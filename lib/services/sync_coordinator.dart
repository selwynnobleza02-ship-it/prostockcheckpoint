import 'dart:async';
import 'package:prostock/services/operation_queue.dart';
import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/utils/error_logger.dart';

/// Coordinates sync operations to prevent concurrent syncs and ensure consistency
class SyncCoordinator {
  final OperationQueue _queue;

  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  final Set<String> _syncingOperations = {};

  SyncCoordinator(this._queue);

  /// Initialize the sync coordinator
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    ErrorLogger.logInfo(
      'SyncCoordinator initialized',
      context: 'SyncCoordinator.initialize',
    );
  }

  /// Sync pending operations with deduplication
  Future<void> syncPendingOperations() async {
    if (!_isInitialized) {
      throw StateError('SyncCoordinator not initialized');
    }

    if (_isSyncing) {
      ErrorLogger.logInfo(
        'Sync already in progress, skipping',
        context: 'SyncCoordinator.syncPendingOperations',
      );
      return;
    }

    _isSyncing = true;

    try {
      final operations = await _queue.getPendingOperations();

      if (operations.isEmpty) {
        ErrorLogger.logInfo(
          'No pending operations to sync',
          context: 'SyncCoordinator.syncPendingOperations',
        );
        return;
      }

      ErrorLogger.logInfo(
        'Starting sync of ${operations.length} operations',
        context: 'SyncCoordinator.syncPendingOperations',
      );

      // Process operations in batches
      await _processOperationsInBatches(operations);

      _lastSyncTime = DateTime.now();

      ErrorLogger.logInfo(
        'Sync completed successfully',
        context: 'SyncCoordinator.syncPendingOperations',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Sync failed',
        error: e,
        context: 'SyncCoordinator.syncPendingOperations',
      );
      rethrow;
    } finally {
      _isSyncing = false;
      _syncingOperations.clear();
    }
  }

  /// Process operations in batches to avoid overwhelming the system
  Future<void> _processOperationsInBatches(
    List<IdempotentOperation> operations,
  ) async {
    const int batchSize = 10;

    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = operations.sublist(
        i,
        i + batchSize > operations.length ? operations.length : i + batchSize,
      );

      await _processBatch(batch);

      // Small delay between batches to prevent overwhelming
      if (i + batchSize < operations.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Process a batch of operations
  Future<void> _processBatch(List<IdempotentOperation> operations) async {
    final List<Future<OperationResult>> futures = [];

    for (final operation in operations) {
      // Skip if already being processed
      if (_syncingOperations.contains(operation.operationId)) {
        continue;
      }

      _syncingOperations.add(operation.operationId);

      futures.add(_processOperation(operation));
    }

    // Wait for all operations in batch to complete
    final results = await Future.wait(futures, eagerError: false);

    // Log results
    int successCount = 0;
    int failureCount = 0;

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.isSuccess) {
        successCount++;
      } else {
        failureCount++;
        ErrorLogger.logError(
          'Operation ${operations[i].operationId} failed: ${result.error}',
          context: 'SyncCoordinator._processBatch',
        );
      }
    }

    ErrorLogger.logInfo(
      'Batch processed: $successCount success, $failureCount failures',
      context: 'SyncCoordinator._processBatch',
    );
  }

  /// Process a single operation
  Future<OperationResult> _processOperation(
    IdempotentOperation operation,
  ) async {
    try {
      final result = await operation.execute();

      if (result.isSuccess) {
        // Remove from queue on success
        await _queue.removeOperation(operation.operationId);
      } else {
        // Handle retry logic
        if (operation.canRetry()) {
          await _queue.requeueOperation(operation);
        } else {
          // Remove from queue if max retries exceeded
          await _queue.removeOperation(operation.operationId);

          ErrorLogger.logError(
            'Operation ${operation.operationId} exceeded max retries, removing from queue',
            context: 'SyncCoordinator._processOperation',
          );
        }
      }

      return result;
    } catch (e) {
      ErrorLogger.logError(
        'Operation ${operation.operationId} execution error',
        error: e,
        context: 'SyncCoordinator._processOperation',
      );

      // Handle retry logic
      if (operation.canRetry()) {
        await _queue.requeueOperation(operation);
      } else {
        await _queue.removeOperation(operation.operationId);
      }

      return OperationResult.failure(
        'Execution error: ${e.toString()}',
        errorCode: 'EXECUTION_ERROR',
      );
    } finally {
      _syncingOperations.remove(operation.operationId);
    }
  }

  /// Get sync status
  bool get isSyncing => _isSyncing;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Get currently syncing operations
  Set<String> get syncingOperations => Set.unmodifiable(_syncingOperations);

  /// Force stop sync (for emergency situations)
  Future<void> stopSync() async {
    if (_isSyncing) {
      ErrorLogger.logInfo(
        'Stopping sync operation',
        context: 'SyncCoordinator.stopSync',
      );

      _isSyncing = false;
      _syncingOperations.clear();
    }
  }
}

