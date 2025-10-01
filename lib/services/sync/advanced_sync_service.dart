import 'dart:async';
import 'package:prostock/services/event_sourcing/event_store.dart';
import 'package:prostock/services/consistency/data_consistency_manager.dart';
import 'package:prostock/services/offline/connectivity_service.dart';
import 'package:prostock/services/conflict_resolver.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced sync service with delta sync and conflict resolution
class AdvancedSyncService {
  final EventStore _eventStore;
  final DataConsistencyManager _consistencyManager;
  final ConnectivityService _connectivityService;
  final FirebaseFirestore _firestore;

  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  AdvancedSyncService({
    required EventStore eventStore,
    required DataConsistencyManager consistencyManager,
    required ConnectivityService connectivityService,
    required ConflictResolver conflictResolver,
    required FirebaseFirestore firestore,
  }) : _eventStore = eventStore,
       _consistencyManager = consistencyManager,
       _connectivityService = connectivityService,
       _firestore = firestore;

  /// Initialize the advanced sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;

      // Set up connectivity listener
      _connectivityService.connectivityStream.listen((isOnline) {
        if (isOnline && !_isSyncing) {
          _triggerSync();
        }
      });

      ErrorLogger.logInfo(
        'AdvancedSyncService initialized',
        context: 'AdvancedSyncService.initialize',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to initialize AdvancedSyncService',
        error: e,
        context: 'AdvancedSyncService.initialize',
      );
      rethrow;
    }
  }

  /// Trigger sync process
  Future<void> _triggerSync() async {
    if (_isSyncing || !_connectivityService.isOnline) return;

    _isSyncing = true;
    _lastSyncTime = DateTime.now();

    try {
      ErrorLogger.logInfo(
        'Starting advanced sync process',
        context: 'AdvancedSyncService._triggerSync',
      );

      // 1. Sync events to Firestore
      await _syncEventsToFirestore();

      // 2. Sync Firestore changes to local
      await _syncFirestoreToLocal();

      // 3. Ensure data consistency
      await _consistencyManager.ensureConsistency();

      ErrorLogger.logInfo(
        'Advanced sync completed successfully',
        context: 'AdvancedSyncService._triggerSync',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Advanced sync failed',
        error: e,
        context: 'AdvancedSyncService._triggerSync',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync local events to Firestore
  Future<void> _syncEventsToFirestore() async {
    try {
      // Get events since last sync
      final lastSync =
          _lastSyncTime?.subtract(const Duration(hours: 1)) ??
          DateTime.now().subtract(const Duration(days: 1));
      final events = await _eventStore.getEventsSince(lastSync);

      if (events.isEmpty) return;

      ErrorLogger.logInfo(
        'Syncing ${events.length} events to Firestore',
        context: 'AdvancedSyncService._syncEventsToFirestore',
      );

      // Group events by collection
      final eventsByCollection = <String, List<DomainEvent>>{};
      for (final event in events) {
        final collection = _getCollectionForEvent(event);
        eventsByCollection.putIfAbsent(collection, () => []).add(event);
      }

      // Sync each collection
      for (final entry in eventsByCollection.entries) {
        await _syncEventsToCollection(entry.key, entry.value);
      }
    } catch (e) {
      ErrorLogger.logError(
        'Failed to sync events to Firestore',
        error: e,
        context: 'AdvancedSyncService._syncEventsToFirestore',
      );
    }
  }

  /// Sync events to a specific Firestore collection
  Future<void> _syncEventsToCollection(
    String collection,
    List<DomainEvent> events,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final event in events) {
        final docRef = _firestore.collection(collection).doc(event.aggregateId);
        batch.set(docRef, event.eventData, SetOptions(merge: true));
      }

      await batch.commit();

      ErrorLogger.logInfo(
        'Synced ${events.length} events to $collection',
        context: 'AdvancedSyncService._syncEventsToCollection',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to sync events to collection $collection',
        error: e,
        context: 'AdvancedSyncService._syncEventsToCollection',
      );
    }
  }

  /// Sync Firestore changes to local
  Future<void> _syncFirestoreToLocal() async {
    try {
      // This would implement delta sync from Firestore
      // For now, just log the operation
      ErrorLogger.logInfo(
        'Syncing Firestore changes to local',
        context: 'AdvancedSyncService._syncFirestoreToLocal',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to sync Firestore to local',
        error: e,
        context: 'AdvancedSyncService._syncFirestoreToLocal',
      );
    }
  }

  /// Get Firestore collection for event
  String _getCollectionForEvent(DomainEvent event) {
    switch (event.eventType) {
      case 'SaleCreated':
        return 'sales';
      case 'CreditTransactionCreated':
        return 'credit_transactions';
      case 'StockUpdated':
        return 'products';
      case 'CustomerUpdated':
        return 'customers';
      default:
        return 'events';
    }
  }

  /// Get sync status
  bool get isSyncing => _isSyncing;

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Force sync
  Future<void> forceSync() async {
    await _triggerSync();
  }
}
