import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/providers/sync_failure_provider.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/offline/cache_service.dart';
import 'package:prostock/services/offline/connectivity_service.dart';
import 'package:prostock/services/offline/operation_queue_service.dart';
import 'package:prostock/services/offline/sync_service.dart';

class OfflineManager with ChangeNotifier {
  final SyncFailureProvider _syncFailureProvider;

  final ConnectivityService _connectivityService = ConnectivityService();
  final CacheService _cacheService = CacheService();
  final OperationQueueService _queueService = OperationQueueService(
    LocalDatabaseService.instance,
  );
  late final SyncService _syncService = SyncService(
    _queueService,
    LocalDatabaseService.instance,
    _syncFailureProvider,
  )..setProgressCallback(_updateSyncProgress);

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  List<OfflineOperation> _pendingOperations = [];
  int _syncProgress = 0;
  int _totalOperationsToSync = 0;

  OfflineManager(this._syncFailureProvider);

  bool get isOnline => _connectivityService.isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<OfflineOperation> get pendingOperations =>
      List.unmodifiable(_pendingOperations);
  int get pendingOperationsCount => _pendingOperations.length;
  int get syncProgress => _syncProgress;
  int get totalOperationsToSync => _totalOperationsToSync;

  Future<void> initialize() async {
    await _connectivityService.initialize();
    _connectivityService.connectivityStream.listen((_) => _onConnectivityChanged());
    _pendingOperations = await _queueService.getPendingOperations();
    notifyListeners();
    if (isOnline) {
      await syncPendingOperations();
    }
  }

  void _onConnectivityChanged() async {
    if (isOnline) {
      await syncPendingOperations();
    }
    notifyListeners();
  }

  Future<void> queueOperation(OfflineOperation operation) async {
    await _queueService.queueOperation(operation);
    _pendingOperations = await _queueService.getPendingOperations();
    notifyListeners();
    if (isOnline) {
      await syncPendingOperations();
    }
  }

  Future<void> syncPendingOperations() async {
    if (isSyncing) return;

    _isSyncing = true;
    _pendingOperations = await _queueService.getPendingOperations();
    _totalOperationsToSync = _pendingOperations.length;
    _syncProgress = 0;
    notifyListeners();

    await _syncService.syncPendingOperations();

    _pendingOperations = await _queueService.getPendingOperations();
    _isSyncing = false;
    _syncProgress = 0;
    _totalOperationsToSync = 0;
    _lastSyncTime = DateTime.now();
    await _cacheService.saveLastSyncTime(_lastSyncTime!);
    notifyListeners();
  }

  Future<List<Sale>> getPendingSales() async {
    return await _queueService.getPendingSales();
  }

  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }

  void _updateSyncProgress(int completed, int total) {
    _syncProgress = completed;
    _totalOperationsToSync = total;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }
}
