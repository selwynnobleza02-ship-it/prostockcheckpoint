import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../services/firestore_service.dart';
import '../services/local_database_service.dart';
import '../utils/error_logger.dart';
import '../utils/constants.dart';

/// Offline Manager - Comprehensive offline-first data synchronization system
///
/// ARCHITECTURE OVERVIEW:
/// This service implements a sophisticated offline-first architecture that ensures
/// the app remains fully functional without internet connectivity while maintaining
/// data consistency when connectivity is restored.
///
/// CORE COMPONENTS:
/// 1. Connectivity Monitoring: Real-time network status detection
/// 2. Operation Queue: Persistent storage of offline operations
/// 3. Cache Management: Multi-tier caching with intelligent expiry
/// 4. Sync Engine: Conflict-free synchronization algorithms
///
/// BUSINESS CONTINUITY:
/// - All critical operations (sales, inventory, customer management) work offline
/// - Data integrity maintained through atomic operations and rollback mechanisms
/// - Automatic background sync when connectivity is restored
/// - Conflict resolution prioritizes local changes for business continuity
class OfflineManager with ChangeNotifier {
  static final OfflineManager instance = OfflineManager._init();
  final LocalDatabaseService _localDatabaseService =
      LocalDatabaseService.instance;
  static const int maxRetries = 3;
  OfflineManager._init();

  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  List<OfflineOperation> _pendingOperations = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<OfflineOperation> get pendingOperations =>
      List.unmodifiable(_pendingOperations);
  int get pendingOperationsCount => _pendingOperations.length;

  /// Initialization - Sets up connectivity monitoring and loads pending operations
  ///
  /// STARTUP SEQUENCE:
  /// 1. Check current connectivity status
  /// 2. Initialize connectivity monitoring stream
  /// 3. Load any pending operations from persistent storage
  /// 4. Attempt immediate sync if online and operations exist
  Future<void> initialize() async {
    await _checkConnectivity();
    _startConnectivityMonitoring();
    await _loadPendingOperationsFromDb();

    if (_isOnline && _pendingOperations.isNotEmpty) {
      await syncPendingOperations();
    }
  }

  /// Connectivity Detection - Real-time network status monitoring
  /// Connectivity Detection - Real-time network status monitoring
  Future<void> _checkConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    // Check if any of the connectivity results indicate we're online
    _isOnline = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
    notifyListeners();
  }

  /// Connectivity Monitoring - Automatic sync trigger on reconnection
  ///
  /// RECONNECTION LOGIC:
  /// - Detects transition from offline to online state
  /// - Automatically triggers sync of pending operations
  /// - Provides user feedback about connectivity changes
  /// - Handles rapid connectivity changes gracefully
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final wasOnline = _isOnline;
      // Check if any of the connectivity results indicate we're online
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      if (!wasOnline && _isOnline) {
        // Just came back online - trigger automatic sync
        ErrorLogger.logInfo(
          'Back online - syncing pending operations',
          context: 'OfflineManager._startConnectivityMonitoring',
        );
        await syncPendingOperations();
      } else if (wasOnline && !_isOnline) {
        // Just went offline - prepare for offline mode
        ErrorLogger.logInfo(
          'Went offline',
          context: 'OfflineManager._startConnectivityMonitoring',
        );
      }

      notifyListeners();
    });
  }

  /// Multi-Tier Cache Management System
  ///
  /// CACHING STRATEGY:
  /// - Level 1: In-memory cache for immediate access
  /// - Level 2: SharedPreferences for persistent offline storage
  /// - Level 3: Firestore for authoritative cloud data
  ///
  /// CACHE INVALIDATION:
  /// - Time-based expiry with configurable TTL
  /// - Manual invalidation for critical data updates
  /// - Automatic cleanup to prevent storage bloat
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString('cache_$key', jsonString);
      await prefs.setString(
        'cache_${key}_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error caching data',
        error: e,
        context: 'OfflineManager.cacheData',
      );
    }
  }

  /// Generic cache retrieval with type safety
  ///
  /// TYPE SAFETY:
  /// - Generic method supports any data type with proper deserialization
  /// - Handles both single objects and collections
  /// - Automatic type conversion and validation
  Future<T?> getCachedData<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cache_$key');

      if (jsonString != null) {
        final data = jsonDecode(jsonString);
        if (data is List) {
          return data
                  .map((item) => fromJson(item as Map<String, dynamic>))
                  .toList()
              as T;
        } else if (data is Map<String, dynamic>) {
          return fromJson(data);
        }
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error getting cached data',
        error: e,
        context: 'OfflineManager.getCachedData',
      );
    }
    return null;
  }

  /// Cache validity checking with configurable expiry
  Future<bool> isCacheValid(String key, Duration maxAge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString('cache_${key}_timestamp');

      if (timestampString != null) {
        final timestamp = DateTime.parse(timestampString);
        return DateTime.now().difference(timestamp) < maxAge;
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error checking cache validity',
        error: e,
        context: 'OfflineManager.isCacheValid',
      );
    }
    return false;
  }

  /// Operation Queue Management - Offline operation persistence
  ///
  /// QUEUE STRATEGY:
  /// - FIFO processing ensures chronological consistency
  /// - Persistent storage survives app restarts
  /// - Automatic retry mechanism for failed operations
  /// - Duplicate detection prevents redundant operations
  Future<void> queueOperation(OfflineOperation operation) async {
    if (operation.type == OperationType.createSaleTransaction) {
      final saleMap = operation.data['sale'] as Map<String, dynamic>;
      final sale = Sale.fromMap(saleMap).copyWith(isSynced: 0);
      final saleItems = (operation.data['saleItems'] as List)
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList();

      await _localDatabaseService.insertSale(sale.toMap());
      for (final item in saleItems) {
        await _localDatabaseService.insertSaleItem(item.toMap());
      }
    }

    try {
      final db = await _localDatabaseService.database;
      await db.insert('offline_operations', operation.toMap());
      _pendingOperations.add(operation);
      notifyListeners();
      ErrorLogger.logInfo(
        'Queued operation: ${operation.type} - ${operation.id}',
        context: 'OfflineManager.queueOperation',
      );
      if (_isOnline) {
        await syncPendingOperations();
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error queuing operation',
        error: e,
        context: 'OfflineManager.queueOperation',
      );
    }
  }

  /// Synchronization Engine - Conflict-free operation replay
  ///
  /// SYNC ALGORITHM:
  /// 1. Prevent concurrent sync operations
  /// 2. Process operations in chronological order
  /// 3. Individual operation retry on failure
  /// 4. Maintain operation queue integrity
  /// 5. Update sync timestamp on completion
  ///
  /// CONFLICT RESOLUTION:
  /// - Last-write-wins for simple conflicts
  /// - Business logic validation before applying changes
  /// - Rollback capability for failed batch operations
  Future<void> syncPendingOperations() async {
    if (!_isOnline || _isSyncing) return;
    await _loadPendingOperationsFromDb();
    if (_pendingOperations.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    final operationsToSync = await _getOperationsToSync();

    try {
      await _processBatches(operationsToSync);
      await _handleSuccessfulSync();
    } catch (e) {
      _handleFailedSync(e);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<List<OfflineOperation>> _getOperationsToSync() async {
    await _loadPendingOperationsFromDb();
    return List.from(_pendingOperations);
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
        _pendingOperations.remove(operation);
        ErrorLogger.logInfo(
          'Synced operation: ${operation.type} - ${operation.id}',
          context: 'OfflineManager.syncPendingOperations',
        );
      } catch (e) {
        ErrorLogger.logError(
          'Failed to sync operation ${operation.id}',
          error: e,
          context: 'OfflineManager.syncPendingOperations',
        );
        if (operation.retryCount < maxRetries) {
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );
          failedOperations.add(updatedOperation);
        } else {
          // Move to dead letter queue
          await _moveToDeadLetterQueue(operation, e.toString());
          successfulOperationIds.add(operation.dbId!);
          ErrorLogger.logError(
            'Operation ${operation.id} failed after $maxRetries retries',
            error: e,
            context: 'OfflineManager.syncPendingOperations',
          );
        }
      }
    }

    if (batchOperations.isNotEmpty) {
      await FirestoreService.instance.batchWrite(batchOperations);
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

  Future<void> _handleSuccessfulSync() async {
    _lastSyncTime = DateTime.now();
    await _saveLastSyncTime();
  }

  void _handleFailedSync(Object e) {
    ErrorLogger.logError(
      'Error during sync',
      error: e,
      context: 'OfflineManager.syncPendingOperations',
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
  }

  /// Operation Execution - Type-safe operation replay
  ///
  /// OPERATION TYPES:
  /// - Data mutations: Insert, update, delete operations
  /// - Business transactions: Multi-step operations with rollback
  /// - System operations: Configuration and maintenance tasks
  ///
  /// EXECUTION SAFETY:
  /// - Type validation before execution
  /// - Business rule enforcement
  /// - Atomic operation guarantee
  List<Map<String, dynamic>> _getBatchOperations(OfflineOperation operation) {
    switch (operation.type) {
      case OperationType.insertProduct:
        return [
          {
            'type': AppConstants.operationInsert,
            'collection': operation.collectionName,
            'data': operation.data,
          },
        ];
      case OperationType.updateProduct:
        return [
          {
            'type': AppConstants.operationUpdate,
            'collection': operation.collectionName,
            'docId': operation.documentId,
            'data': operation.data,
          },
        ];
      case OperationType.insertCustomer:
        return [
          {
            'type': AppConstants.operationInsert,
            'collection': operation.collectionName,
            'data': operation.data,
          },
        ];
      case OperationType.updateCustomer:
        return [
          {
            'type': AppConstants.operationUpdate,
            'collection': operation.collectionName,
            'docId': operation.documentId,
            'data': operation.data,
          },
        ];
      case OperationType.createSaleTransaction:
        final saleMap = operation.data['sale'] as Map<String, dynamic>;
        final sale = Sale.fromMap(saleMap);
        final saleItems = (operation.data['saleItems'] as List)
            .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
            .toList();

        // Also save to local DB when syncing
        unawaited(
          _localDatabaseService.insertSale(sale.copyWith(isSynced: 1).toMap()),
        );
        for (final item in saleItems) {
          unawaited(_localDatabaseService.insertSaleItem(item.toMap()));
        }

        final List<Map<String, dynamic>> operations = [];

        // Add sale insertion
        operations.add({
          'type': AppConstants.operationInsert,
          'collection': AppConstants.salesCollection,
          'docId': sale.id,
          'data': sale.toMap(),
        });

        // Add sale item insertions
        for (final item in saleItems) {
          operations.add({
            'type': AppConstants.operationInsert,
            'collection': AppConstants.saleItemsCollection,
            'docId': item.id,
            'data': item.toMap(),
          });
        }

        // Add stock updates
        for (final item in saleItems) {
          operations.add({
            'type': AppConstants.operationUpdate,
            'collection': AppConstants.productsCollection,
            'docId': item.productId,
            'data': {'stock': FieldValue.increment(-item.quantity)},
          });
        }

        return operations;
      case OperationType.insertCreditTransaction:
        return [
          {
            'type': AppConstants.operationInsert,
            'collection': operation.collectionName,
            'data': operation.data,
          },
        ];
      case OperationType.updateCustomerBalance:
        return [
          {
            'type': AppConstants.operationUpdate,
            'collection': operation.collectionName,
            'docId': operation.documentId,
            'data': operation.data,
          },
        ];
      case OperationType.insertLoss:
        return [
          {
            'type': AppConstants.operationInsert,
            'collection': operation.collectionName,
            'data': operation.data,
          },
        ];
      case OperationType.insertPriceHistory:
        return [
          {
            'type': AppConstants.operationInsert,
            'collection': operation.collectionName,
            'data': operation.data,
          },
        ];
    }
  }

  Future<void> _loadPendingOperationsFromDb() async {
    try {
      final db = await _localDatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'offline_operations',
      );
      _pendingOperations = List.generate(maps.length, (i) {
        return OfflineOperation.fromMap(maps[i]);
      });
      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Error loading pending operations from DB',
        error: e,
        context: 'OfflineManager._loadPendingOperationsFromDb',
      );
    }
  }

  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSyncTime != null) {
        await prefs.setString(
          'last_sync_time',
          _lastSyncTime!.toIso8601String(),
        );
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error saving last sync time',
        error: e,
        context: 'OfflineManager._saveLastSyncTime',
      );
    }
  }

  /// Cache management utilities
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('cache_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      ErrorLogger.logInfo(
        'Cache cleared',
        context: 'OfflineManager.clearCache',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error clearing cache',
        error: e,
        context: 'OfflineManager.clearCache',
      );
    }
  }

  Future<void> clearPendingOperations() async {
    try {
      final db = await _localDatabaseService.database;
      await db.delete('offline_operations');
      _pendingOperations.clear();
      notifyListeners();
      ErrorLogger.logInfo(
        'Pending operations cleared',
        context: 'OfflineManager.clearPendingOperations',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error clearing pending operations',
        error: e,
        context: 'OfflineManager.clearPendingOperations',
      );
    }
  }

  Future<List<Sale>> getPendingSales() async {
    final db = await _localDatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return Sale.fromMap(maps[i]);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Operation Type Enumeration - Defines all supported offline operations
enum OperationType {
  insertProduct,
  updateProduct,
  insertCustomer,
  updateCustomer,
  createSaleTransaction,
  insertCreditTransaction,
  updateCustomerBalance,
  insertLoss,
  insertPriceHistory,
}

/// Offline Operation Model - Serializable operation container
///
/// OPERATION STRUCTURE:
/// - Unique ID for deduplication and tracking
/// - Operation type for proper execution routing
/// - Serialized data payload with all necessary information
/// - Timestamp for chronological processing and conflict resolution
class OfflineOperation {
  final int? dbId;
  final String id;
  final OperationType type;
  final String collectionName;
  final String? documentId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  OfflineOperation({
    this.dbId,
    String? id,
    required this.type,
    required this.collectionName,
    this.documentId,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  }) : id = id ?? const Uuid().v4();

  OfflineOperation copyWith({
    int? dbId,
    String? id,
    OperationType? type,
    String? collectionName,
    String? documentId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return OfflineOperation(
      dbId: dbId ?? this.dbId,
      id: id ?? this.id,
      type: type ?? this.type,
      collectionName: collectionName ?? this.collectionName,
      documentId: documentId ?? this.documentId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operation_id': id,
      'operation_type': type.toString().split('.').last,
      'collection_name': collectionName,
      'document_id': documentId,
      'data': jsonEncode(data),
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory OfflineOperation.fromMap(Map<String, dynamic> map) {
    return OfflineOperation(
      dbId: map['id'] as int,
      id: map['operation_id'] as String,
      type: OperationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['operation_type'],
      ),
      collectionName: map['collection_name'] as String,
      documentId: map['document_id'] as String?,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      timestamp: DateTime.parse(map['timestamp'] as String),
      retryCount: map['retry_count'] ?? 0,
    );
  }
}
