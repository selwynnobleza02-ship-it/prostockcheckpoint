import 'dart:async';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';

/// Event store for implementing event sourcing pattern
class EventStore {
  final LocalDatabaseService _localDatabaseService;
  final StreamController<DomainEvent> _eventStreamController =
      StreamController<DomainEvent>.broadcast();

  EventStore(this._localDatabaseService);

  /// Get event stream
  Stream<DomainEvent> get eventStream => _eventStreamController.stream;

  /// Append an event to the store
  Future<void> appendEvent(DomainEvent event) async {
    try {
      final db = await _localDatabaseService.database;

      await db.insert('events', {
        'id': event.id,
        'aggregate_id': event.aggregateId,
        'event_type': event.eventType,
        'event_data': event.eventData,
        'timestamp': event.timestamp.toIso8601String(),
        'version': event.version,
        'metadata': event.metadata,
      });

      // Emit event to stream
      _eventStreamController.add(event);

      ErrorLogger.logInfo(
        'Event ${event.id} appended to store',
        context: 'EventStore.appendEvent',
        metadata: {
          'eventType': event.eventType,
          'aggregateId': event.aggregateId,
        },
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to append event ${event.id}',
        error: e,
        context: 'EventStore.appendEvent',
      );
      rethrow;
    }
  }

  /// Get events for a specific aggregate
  Future<List<DomainEvent>> getEventsForAggregate(String aggregateId) async {
    try {
      final db = await _localDatabaseService.database;
      final results = await db.query(
        'events',
        where: 'aggregate_id = ?',
        whereArgs: [aggregateId],
        orderBy: 'version ASC',
      );

      return results.map((row) => DomainEvent.fromMap(row)).toList();
    } catch (e) {
      ErrorLogger.logError(
        'Failed to get events for aggregate $aggregateId',
        error: e,
        context: 'EventStore.getEventsForAggregate',
      );
      return [];
    }
  }

  /// Get events by type
  Future<List<DomainEvent>> getEventsByType(String eventType) async {
    try {
      final db = await _localDatabaseService.database;
      final results = await db.query(
        'events',
        where: 'event_type = ?',
        whereArgs: [eventType],
        orderBy: 'timestamp ASC',
      );

      return results.map((row) => DomainEvent.fromMap(row)).toList();
    } catch (e) {
      ErrorLogger.logError(
        'Failed to get events by type $eventType',
        error: e,
        context: 'EventStore.getEventsByType',
      );
      return [];
    }
  }

  /// Get events since a specific timestamp
  Future<List<DomainEvent>> getEventsSince(DateTime timestamp) async {
    try {
      final db = await _localDatabaseService.database;
      final results = await db.query(
        'events',
        where: 'timestamp > ?',
        whereArgs: [timestamp.toIso8601String()],
        orderBy: 'timestamp ASC',
      );

      return results.map((row) => DomainEvent.fromMap(row)).toList();
    } catch (e) {
      ErrorLogger.logError(
        'Failed to get events since $timestamp',
        error: e,
        context: 'EventStore.getEventsSince',
      );
      return [];
    }
  }

  /// Replay events to rebuild aggregate state
  Future<T> replayEvents<T>(
    String aggregateId,
    T Function(List<DomainEvent>) replayer,
  ) async {
    try {
      final events = await getEventsForAggregate(aggregateId);
      return replayer(events);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to replay events for aggregate $aggregateId',
        error: e,
        context: 'EventStore.replayEvents',
      );
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _eventStreamController.close();
  }
}

/// Represents a domain event
class DomainEvent {
  final String id;
  final String aggregateId;
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime timestamp;
  final int version;
  final Map<String, dynamic> metadata;

  DomainEvent({
    required this.id,
    required this.aggregateId,
    required this.eventType,
    required this.eventData,
    required this.timestamp,
    required this.version,
    this.metadata = const {},
  });

  /// Create from database map
  factory DomainEvent.fromMap(Map<String, dynamic> map) {
    return DomainEvent(
      id: map['id'] as String,
      aggregateId: map['aggregate_id'] as String,
      eventType: map['event_type'] as String,
      eventData: Map<String, dynamic>.from(map['event_data'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
      version: map['version'] as int,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'aggregate_id': aggregateId,
      'event_type': eventType,
      'event_data': eventData,
      'timestamp': timestamp.toIso8601String(),
      'version': version,
      'metadata': metadata,
    };
  }
}
