import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/sync_failure.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:prostock/services/cloudinary_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/offline/operation_queue_service.dart';
import 'package:prostock/utils/constants.dart';
import 'package:prostock/utils/error_logger.dart';

class SyncService {
  final OperationQueueService _queueService;
  final LocalDatabaseService _localDatabaseService;
  final SyncFailureProvider _syncFailureProvider;
  static const int maxRetries = 3;

  Function(int, int)? _onProgressUpdate;

  SyncService(
    this._queueService,
    this._localDatabaseService,
    this._syncFailureProvider,
  );

  void setProgressCallback(Function(int completed, int total) callback) {
    _onProgressUpdate = callback;
  }

  Future<void> syncPendingOperations() async {
    final operationsToSync = await _queueService.getPendingOperations();
    if (operationsToSync.isEmpty) return;

    try {
      await _processBatches(operationsToSync);
    } catch (e) {
      _handleFailedSync(e);
    }
  }

  Future<void> _processBatches(List<OfflineOperation> operationsToSync) async {
    const int batchSize = 50;
    for (int i = 0; i < operationsToSync.length; i += batchSize) {
      final List<OfflineOperation> batch = operationsToSync.sublist(
        i,
        i + batchSize > operationsToSync.length
            ? operationsToSync.length
            : i + batchSize,
      );
      await _processBatch(batch);

      // Update progress after each batch
      _updateSyncProgress(i + batch.length, operationsToSync.length);
    }
  }

  void _updateSyncProgress(int completed, int total) {
    _onProgressUpdate?.call(completed, total);
  }

  Future<void> _processBatch(List<OfflineOperation> batch) async {
    final List<Map<String, dynamic>> batchOperations = [];
    final List<OfflineOperation> operationsInBatch = [];
    final List<OfflineOperation> failedOperations = [];

    for (final operation in batch) {
      try {
        // Handle image upload with fallback
        if (operation.type == OperationType.insertCustomer ||
            operation.type == OperationType.updateCustomer) {
          if (operation.data['localImagePath'] != null) {
            try {
              final imageUrl = await CloudinaryService.instance.uploadImage(
                File(operation.data['localImagePath']),
              );
              operation.data['imageUrl'] = imageUrl;
              operation.data.remove('localImagePath');
              ErrorLogger.logInfo(
                'Image uploaded successfully for operation ${operation.id}',
                context: 'SyncService._processBatch',
              );
            } catch (imageError) {
              ErrorLogger.logError(
                'Image upload failed for operation ${operation.id}, continuing without image',
                error: imageError,
                context: 'SyncService._processBatch',
              );
              // Keep localImagePath for retry later, don't fail the entire operation
              // operation.data.remove('localImagePath'); // Commented out to preserve for retry
            }
          }
        }

        final newBatchOperations = _getBatchOperations(operation);
        batchOperations.addAll(newBatchOperations);
        operationsInBatch.add(operation);
        ErrorLogger.logInfo(
          'Prepared operation for batch: ${operation.type} - ${operation.id}',
          context: 'SyncService._processBatch',
        );
      } catch (e) {
        ErrorLogger.logError(
          'Failed to prepare operation ${operation.id}',
          error: e,
          context: 'SyncService._processBatch',
        );
        if (operation.retryCount < maxRetries) {
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );
          failedOperations.add(updatedOperation);
        } else {
          await _moveToDeadLetterQueue(operation, e.toString());
          ErrorLogger.logError(
            'Operation ${operation.id} failed after $maxRetries retries',
            error: e,
            context: 'SyncService._processBatch',
          );
        }
      }
    }

    // Commit batch with error handling
    final List<int> successfulOperationIds = [];
    if (batchOperations.isNotEmpty) {
      final firestoreBatch = FirebaseFirestore.instance.batch();

      for (final operation in batchOperations) {
        final type = operation['type'];
        final collection = operation['collection'];
        final docId = operation['docId'];
        final data = operation['data'];

        if (type == AppConstants.operationInsert) {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          firestoreBatch.set(docRef, data);
        } else if (type == AppConstants.operationUpdate) {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          // Use set with merge for updateProduct to handle missing documents
          if (collection == AppConstants.productsCollection) {
            firestoreBatch.set(docRef, data, SetOptions(merge: true));
          } else {
            firestoreBatch.update(docRef, data);
          }
        } else if (type == AppConstants.operationDelete) {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          firestoreBatch.delete(docRef);
        }
      }

      try {
        await firestoreBatch.commit();
        // Only mark as successful if commit succeeds
        successfulOperationIds.addAll(operationsInBatch.map((op) => op.dbId!));
        ErrorLogger.logInfo(
          'Successfully committed batch with ${operationsInBatch.length} operations',
          context: 'SyncService._processBatch',
        );
      } catch (e) {
        ErrorLogger.logError(
          'Firebase batch commit failed, retrying operations',
          error: e,
          context: 'SyncService._processBatch',
        );
        // If commit fails, retry all operations
        for (final op in operationsInBatch) {
          if (op.retryCount < maxRetries) {
            final updatedOperation = op.copyWith(retryCount: op.retryCount + 1);
            failedOperations.add(updatedOperation);
            ErrorLogger.logInfo(
              'Retrying operation ${op.id} (attempt ${updatedOperation.retryCount})',
              context: 'SyncService._processBatch',
            );
          } else {
            await _moveToDeadLetterQueue(op, e.toString());
            successfulOperationIds.add(op.dbId!);
            ErrorLogger.logError(
              'Operation ${op.id} failed after $maxRetries retries due to batch commit failure',
              error: e,
              context: 'SyncService._processBatch',
            );
          }
        }
      }
    }

    final db = await _localDatabaseService.database;
    // Delete only successfully synced operations
    if (successfulOperationIds.isNotEmpty) {
      final placeholders = successfulOperationIds.map((_) => '?').join(',');
      await db.delete(
        'offline_operations',
        where: 'id IN ($placeholders)',
        whereArgs: successfulOperationIds,
      );
      ErrorLogger.logInfo(
        'Removed ${successfulOperationIds.length} successfully synced operations from queue',
        context: 'SyncService._processBatch',
      );
    }

    if (failedOperations.isNotEmpty) {
      final batchDb = db.batch();
      for (final op in failedOperations) {
        batchDb.update(
          'offline_operations',
          op.toMap(),
          where: 'id = ?',
          whereArgs: [op.dbId],
        );
      }
      await batchDb.commit(noResult: true);
      ErrorLogger.logInfo(
        'Updated retry count for ${failedOperations.length} failed operations',
        context: 'SyncService._processBatch',
      );
    }
  }

  void _handleFailedSync(Object e) {
    ErrorLogger.logError(
      'Error during sync',
      error: e,
      context: 'SyncService.syncPendingOperations',
    );
  }

  Future<void> _moveToDeadLetterQueue(
    OfflineOperation operation,
    String error,
  ) async {
    final db = await _localDatabaseService.database;
    await db.insert('dead_letter_operations', {
      'operation_id': operation.id,
      'operation_type': operation.type.toString().split('.').last,
      'collection_name': operation.collectionName,
      'document_id': operation.documentId,
      'data': jsonEncode(operation.data),
      'timestamp': operation.timestamp.toIso8601String(),
      'error': error,
    });

    _syncFailureProvider.addFailure(
      SyncFailure(operation: operation, error: error),
    );
  }

  List<Map<String, dynamic>> _getBatchOperations(OfflineOperation operation) {
    switch (operation.type) {
      case OperationType.insertProduct:
      case OperationType.insertCustomer:
      case OperationType.insertCreditTransaction:
      case OperationType.insertLoss:
      case OperationType.insertPriceHistory:
      case OperationType.insertCostHistory:
      case OperationType.insertStockMovement:
      case OperationType.logActivity:
        return [_getInsertOperation(operation)];
      case OperationType.updateProduct:
      case OperationType.updateCustomer:
        return [_getUpdateOperation(operation)];
      case OperationType.updateCustomerBalance:
        return [_getBalanceIncrementOperation(operation)];
      case OperationType.deleteCustomer:
        return [_getDeleteOperation(operation)];
      case OperationType.createSaleTransaction:
        final saleMap = operation.data['sale'] as Map<String, dynamic>;
        final sale = Sale.fromMap(saleMap);
        final saleItems = (operation.data['saleItems'] as List)
            .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
            .toList();

        // Avoid duplicating local data: just mark as synced instead of re-inserting
        unawaited(_localDatabaseService.markSaleAsSynced(sale.id!));

        final List<Map<String, dynamic>> operations = [];

        // Normalize sale payload for Firestore: camelCase + Timestamp
        final Map<String, dynamic> saleData = {
          'userId': sale.userId,
          'customerId': sale.customerId,
          'totalAmount': sale.totalAmount,
          'paymentMethod': sale.paymentMethod,
          'status': sale.status,
          'createdAt': Timestamp.fromDate(sale.createdAt),
        };
        if (sale.dueDate != null) {
          saleData['dueDate'] = Timestamp.fromDate(sale.dueDate!);
        }

        operations.add({
          'type': AppConstants.operationInsert,
          'collection': AppConstants.salesCollection,
          'docId': sale.id,
          'data': saleData,
        });

        for (final item in saleItems) {
          final Map<String, dynamic> itemData = {
            'saleId': item.saleId,
            'productId': item.productId,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
            'totalPrice': item.totalPrice,
          };
          operations.add({
            'type': AppConstants.operationInsert,
            'collection': AppConstants.saleItemsCollection,
            'docId': item.id,
            'data': itemData,
          });
        }

        for (final item in saleItems) {
          operations.add({
            'type': AppConstants.operationUpdate,
            'collection': AppConstants.productsCollection,
            'docId': item.productId,
            'data': {'stock': FieldValue.increment(-item.quantity)},
          });
        }

        return operations;
    }
  }

  Map<String, dynamic> _getInsertOperation(OfflineOperation operation) {
    return {
      'type': AppConstants.operationInsert,
      'collection': operation.collectionName,
      'docId': operation.documentId,
      'data': operation.data,
    };
  }

  Map<String, dynamic> _getUpdateOperation(OfflineOperation operation) {
    return {
      'type': AppConstants.operationUpdate,
      'collection': operation.collectionName,
      'docId': operation.documentId,
      'data': operation.data,
    };
  }

  Map<String, dynamic> _getDeleteOperation(OfflineOperation operation) {
    return {
      'type': AppConstants.operationDelete,
      'collection': operation.collectionName,
      'docId': operation.documentId,
    };
  }

  Map<String, dynamic> _getBalanceIncrementOperation(
    OfflineOperation operation,
  ) {
    return {
      'type': AppConstants.operationUpdate,
      'collection': operation.collectionName,
      'docId': operation.documentId,
      'data': {
        'balance': FieldValue.increment(
          operation.data['balance_increment'] ?? 0.0,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    };
  }
}
