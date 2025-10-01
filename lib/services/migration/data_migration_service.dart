import 'dart:async';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/event_sourcing/event_store.dart';
import 'package:prostock/utils/error_logger.dart';

/// Service for migrating data to the new architecture
class DataMigrationService {
  final LocalDatabaseService _localDatabaseService;
  final EventStore _eventStore;

  DataMigrationService({
    required LocalDatabaseService localDatabaseService,
    required EventStore eventStore,
  }) : _localDatabaseService = localDatabaseService,
       _eventStore = eventStore;

  /// Migrate existing data to event sourcing
  Future<void> migrateToEventSourcing() async {
    try {
      ErrorLogger.logInfo(
        'Starting data migration to event sourcing',
        context: 'DataMigrationService.migrateToEventSourcing',
      );

      // 1. Migrate sales data
      await _migrateSalesData();

      // 2. Migrate credit transactions
      await _migrateCreditTransactions();

      // 3. Migrate product data
      await _migrateProductData();

      // 4. Migrate customer data
      await _migrateCustomerData();

      ErrorLogger.logInfo(
        'Data migration completed successfully',
        context: 'DataMigrationService.migrateToEventSourcing',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Data migration failed',
        error: e,
        context: 'DataMigrationService.migrateToEventSourcing',
      );
      rethrow;
    }
  }

  /// Migrate sales data to events
  Future<void> _migrateSalesData() async {
    try {
      final db = await _localDatabaseService.database;
      final sales = await db.query('sales');

      for (final sale in sales) {
        final event = DomainEvent(
          id: '${sale['id']}_created',
          aggregateId: sale['id'] as String,
          eventType: 'SaleCreated',
          eventData: {
            'id': sale['id'],
            'customerId': sale['customer_id'],
            'totalAmount': sale['total_amount'],
            'paymentMethod': sale['payment_method'],
            'status': sale['status'] ?? 'completed',
            'createdAt': sale['created_at'],
            'userId': sale['user_id'],
            'dueDate': sale['due_date'],
          },
          timestamp: DateTime.parse(sale['created_at'] as String),
          version: 1,
        );

        await _eventStore.appendEvent(event);
      }

      ErrorLogger.logInfo(
        'Migrated ${sales.length} sales to events',
        context: 'DataMigrationService._migrateSalesData',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to migrate sales data',
        error: e,
        context: 'DataMigrationService._migrateSalesData',
      );
    }
  }

  /// Migrate credit transactions to events
  Future<void> _migrateCreditTransactions() async {
    try {
      final db = await _localDatabaseService.database;
      final transactions = await db.query('credit_transactions');

      for (final transaction in transactions) {
        final event = DomainEvent(
          id: '${transaction['id']}_created',
          aggregateId: transaction['id'] as String,
          eventType: 'CreditTransactionCreated',
          eventData: {
            'id': transaction['id'],
            'customerId': transaction['customerId'],
            'amount': transaction['amount'],
            'type': transaction['type'],
            'date': transaction['date'],
            'notes': transaction['notes'],
            'items': transaction['items'],
          },
          timestamp: DateTime.parse(transaction['date'] as String),
          version: 1,
        );

        await _eventStore.appendEvent(event);
      }

      ErrorLogger.logInfo(
        'Migrated ${transactions.length} credit transactions to events',
        context: 'DataMigrationService._migrateCreditTransactions',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to migrate credit transactions',
        error: e,
        context: 'DataMigrationService._migrateCreditTransactions',
      );
    }
  }

  /// Migrate product data to events
  Future<void> _migrateProductData() async {
    try {
      final db = await _localDatabaseService.database;
      final products = await db.query('products');

      for (final product in products) {
        final event = DomainEvent(
          id: '${product['id']}_created',
          aggregateId: product['id'] as String,
          eventType: 'ProductCreated',
          eventData: {
            'id': product['id'],
            'name': product['name'],
            'description': product['description'],
            'cost': product['cost'],
            'sellingPrice': product['selling_price'],
            'stock': product['stock'],
            'category': product['category'],
            'barcode': product['barcode'],
            'imageUrl': product['image_url'],
            'createdAt': product['created_at'],
            'updatedAt': product['updated_at'],
          },
          timestamp: DateTime.parse(product['created_at'] as String),
          version: 1,
        );

        await _eventStore.appendEvent(event);
      }

      ErrorLogger.logInfo(
        'Migrated ${products.length} products to events',
        context: 'DataMigrationService._migrateProductData',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to migrate product data',
        error: e,
        context: 'DataMigrationService._migrateProductData',
      );
    }
  }

  /// Migrate customer data to events
  Future<void> _migrateCustomerData() async {
    try {
      final db = await _localDatabaseService.database;
      final customers = await db.query('customers');

      for (final customer in customers) {
        final event = DomainEvent(
          id: '${customer['id']}_created',
          aggregateId: customer['id'] as String,
          eventType: 'CustomerCreated',
          eventData: {
            'id': customer['id'],
            'name': customer['name'],
            'phone': customer['phone'],
            'email': customer['email'],
            'address': customer['address'],
            'balance': customer['balance'],
            'creditLimit': customer['credit_limit'],
            'imageUrl': customer['image_url'],
            'createdAt': customer['created_at'],
            'updatedAt': customer['updated_at'],
          },
          timestamp: DateTime.parse(customer['created_at'] as String),
          version: 1,
        );

        await _eventStore.appendEvent(event);
      }

      ErrorLogger.logInfo(
        'Migrated ${customers.length} customers to events',
        context: 'DataMigrationService._migrateCustomerData',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to migrate customer data',
        error: e,
        context: 'DataMigrationService._migrateCustomerData',
      );
    }
  }
}
