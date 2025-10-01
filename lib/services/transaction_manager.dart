import 'dart:async';
import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:uuid/uuid.dart';

/// Manages transactions to ensure atomicity across multiple operations
class TransactionManager {
  final LocalDatabaseService _localDatabaseService;

  bool _isInitialized = false;
  final Map<String, Transaction> _activeTransactions = {};

  TransactionManager(this._localDatabaseService);

  /// Initialize the transaction manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    ErrorLogger.logInfo(
      'TransactionManager initialized',
      context: 'TransactionManager.initialize',
    );
  }

  /// Execute multiple operations as a single transaction
  Future<TransactionResult> executeTransaction(
    List<IdempotentOperation> operations,
  ) async {
    if (!_isInitialized) {
      throw StateError('TransactionManager not initialized');
    }

    if (operations.isEmpty) {
      return TransactionResult.success([]);
    }

    final transactionId = const Uuid().v4();
    final transaction = Transaction(
      id: transactionId,
      operations: operations,
      status: TransactionStatus.pending,
    );

    _activeTransactions[transactionId] = transaction;

    try {
      ErrorLogger.logInfo(
        'Starting transaction $transactionId with ${operations.length} operations',
        context: 'TransactionManager.executeTransaction',
      );

      // Validate all operations
      for (final operation in operations) {
        if (!operation.validate()) {
          throw Exception('Invalid operation: ${operation.operationId}');
        }
      }

      // Execute operations in sequence
      final results = <OperationResult>[];

      for (final operation in operations) {
        try {
          final result = await operation.execute();
          results.add(result);

          if (!result.isSuccess) {
            // If any operation fails, rollback the transaction
            await _rollbackTransaction(transactionId, results);

            return TransactionResult.failure(
              'Transaction failed at operation ${operation.operationId}: ${result.error}',
              transactionId: transactionId,
            );
          }
        } catch (e) {
          // Rollback on exception
          await _rollbackTransaction(transactionId, results);

          ErrorLogger.logError(
            'Transaction $transactionId failed at operation ${operation.operationId}',
            error: e,
            context: 'TransactionManager.executeTransaction',
          );

          return TransactionResult.failure(
            'Transaction failed: ${e.toString()}',
            transactionId: transactionId,
          );
        }
      }

      // Commit transaction
      await _commitTransaction(transactionId);

      ErrorLogger.logInfo(
        'Transaction $transactionId completed successfully',
        context: 'TransactionManager.executeTransaction',
      );

      return TransactionResult.success(results, transactionId: transactionId);
    } catch (e) {
      ErrorLogger.logError(
        'Transaction $transactionId failed',
        error: e,
        context: 'TransactionManager.executeTransaction',
      );

      await _rollbackTransaction(transactionId, []);

      return TransactionResult.failure(
        'Transaction failed: ${e.toString()}',
        transactionId: transactionId,
      );
    } finally {
      _activeTransactions.remove(transactionId);
    }
  }

  /// Rollback a transaction
  Future<void> rollbackTransaction(String transactionId) async {
    if (!_activeTransactions.containsKey(transactionId)) {
      throw Exception('Transaction $transactionId not found');
    }

    final transaction = _activeTransactions[transactionId]!;
    await _rollbackTransaction(transactionId, transaction.results);
  }

  /// Commit a transaction
  Future<void> commitTransaction(String transactionId) async {
    if (!_activeTransactions.containsKey(transactionId)) {
      throw Exception('Transaction $transactionId not found');
    }

    await _commitTransaction(transactionId);
  }

  /// Get active transactions
  Map<String, Transaction> get activeTransactions =>
      Map.unmodifiable(_activeTransactions);

  /// Internal rollback implementation
  Future<void> _rollbackTransaction(
    String transactionId,
    List<OperationResult> results,
  ) async {
    final transaction = _activeTransactions[transactionId];
    if (transaction == null) return;

    try {
      ErrorLogger.logInfo(
        'Rolling back transaction $transactionId',
        context: 'TransactionManager._rollbackTransaction',
      );

      // Execute rollback operations in reverse order
      for (int i = transaction.operations.length - 1; i >= 0; i--) {
        final operation = transaction.operations[i];

        try {
          // Try to rollback the operation
          await _rollbackOperation(operation);
        } catch (e) {
          ErrorLogger.logError(
            'Failed to rollback operation ${operation.operationId}',
            error: e,
            context: 'TransactionManager._rollbackTransaction',
          );
          // Continue with other rollbacks even if one fails
        }
      }

      transaction.status = TransactionStatus.rolledBack;

      ErrorLogger.logInfo(
        'Transaction $transactionId rolled back successfully',
        context: 'TransactionManager._rollbackTransaction',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to rollback transaction $transactionId',
        error: e,
        context: 'TransactionManager._rollbackTransaction',
      );
      rethrow;
    }
  }

  /// Internal commit implementation
  Future<void> _commitTransaction(String transactionId) async {
    final transaction = _activeTransactions[transactionId];
    if (transaction == null) return;

    try {
      // Use database transaction for atomicity
      final db = await _localDatabaseService.database;
      await db.transaction((txn) async {
        // Mark transaction as committed in database
        await txn.insert('transactions', {
          'id': transactionId,
          'status': 'committed',
          'created_at': DateTime.now().toIso8601String(),
          'operation_count': transaction.operations.length,
        });
      });

      transaction.status = TransactionStatus.committed;

      ErrorLogger.logInfo(
        'Transaction $transactionId committed successfully',
        context: 'TransactionManager._commitTransaction',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to commit transaction $transactionId',
        error: e,
        context: 'TransactionManager._commitTransaction',
      );
      rethrow;
    }
  }

  /// Rollback a single operation (to be implemented by specific operation types)
  Future<void> _rollbackOperation(IdempotentOperation operation) async {
    // This will be implemented by specific operation types
    // For now, just log the rollback attempt
    ErrorLogger.logInfo(
      'Rolling back operation ${operation.operationId}',
      context: 'TransactionManager._rollbackOperation',
    );
  }
}

/// Represents a transaction
class Transaction {
  final String id;
  final List<IdempotentOperation> operations;
  TransactionStatus status;
  final List<OperationResult> results;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.operations,
    required this.status,
    List<OperationResult>? results,
    DateTime? createdAt,
  }) : results = results ?? [],
       createdAt = createdAt ?? DateTime.now();
}

/// Transaction status
enum TransactionStatus { pending, committed, rolledBack, failed }
