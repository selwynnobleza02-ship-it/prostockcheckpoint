import 'dart:async';
import 'package:prostock/services/event_sourcing/event_store.dart';
import 'package:prostock/services/cqrs/command_handler.dart';
import 'package:prostock/services/cqrs/query_handler.dart';
import 'package:prostock/services/conflict_resolver.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Manages data consistency across the application
class DataConsistencyManager {
  final EventStore _eventStore;
  final LocalDatabaseService _localDatabaseService;

  final Map<String, StreamSubscription> _eventSubscriptions = {};
  final Map<String, DateTime> _lastProcessedEvents = {};

  DataConsistencyManager({
    required EventStore eventStore,
    required CommandHandler commandHandler,
    required QueryHandler queryHandler,
    required ConflictResolver conflictResolver,
    required LocalDatabaseService localDatabaseService,
  }) : _eventStore = eventStore,
       _localDatabaseService = localDatabaseService;

  /// Initialize the consistency manager
  Future<void> initialize() async {
    try {
      // Set up event listeners for consistency
      await _setupEventListeners();

      // Process any unprocessed events
      await _processUnprocessedEvents();

      ErrorLogger.logInfo(
        'DataConsistencyManager initialized',
        context: 'DataConsistencyManager.initialize',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to initialize DataConsistencyManager',
        error: e,
        context: 'DataConsistencyManager.initialize',
      );
      rethrow;
    }
  }

  /// Set up event listeners for maintaining consistency
  Future<void> _setupEventListeners() async {
    // Listen to all events
    _eventSubscriptions['all_events'] = _eventStore.eventStream.listen(
      _handleEvent,
      onError: (error) {
        ErrorLogger.logError(
          'Event stream error',
          error: error,
          context: 'DataConsistencyManager._setupEventListeners',
        );
      },
    );
  }

  /// Handle incoming events for consistency
  Future<void> _handleEvent(DomainEvent event) async {
    try {
      ErrorLogger.logInfo(
        'Processing event ${event.eventType} for aggregate ${event.aggregateId}',
        context: 'DataConsistencyManager._handleEvent',
      );

      // Update read models based on event type
      await _updateReadModels(event);

      // Mark event as processed
      _lastProcessedEvents[event.id] = DateTime.now();

      ErrorLogger.logInfo(
        'Event ${event.id} processed successfully',
        context: 'DataConsistencyManager._handleEvent',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to process event ${event.id}',
        error: e,
        context: 'DataConsistencyManager._handleEvent',
      );
    }
  }

  /// Update read models based on events
  Future<void> _updateReadModels(DomainEvent event) async {
    switch (event.eventType) {
      case 'SaleCreated':
        await _updateSalesReadModel(event);
        break;
      case 'CreditTransactionCreated':
        await _updateCreditReadModel(event);
        break;
      case 'StockUpdated':
        await _updateInventoryReadModel(event);
        break;
      case 'CustomerUpdated':
        await _updateCustomerReadModel(event);
        break;
      default:
        ErrorLogger.logInfo(
          'No read model update needed for event type ${event.eventType}',
          context: 'DataConsistencyManager._updateReadModels',
        );
    }
  }

  /// Update sales read model
  Future<void> _updateSalesReadModel(DomainEvent event) async {
    try {
      final saleData = event.eventData;
      final db = await _localDatabaseService.database;

      // Update sales table
      await db.insert('sales_read_model', {
        'id': saleData['id'],
        'customer_id': saleData['customerId'],
        'total_amount': saleData['totalAmount'],
        'payment_method': saleData['paymentMethod'],
        'status': saleData['status'],
        'created_at': saleData['createdAt'],
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Update sale items
      final saleItems = saleData['items'] as List<dynamic>? ?? [];
      for (final item in saleItems) {
        await db.insert('sale_items_read_model', {
          'id': item['id'],
          'sale_id': saleData['id'],
          'product_id': item['productId'],
          'quantity': item['quantity'],
          'unit_price': item['unitPrice'],
          'total_price': item['totalPrice'],
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      ErrorLogger.logError(
        'Failed to update sales read model for event ${event.id}',
        error: e,
        context: 'DataConsistencyManager._updateSalesReadModel',
      );
    }
  }

  /// Update credit read model
  Future<void> _updateCreditReadModel(DomainEvent event) async {
    try {
      final transactionData = event.eventData;
      final db = await _localDatabaseService.database;

      await db.insert(
        'credit_transactions_read_model',
        {
          'id': transactionData['id'],
          'customer_id': transactionData['customerId'],
          'amount': transactionData['amount'],
          'type': transactionData['type'],
          'date': transactionData['date'],
          'notes': transactionData['notes'],
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to update credit read model for event ${event.id}',
        error: e,
        context: 'DataConsistencyManager._updateCreditReadModel',
      );
    }
  }

  /// Update inventory read model
  Future<void> _updateInventoryReadModel(DomainEvent event) async {
    try {
      final stockData = event.eventData;
      final db = await _localDatabaseService.database;

      await db.update(
        'products',
        {
          'stock': stockData['newStock'],
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [stockData['productId']],
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to update inventory read model for event ${event.id}',
        error: e,
        context: 'DataConsistencyManager._updateInventoryReadModel',
      );
    }
  }

  /// Update customer read model
  Future<void> _updateCustomerReadModel(DomainEvent event) async {
    try {
      final customerData = event.eventData;
      final db = await _localDatabaseService.database;

      await db.update(
        'customers',
        {
          'balance': customerData['balance'],
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerData['id']],
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to update customer read model for event ${event.id}',
        error: e,
        context: 'DataConsistencyManager._updateCustomerReadModel',
      );
    }
  }

  /// Process any unprocessed events
  Future<void> _processUnprocessedEvents() async {
    try {
      final lastProcessed = _lastProcessedEvents.values.isNotEmpty
          ? _lastProcessedEvents.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now().subtract(const Duration(days: 1));

      final unprocessedEvents = await _eventStore.getEventsSince(lastProcessed);

      for (final event in unprocessedEvents) {
        await _handleEvent(event);
      }

      ErrorLogger.logInfo(
        'Processed ${unprocessedEvents.length} unprocessed events',
        context: 'DataConsistencyManager._processUnprocessedEvents',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to process unprocessed events',
        error: e,
        context: 'DataConsistencyManager._processUnprocessedEvents',
      );
    }
  }

  /// Ensure consistency across all data
  Future<void> ensureConsistency() async {
    try {
      ErrorLogger.logInfo(
        'Starting consistency check',
        context: 'DataConsistencyManager.ensureConsistency',
      );

      // Rebuild all read models from events
      await _rebuildReadModels();

      ErrorLogger.logInfo(
        'Consistency check completed',
        context: 'DataConsistencyManager.ensureConsistency',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to ensure consistency',
        error: e,
        context: 'DataConsistencyManager.ensureConsistency',
      );
    }
  }

  /// Rebuild read models from events
  Future<void> _rebuildReadModels() async {
    try {
      // Get all events
      final allEvents = await _eventStore.getEventsSince(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      // Clear read models
      final db = await _localDatabaseService.database;
      await db.delete('sales_read_model');
      await db.delete('sale_items_read_model');
      await db.delete('credit_transactions_read_model');

      // Rebuild from events
      for (final event in allEvents) {
        await _updateReadModels(event);
      }
    } catch (e) {
      ErrorLogger.logError(
        'Failed to rebuild read models',
        error: e,
        context: 'DataConsistencyManager._rebuildReadModels',
      );
    }
  }

  /// Dispose resources
  void dispose() {
    for (final subscription in _eventSubscriptions.values) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();
  }
}
