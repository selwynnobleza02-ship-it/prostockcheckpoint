import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/services/operation_queue.dart';
import 'package:prostock/services/sync_coordinator.dart';
import 'package:prostock/services/transaction_manager.dart';
import 'package:prostock/services/conflict_resolver.dart';
import 'package:prostock/services/offline/connectivity_service.dart';
import 'package:prostock/services/event_sourcing/event_store.dart';
import 'package:prostock/services/cqrs/command_handler.dart';
import 'package:prostock/services/cqrs/query_handler.dart';
import 'package:prostock/services/consistency/data_consistency_manager.dart';
import 'package:prostock/utils/error_logger.dart';

/// Enhanced unified operation manager with event sourcing and CQRS
class EnhancedUnifiedOperationManager with ChangeNotifier {
  final OperationQueue _queue;
  final SyncCoordinator _syncCoordinator;
  final TransactionManager _transactionManager;
  final ConflictResolver _conflictResolver;
  final ConnectivityService _connectivityService;
  final EventStore _eventStore;
  final CommandHandler _commandHandler;
  final QueryHandler _queryHandler;
  final DataConsistencyManager _consistencyManager;

  bool _isInitialized = false;
  final Map<String, Completer<OperationResult>> _pendingOperations = {};

  EnhancedUnifiedOperationManager({
    required OperationQueue queue,
    required SyncCoordinator syncCoordinator,
    required TransactionManager transactionManager,
    required ConflictResolver conflictResolver,
    required ConnectivityService connectivityService,
    required EventStore eventStore,
    required CommandHandler commandHandler,
    required QueryHandler queryHandler,
    required DataConsistencyManager consistencyManager,
  }) : _queue = queue,
       _syncCoordinator = syncCoordinator,
       _transactionManager = transactionManager,
       _conflictResolver = conflictResolver,
       _connectivityService = connectivityService,
       _eventStore = eventStore,
       _commandHandler = commandHandler,
       _queryHandler = queryHandler,
       _consistencyManager = consistencyManager;

  /// Initialize the enhanced operation manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _queue.initialize();
      await _syncCoordinator.initialize();
      await _transactionManager.initialize();
      await _conflictResolver.initialize();
      await _connectivityService.initialize();
      await _consistencyManager.initialize();

      _isInitialized = true;

      // Start background sync
      _startBackgroundSync();

      ErrorLogger.logInfo(
        'EnhancedUnifiedOperationManager initialized successfully',
        context: 'EnhancedUnifiedOperationManager.initialize',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to initialize EnhancedUnifiedOperationManager',
        error: e,
        context: 'EnhancedUnifiedOperationManager.initialize',
      );
      rethrow;
    }
  }

  /// Execute a single operation with enhanced deduplication and event sourcing
  Future<OperationResult> executeOperation(
    IdempotentOperation operation,
  ) async {
    if (!_isInitialized) {
      throw StateError('EnhancedUnifiedOperationManager not initialized');
    }

    // Check if operation is already pending
    if (_pendingOperations.containsKey(operation.operationId)) {
      return await _pendingOperations[operation.operationId]!.future;
    }

    // Validate operation
    if (!operation.validate()) {
      return OperationResult.failure(
        'Operation validation failed',
        errorCode: 'VALIDATION_ERROR',
      );
    }

    // Create completer for this operation
    final completer = Completer<OperationResult>();
    _pendingOperations[operation.operationId] = completer;

    try {
      // Check for duplicates in queue
      if (await _queue.hasOperation(operation.operationId)) {
        completer.complete(OperationResult.success('Operation already queued'));
        return OperationResult.success('Operation already queued');
      }

      // Add to queue
      await _queue.queueOperation(operation);

      // Execute immediately if possible
      final result = await _executeOperationImmediate(operation);

      completer.complete(result);
      return result;
    } catch (e) {
      final errorResult = OperationResult.failure(
        'Operation execution failed: ${e.toString()}',
        errorCode: 'EXECUTION_ERROR',
      );
      completer.complete(errorResult);
      return errorResult;
    } finally {
      _pendingOperations.remove(operation.operationId);
    }
  }

  /// Execute multiple operations as a transaction with event sourcing
  Future<TransactionResult> executeTransaction(
    List<IdempotentOperation> operations,
  ) async {
    if (!_isInitialized) {
      throw StateError('EnhancedUnifiedOperationManager not initialized');
    }

    if (operations.isEmpty) {
      return TransactionResult.success([]);
    }

    // Validate all operations
    for (final operation in operations) {
      if (!operation.validate()) {
        return TransactionResult.failure(
          'Invalid operation: ${operation.operationId}',
        );
      }
    }

    try {
      return await _transactionManager.executeTransaction(operations);
    } catch (e) {
      ErrorLogger.logError(
        'Transaction execution failed',
        error: e,
        context: 'EnhancedUnifiedOperationManager.executeTransaction',
      );
      return TransactionResult.failure('Transaction failed: ${e.toString()}');
    }
  }

  /// Execute a command using CQRS pattern
  Future<CommandResult> executeCommand(Command command) async {
    if (!_isInitialized) {
      throw StateError('EnhancedUnifiedOperationManager not initialized');
    }

    try {
      return await _commandHandler.handle(command);
    } catch (e) {
      ErrorLogger.logError(
        'Command execution failed',
        error: e,
        context: 'EnhancedUnifiedOperationManager.executeCommand',
      );
      return CommandResult.failure('Command failed: ${e.toString()}');
    }
  }

  /// Execute a query using CQRS pattern
  Future<QueryResult<T>> executeQuery<T>(Query query) async {
    if (!_isInitialized) {
      throw StateError('EnhancedUnifiedOperationManager not initialized');
    }

    try {
      return await _queryHandler.handle<T>(query);
    } catch (e) {
      ErrorLogger.logError(
        'Query execution failed',
        error: e,
        context: 'EnhancedUnifiedOperationManager.executeQuery',
      );
      return QueryResult.failure('Query failed: ${e.toString()}');
    }
  }

  /// Sync pending operations with enhanced conflict resolution
  Future<void> syncPendingOperations() async {
    if (!_isInitialized) {
      throw StateError('EnhancedUnifiedOperationManager not initialized');
    }

    try {
      await _syncCoordinator.syncPendingOperations();
    } catch (e) {
      ErrorLogger.logError(
        'Sync failed',
        error: e,
        context: 'EnhancedUnifiedOperationManager.syncPendingOperations',
      );
      rethrow;
    }
  }

  /// Ensure data consistency across all systems
  Future<void> ensureConsistency() async {
    if (!_isInitialized) {
      throw StateError('EnhancedUnifiedOperationManager not initialized');
    }

    try {
      await _consistencyManager.ensureConsistency();
    } catch (e) {
      ErrorLogger.logError(
        'Consistency check failed',
        error: e,
        context: 'EnhancedUnifiedOperationManager.ensureConsistency',
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

  /// Get connectivity status stream
  Stream<bool> get connectivityStream =>
      _connectivityService.connectivityStream;

  /// Get event stream
  Stream<DomainEvent> get eventStream => _eventStore.eventStream;

  /// Execute operation immediately (if online)
  Future<OperationResult> _executeOperationImmediate(
    IdempotentOperation operation,
  ) async {
    if (!_connectivityService.isOnline) {
      return OperationResult.success('Operation queued for offline execution');
    }

    try {
      final stopwatch = Stopwatch()..start();
      final result = await operation.execute();
      stopwatch.stop();

      if (result.isSuccess) {
        // Remove from queue if successful
        await _queue.removeOperation(operation.operationId);

        ErrorLogger.logInfo(
          'Operation ${operation.operationId} executed successfully in ${stopwatch.elapsedMilliseconds}ms',
          context: 'EnhancedUnifiedOperationManager._executeOperationImmediate',
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
          context: 'EnhancedUnifiedOperationManager._executeOperationImmediate',
        );
      }

      return result;
    } catch (e) {
      ErrorLogger.logError(
        'Operation ${operation.operationId} execution error',
        error: e,
        context: 'EnhancedUnifiedOperationManager._executeOperationImmediate',
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
          context: 'EnhancedUnifiedOperationManager._startBackgroundSync',
        );
      }
    });
  }

  @override
  void dispose() {
    _consistencyManager.dispose();
    _connectivityService.dispose();
    _eventStore.dispose();
    super.dispose();
  }
}

