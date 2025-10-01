import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/services/operation_queue.dart';
import 'package:prostock/services/sync_coordinator.dart';
import 'package:prostock/services/transaction_manager.dart';
import 'package:prostock/services/conflict_resolver.dart';
import 'package:prostock/services/offline/connectivity_service.dart';
import 'package:prostock/utils/error_logger.dart';

/// Centralized manager for all operations in the system
/// Prevents duplication, ensures idempotency, and coordinates sync
class UnifiedOperationManager with ChangeNotifier {
  final OperationQueue _queue;
  final SyncCoordinator _syncCoordinator;
  final TransactionManager _transactionManager;
  final ConflictResolver _conflictResolver;
  final ConnectivityService _connectivityService;

  bool _isInitialized = false;
  final Map<String, Completer<OperationResult>> _pendingOperations = {};

  UnifiedOperationManager({
    required OperationQueue queue,
    required SyncCoordinator syncCoordinator,
    required TransactionManager transactionManager,
    required ConflictResolver conflictResolver,
    required ConnectivityService connectivityService,
  }) : _queue = queue,
       _syncCoordinator = syncCoordinator,
       _transactionManager = transactionManager,
       _conflictResolver = conflictResolver,
       _connectivityService = connectivityService;

  /// Initialize the operation manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _queue.initialize();
      await _syncCoordinator.initialize();
      await _transactionManager.initialize();
      await _conflictResolver.initialize();
      await _connectivityService.initialize();

      _isInitialized = true;

      // Start background sync
      _startBackgroundSync();

      ErrorLogger.logInfo(
        'UnifiedOperationManager initialized successfully',
        context: 'UnifiedOperationManager.initialize',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to initialize UnifiedOperationManager',
        error: e,
        context: 'UnifiedOperationManager.initialize',
      );
      rethrow;
    }
  }

  /// Execute a single operation with deduplication
  Future<OperationResult> executeOperation(
    IdempotentOperation operation,
  ) async {
    if (!_isInitialized) {
      throw StateError('UnifiedOperationManager not initialized');
    }

    // Check if operation is already pending
    if (_pendingOperations.containsKey(operation.operationId)) {
      return await _pendingOperations[operation.operationId]!.future;
    }

    // Validate operation
    if (!operation.validate()) {
      return OperationResult.failure(
        'Invalid operation data',
        errorCode: 'INVALID_OPERATION',
      );
    }

    // Create completer for this operation
    final completer = Completer<OperationResult>();
    _pendingOperations[operation.operationId] = completer;

    try {
      // Check for duplicates in queue
      if (await _queue.hasOperation(operation.operationId)) {
        ErrorLogger.logInfo(
          'Operation ${operation.operationId} already queued, skipping duplicate',
          context: 'UnifiedOperationManager.executeOperation',
        );
        return OperationResult.success('Operation already queued');
      }

      // Add to queue
      await _queue.queueOperation(operation);

      // Execute immediately if possible
      final result = await _executeOperationImmediate(operation);

      completer.complete(result);
      return result;
    } catch (e) {
      final error = OperationResult.failure(
        'Failed to execute operation: ${e.toString()}',
        errorCode: 'EXECUTION_ERROR',
      );
      completer.complete(error);
      return error;
    } finally {
      _pendingOperations.remove(operation.operationId);
    }
  }

  /// Execute multiple operations as a transaction
  Future<TransactionResult> executeTransaction(
    List<IdempotentOperation> operations,
  ) async {
    if (!_isInitialized) {
      throw StateError('UnifiedOperationManager not initialized');
    }

    if (operations.isEmpty) {
      return TransactionResult.success([]);
    }

    // Validate all operations
    for (final operation in operations) {
      if (!operation.validate()) {
        return TransactionResult.failure(
          'Invalid operation in transaction: ${operation.operationId}',
        );
      }
    }

    try {
      return await _transactionManager.executeTransaction(operations);
    } catch (e) {
      ErrorLogger.logError(
        'Transaction execution failed',
        error: e,
        context: 'UnifiedOperationManager.executeTransaction',
      );
      return TransactionResult.failure('Transaction failed: ${e.toString()}');
    }
  }

  /// Sync pending operations
  Future<void> syncPendingOperations() async {
    if (!_isInitialized) {
      throw StateError('UnifiedOperationManager not initialized');
    }

    try {
      await _syncCoordinator.syncPendingOperations();
      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Sync failed',
        error: e,
        context: 'UnifiedOperationManager.syncPendingOperations',
      );
      rethrow;
    }
  }

  /// Get pending operations count
  Future<int> getPendingOperationsCount() async {
    return await _queue.getPendingOperationsCount();
  }

  /// Get sync status
  bool get isSyncing => _syncCoordinator.isSyncing;

  /// Get last sync time
  DateTime? get lastSyncTime => _syncCoordinator.lastSyncTime;

  /// Check if device is online
  bool get isOnline => _connectivityService.isOnline;

  /// Execute operation immediately (if online)
  Future<OperationResult> _executeOperationImmediate(
    IdempotentOperation operation,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await operation.execute();
      stopwatch.stop();

      if (result.isSuccess) {
        // Remove from queue if successful
        await _queue.removeOperation(operation.operationId);

        ErrorLogger.logInfo(
          'Operation ${operation.operationId} executed successfully in ${stopwatch.elapsedMilliseconds}ms',
          context: 'UnifiedOperationManager._executeOperationImmediate',
        );
      } else {
        // Handle retry logic
        if (operation.canRetry()) {
          await _queue.requeueOperation(operation);
        } else {
          await _queue.removeOperation(operation.operationId);
        }

        ErrorLogger.logError(
          'Operation ${operation.operationId} failed: ${result.error}',
          context: 'UnifiedOperationManager._executeOperationImmediate',
        );
      }

      return result;
    } catch (e) {
      ErrorLogger.logError(
        'Operation ${operation.operationId} execution error',
        error: e,
        context: 'UnifiedOperationManager._executeOperationImmediate',
      );

      if (operation.canRetry()) {
        await _queue.requeueOperation(operation);
      }

      return OperationResult.failure(
        'Execution error: ${e.toString()}',
        errorCode: 'EXECUTION_ERROR',
      );
    }
  }

  /// Start background sync process
  void _startBackgroundSync() {
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }

      try {
        await syncPendingOperations();
      } catch (e) {
        ErrorLogger.logError(
          'Background sync failed',
          error: e,
          context: 'UnifiedOperationManager._startBackgroundSync',
        );
      }
    });
  }

  @override
  void dispose() {
    _pendingOperations.clear();
    super.dispose();
  }
}
