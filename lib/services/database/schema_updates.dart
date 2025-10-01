import 'package:prostock/utils/error_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Database schema updates for event sourcing and CQRS
class SchemaUpdates {
  static const int currentVersion = 8;

  /// Apply all schema updates
  static Future<void> applyUpdates(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    try {
      if (oldVersion < 2) {
        await _createEventSourcingTables(db);
      }

      if (oldVersion < 3) {
        await _createCQRSReadModelTables(db);
      }

      ErrorLogger.logInfo(
        'Database schema updated from version $oldVersion to $newVersion',
        context: 'SchemaUpdates.applyUpdates',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to apply database schema updates',
        error: e,
        context: 'SchemaUpdates.applyUpdates',
      );
      rethrow;
    }
  }

  /// Create event sourcing tables
  static Future<void> _createEventSourcingTables(Database db) async {
    // Events table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        aggregate_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        version INTEGER NOT NULL,
        metadata TEXT NOT NULL DEFAULT '{}'
      )
    ''');

    // Create indexes for events
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_aggregate_id ON events(aggregate_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_event_type ON events(event_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp)',
    );

    // Snapshots table for aggregate snapshots
    await db.execute('''
      CREATE TABLE IF NOT EXISTS snapshots (
        aggregate_id TEXT PRIMARY KEY,
        aggregate_type TEXT NOT NULL,
        snapshot_data TEXT NOT NULL,
        version INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    ErrorLogger.logInfo(
      'Event sourcing tables created',
      context: 'SchemaUpdates._createEventSourcingTables',
    );
  }

  /// Create CQRS read model tables
  static Future<void> _createCQRSReadModelTables(Database db) async {
    // Sales read model
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_read_model (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sale items read model
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items_read_model (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales_read_model(id)
      )
    ''');

    // Credit transactions read model
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_transactions_read_model (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for read models
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales_read_model(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales_read_model(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items_read_model(sale_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_credit_transactions_customer_id ON credit_transactions_read_model(customer_id)',
    );

    ErrorLogger.logInfo(
      'CQRS read model tables created',
      context: 'SchemaUpdates._createCQRSReadModelTables',
    );
  }

  /// Create consistency check tables
  static Future<void> createConsistencyTables(Database db) async {
    // Consistency checkpoints
    await db.execute('''
      CREATE TABLE IF NOT EXISTS consistency_checkpoints (
        id TEXT PRIMARY KEY,
        checkpoint_type TEXT NOT NULL,
        last_processed_event_id TEXT,
        last_processed_timestamp TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Data integrity checks
    await db.execute('''
      CREATE TABLE IF NOT EXISTS integrity_checks (
        id TEXT PRIMARY KEY,
        check_type TEXT NOT NULL,
        status TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');

    ErrorLogger.logInfo(
      'Consistency check tables created',
      context: 'SchemaUpdates.createConsistencyTables',
    );
  }
}
