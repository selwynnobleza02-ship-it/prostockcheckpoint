import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/sync_failure.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/offline/operation_queue_service.dart';
import 'package:prostock/utils/constants.dart';
import 'package:prostock/utils/error_logger.dart';

class SyncService {
  final OperationQueueService _queueService;
  final LocalDatabaseService _localDatabaseService;
  final SyncFailureProvider _syncFailureProvider;
  static const int maxRetries = 3;

  SyncService(
    this._queueService,
    this._localDatabaseService,
    this._syncFailureProvider,
  );

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
    }
  }

  Future<void> _processBatch(List<OfflineOperation> batch) async {
    final List<Map<String, dynamic>> batchOperations = [];
    final List<int> successfulOperationIds = [];
    final List<OfflineOperation> failedOperations = [];

    for (final operation in batch) {
      try {
        final newBatchOperations = _getBatchOperations(operation);
        batchOperations.addAll(newBatchOperations);
        successfulOperationIds.add(operation.dbId!);
        ErrorLogger.logInfo(
          'Synced operation: ${operation.type} - ${operation.id}',
          context: 'SyncService._processBatch',
        );
      } catch (e) {
        ErrorLogger.logError(
          'Failed to sync operation ${operation.id}',
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
          successfulOperationIds.add(operation.dbId!);
          ErrorLogger.logError(
            'Operation ${operation.id} failed after $maxRetries retries',
            error: e,
            context: 'SyncService._processBatch',
          );
        }
      }
    }

    if (batchOperations.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();

      for (final operation in batchOperations) {
        final type = operation['type'];
        final collection = operation['collection'];
        final docId = operation['docId'];
        final data = operation['data'];

        if (type == AppConstants.operationInsert) {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          batch.set(docRef, data);
        } else if (type == AppConstants.operationUpdate) {
          final docRef = FirebaseFirestore.instance
              .collection(collection)
              .doc(docId);
          batch.update(docRef, data);
        }
      }

      await batch.commit();
    }

    final db = await _localDatabaseService.database;
    if (successfulOperationIds.isNotEmpty) {
      await db.delete(
        'offline_operations',
        where: 'id IN (?)',
        whereArgs: [successfulOperationIds.join(',')],
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
        return [_getInsertOperation(operation)];
      case OperationType.updateProduct:
      case OperationType.updateCustomer:
      case OperationType.updateCustomerBalance:
        return [_getUpdateOperation(operation)];
      case OperationType.createSaleTransaction:
        final saleMap = operation.data['sale'] as Map<String, dynamic>;
        final sale = Sale.fromMap(saleMap);
        final saleItems = (operation.data['saleItems'] as List)
            .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
            .toList();

        unawaited(
          _localDatabaseService.insertSale(sale.copyWith(isSynced: 1)),
        );
        for (final item in saleItems) {
          unawaited(_localDatabaseService.insertSaleItem(item));
        }

        final List<Map<String, dynamic>> operations = [];

        operations.add({
          'type': AppConstants.operationInsert,
          'collection': AppConstants.salesCollection,
          'docId': sale.id,
          'data': sale.toMap(),
        });

        for (final item in saleItems) {
          operations.add({
            'type': AppConstants.operationInsert,
            'collection': AppConstants.saleItemsCollection,
            'docId': item.id,
            'data': item.toMap(),
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
}
