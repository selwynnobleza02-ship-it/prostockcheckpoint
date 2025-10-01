import 'dart:async';
import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/services/operations/sale_operations.dart';
import 'package:prostock/services/operations/credit_operations.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Deduplicated operation queue that prevents duplicate operations
class OperationQueue {
  final LocalDatabaseService _localDatabaseService;
  final Map<String, IdempotentOperation> _memoryQueue = {};
  final Map<String, DateTime> _operationTimestamps = {};

  bool _isInitialized = false;

  OperationQueue(this._localDatabaseService);

  /// Initialize the operation queue
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load pending operations from database
      await _loadPendingOperations();
      _isInitialized = true;

      ErrorLogger.logInfo(
        'OperationQueue initialized with ${_memoryQueue.length} pending operations',
        context: 'OperationQueue.initialize',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to initialize OperationQueue',
        error: e,
        context: 'OperationQueue.initialize',
      );
      rethrow;
    }
  }

  /// Queue an operation with deduplication
  Future<void> queueOperation(IdempotentOperation operation) async {
    if (!_isInitialized) {
      throw StateError('OperationQueue not initialized');
    }

    // Check for duplicates
    if (_memoryQueue.containsKey(operation.operationId)) {
      ErrorLogger.logInfo(
        'Operation ${operation.operationId} already queued, skipping duplicate',
        context: 'OperationQueue.queueOperation',
      );
      return;
    }

    try {
      // Add to memory queue
      _memoryQueue[operation.operationId] = operation;
      _operationTimestamps[operation.operationId] = DateTime.now();

      // Persist to database
      await _persistOperation(operation);

      ErrorLogger.logInfo(
        'Operation ${operation.operationId} queued successfully',
        context: 'OperationQueue.queueOperation',
      );
    } catch (e) {
      // Remove from memory queue if persistence failed
      _memoryQueue.remove(operation.operationId);
      _operationTimestamps.remove(operation.operationId);

      ErrorLogger.logError(
        'Failed to queue operation ${operation.operationId}',
        error: e,
        context: 'OperationQueue.queueOperation',
      );
      rethrow;
    }
  }

  /// Get all pending operations sorted by priority and timestamp
  Future<List<IdempotentOperation>> getPendingOperations() async {
    if (!_isInitialized) {
      throw StateError('OperationQueue not initialized');
    }

    final operations = _memoryQueue.values.toList();

    // Sort by priority (descending) then by timestamp (ascending)
    operations.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.timestamp.compareTo(b.timestamp);
    });

    return operations;
  }

  /// Get pending operations count
  Future<int> getPendingOperationsCount() async {
    return _memoryQueue.length;
  }

  /// Check if operation exists in queue
  Future<bool> hasOperation(String operationId) async {
    return _memoryQueue.containsKey(operationId);
  }

  /// Remove operation from queue
  Future<void> removeOperation(String operationId) async {
    if (!_isInitialized) {
      throw StateError('OperationQueue not initialized');
    }

    try {
      // Remove from memory
      _memoryQueue.remove(operationId);
      _operationTimestamps.remove(operationId);

      // Remove from database
      await _removeOperationFromDatabase(operationId);

      ErrorLogger.logInfo(
        'Operation $operationId removed from queue',
        context: 'OperationQueue.removeOperation',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to remove operation $operationId',
        error: e,
        context: 'OperationQueue.removeOperation',
      );
      rethrow;
    }
  }

  /// Requeue operation (for retry)
  Future<void> requeueOperation(IdempotentOperation operation) async {
    if (!_isInitialized) {
      throw StateError('OperationQueue not initialized');
    }

    try {
      // Update timestamp
      _operationTimestamps[operation.operationId] = DateTime.now();

      // Update in database
      await _updateOperationInDatabase(operation);

      ErrorLogger.logInfo(
        'Operation ${operation.operationId} requeued for retry',
        context: 'OperationQueue.requeueOperation',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to requeue operation ${operation.operationId}',
        error: e,
        context: 'OperationQueue.requeueOperation',
      );
      rethrow;
    }
  }

  /// Clear all pending operations
  Future<void> clearAll() async {
    if (!_isInitialized) {
      throw StateError('OperationQueue not initialized');
    }

    try {
      _memoryQueue.clear();
      _operationTimestamps.clear();

      await _clearAllFromDatabase();

      ErrorLogger.logInfo(
        'All operations cleared from queue',
        context: 'OperationQueue.clearAll',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to clear operations',
        error: e,
        context: 'OperationQueue.clearAll',
      );
      rethrow;
    }
  }

  /// Load pending operations from database
  Future<void> _loadPendingOperations() async {
    try {
      final db = await _localDatabaseService.database;
      final maps = await db.query(
        'offline_operations',
        orderBy: 'priority DESC, timestamp ASC',
      );

      for (final map in maps) {
        try {
          final operation = _deserializeOperation(map);
          if (operation != null) {
            _memoryQueue[operation.operationId] = operation;
            _operationTimestamps[operation.operationId] = operation.timestamp;
          }
        } catch (e) {
          ErrorLogger.logError(
            'Failed to deserialize operation ${map['operation_id']}',
            error: e,
            context: 'OperationQueue._loadPendingOperations',
          );
        }
      }
    } catch (e) {
      ErrorLogger.logError(
        'Failed to load pending operations',
        error: e,
        context: 'OperationQueue._loadPendingOperations',
      );
      rethrow;
    }
  }

  /// Persist operation to database
  Future<void> _persistOperation(IdempotentOperation operation) async {
    final db = await _localDatabaseService.database;
    await db.insert('offline_operations', {
      'operation_id': operation.operationId,
      'operation_type': operation.operationType,
      'collection_name': _mapCollectionName(operation.operationType),
      'document_id': null,
      'data': operation.toMap(),
      'timestamp': operation.timestamp.toIso8601String(),
      'priority': operation.priority,
      'version': operation.version,
      'retry_count': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _mapCollectionName(String operationType) {
    switch (operationType) {
      case 'create_sale':
        return 'sales';
      case 'create_credit_payment':
        return 'credit_transactions';
      case 'create_credit_sale':
        return 'sales';
      case 'update_stock_for_sale':
        return 'products';
      default:
        return 'operations';
    }
  }

  /// Remove operation from database
  Future<void> _removeOperationFromDatabase(String operationId) async {
    final db = await _localDatabaseService.database;
    await db.delete(
      'offline_operations',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  /// Update operation in database
  Future<void> _updateOperationInDatabase(IdempotentOperation operation) async {
    final db = await _localDatabaseService.database;
    await db.update(
      'offline_operations',
      {
        'data': operation.toMap(),
        'timestamp': operation.timestamp.toIso8601String(),
        'retry_count': 0,
      },
      where: 'operation_id = ?',
      whereArgs: [operation.operationId],
    );
  }

  /// Clear all operations from database
  Future<void> _clearAllFromDatabase() async {
    final db = await _localDatabaseService.database;
    await db.delete('offline_operations');
  }

  /// Deserialize operation from database map
  IdempotentOperation? _deserializeOperation(Map<String, dynamic> map) {
    try {
      final operationType = map['operation_type'] as String;
      final data = map['data'] as Map<String, dynamic>;

      switch (operationType) {
        case 'create_sale':
          return CreateSaleOperation.fromMap(data);
        case 'create_credit_payment':
          return CreateCreditPaymentOperation.fromMap(data);
        case 'create_credit_sale':
          return CreateCreditSaleOperation.fromMap(data);
        case 'update_stock_for_sale':
          return UpdateStockForSaleOperation.fromMap(data);
        default:
          ErrorLogger.logError(
            'Unknown operation type: $operationType',
            context: 'OperationQueue._deserializeOperation',
          );
          return null;
      }
    } catch (e) {
      ErrorLogger.logError(
        'Failed to deserialize operation',
        error: e,
        context: 'OperationQueue._deserializeOperation',
      );
      return null;
    }
  }
}
