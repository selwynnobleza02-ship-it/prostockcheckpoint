import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/product.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._init();
  static Database? _database;

  LocalDatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('prostock.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12, // Increment version to force price_history table creation
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _createTables(Database db) async {
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  imageUrl TEXT,
  localImagePath TEXT,
  balance REAL NOT NULL,
  credit_limit REAL NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  barcode TEXT,
  cost REAL NOT NULL,
  selling_price REAL,
  stock INTEGER NOT NULL,
  min_stock INTEGER NOT NULL,
  category TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sales (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  customer_id TEXT,
  total_amount REAL NOT NULL,
  payment_method TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  due_date TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS sale_items (
  id $textType,
  saleId $textType,
  productId $textType,
  batchId TEXT,
  quantity $integerType,
  unitPrice $doubleType,
  unitCost $doubleType,
  batchCost $doubleType,
  totalPrice $doubleType
)
''');

    // Credit transactions local cache
    await db.execute('''
CREATE TABLE IF NOT EXISTS credit_transactions (
  id TEXT PRIMARY KEY,
  customerId TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  createdAt TEXT,
  type TEXT NOT NULL,
  notes TEXT,
  items TEXT
)
''');

    // Inventory batches for FIFO tracking
    await db.execute('''
CREATE TABLE IF NOT EXISTS inventory_batches (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  batch_number TEXT NOT NULL,
  quantity_received INTEGER NOT NULL,
  quantity_remaining INTEGER NOT NULL,
  unit_cost REAL NOT NULL,
  date_received TEXT NOT NULL,
  supplier_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
)
''');

    // Indexes for batch queries
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_batches_product 
ON inventory_batches(product_id)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_batches_date 
ON inventory_batches(date_received)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_batches_remaining 
ON inventory_batches(quantity_remaining)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS losses (
  id TEXT PRIMARY KEY,
  productId TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  totalCost REAL NOT NULL,
  reason TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  recordedBy TEXT
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS offline_operations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  collection_name TEXT NOT NULL,
  document_id TEXT,
  data TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  version INTEGER
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS dead_letter_operations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  collection_name TEXT NOT NULL,
  document_id TEXT,
  data TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  error TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS price_history (
  id TEXT PRIMARY KEY,
  productId TEXT NOT NULL,
  price REAL NOT NULL,
  timestamp TEXT NOT NULL,
  batchId TEXT,
  batchNumber TEXT,
  cost REAL,
  reason TEXT,
  FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_price_history_product 
ON price_history(productId)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_price_history_timestamp 
ON price_history(timestamp)
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          "ALTER TABLE sale_items ADD COLUMN saleId TEXT NOT NULL DEFAULT ''",
        );
      } catch (e) {
        // Column might already exist, ignore
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          "ALTER TABLE sales ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0",
        );
      } catch (e) {
        // Column might already exist, ignore
      }
    }
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS offline_operations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  collection_name TEXT NOT NULL,
  document_id TEXT,
  data TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  version INTEGER
)
''');
    }
    if (oldVersion < 5) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS losses (
  id TEXT PRIMARY KEY,
  productId TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  totalCost REAL NOT NULL,
  reason TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  recordedBy TEXT
)
''');
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          "ALTER TABLE customers ADD COLUMN version INTEGER NOT NULL DEFAULT 1",
        );
      } catch (e) {
        // Column might already exist, ignore
      }
    }
    // Ensure credit_transactions table exists/updated for older installs
    if (oldVersion < 7) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS credit_transactions (
  id TEXT PRIMARY KEY,
  customerId TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  createdAt TEXT,
  type TEXT NOT NULL,
  notes TEXT,
  items TEXT
)
''');
    }
    // Add unitCost column to sale_items for accurate COGS tracking
    if (oldVersion < 8) {
      try {
        await db.execute(
          "ALTER TABLE sale_items ADD COLUMN unitCost REAL NOT NULL DEFAULT 0.0",
        );
      } catch (e) {
        // Column might already exist, ignore
      }
    }

    // Add FIFO batch tracking system
    if (oldVersion < 9) {
      // Add selling_price to products
      try {
        await db.execute("ALTER TABLE products ADD COLUMN selling_price REAL");
      } catch (e) {
        // Column might already exist, ignore
      }

      // Add batch tracking fields to sale_items
      try {
        await db.execute("ALTER TABLE sale_items ADD COLUMN batchId TEXT");
      } catch (e) {
        // Column might already exist, ignore
      }

      try {
        await db.execute(
          "ALTER TABLE sale_items ADD COLUMN batchCost REAL NOT NULL DEFAULT 0.0",
        );
      } catch (e) {
        // Column might already exist, ignore
      }

      // Create inventory_batches table
      await db.execute('''
CREATE TABLE IF NOT EXISTS inventory_batches (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  batch_number TEXT NOT NULL,
  quantity_received INTEGER NOT NULL,
  quantity_remaining INTEGER NOT NULL,
  unit_cost REAL NOT NULL,
  date_received TEXT NOT NULL,
  supplier_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
)
''');

      // Create indexes
      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_batches_product 
ON inventory_batches(product_id)
''');

      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_batches_date 
ON inventory_batches(date_received)
''');

      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_batches_remaining 
ON inventory_batches(quantity_remaining)
''');

      // Migrate existing stock to initial batches
      final products = await db.query('products');
      for (final product in products) {
        final stock = product['stock'] as int;
        if (stock > 0) {
          final now = DateTime.now().toIso8601String();
          await db.insert('inventory_batches', {
            'id': '${product['id']}-INITIAL',
            'product_id': product['id'],
            'batch_number': 'INITIAL-${product['id']}',
            'quantity_received': stock,
            'quantity_remaining': stock,
            'unit_cost': product['cost'],
            'date_received': now,
            'notes': 'Initial stock migration to FIFO system',
            'created_at': now,
            'updated_at': now,
          });
        }
      }
    }

    // Backfill unitCost for old sale items (pre-FIFO sales)
    if (oldVersion < 10) {
      // Get all sale items with zero or null unitCost
      final saleItems = await db.query(
        'sale_items',
        where: 'unitCost IS NULL OR unitCost = 0.0',
      );

      if (saleItems.isNotEmpty) {
        // Get current product costs for fallback
        final products = await db.query('products');
        final productCostMap = {for (var p in products) p['id']: p['cost']};

        // Update each sale item with the product's current cost
        for (final item in saleItems) {
          final productId = item['productId'] as String?;
          if (productId != null && productCostMap.containsKey(productId)) {
            final cost = productCostMap[productId] as double;
            await db.update(
              'sale_items',
              {
                'unitCost': cost,
                'batchCost': cost, // Also update batchCost for consistency
              },
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          }
        }
      }
    }

    // Add price_history table for offline price history tracking
    if (oldVersion < 11) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS price_history (
  id TEXT PRIMARY KEY,
  productId TEXT NOT NULL,
  price REAL NOT NULL,
  timestamp TEXT NOT NULL,
  batchId TEXT,
  batchNumber TEXT,
  cost REAL,
  reason TEXT,
  FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
)
''');

      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_price_history_product 
ON price_history(productId)
''');

      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_price_history_timestamp 
ON price_history(timestamp)
''');
    }

    // Ensure price_history table exists for version 12 (redundant but safe)
    if (oldVersion < 12) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS price_history (
  id TEXT PRIMARY KEY,
  productId TEXT NOT NULL,
  price REAL NOT NULL,
  timestamp TEXT NOT NULL,
  batchId TEXT,
  batchNumber TEXT,
  cost REAL,
  reason TEXT,
  FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
)
''');

      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_price_history_product 
ON price_history(productId)
''');

      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_price_history_timestamp 
ON price_history(timestamp)
''');
    }
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await instance.database;
    return await db.query('sales');
  }

  Future<List<Map<String, dynamic>>> getSalesSince(DateTime since) async {
    final db = await instance.database;
    return await db.query(
      'sales',
      where: 'created_at >= ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> insertSale(Sale sale) async {
    final db = await instance.database;
    return await db.insert('sales', sale.toMap());
  }

  Future<int> insertSaleItem(SaleItem saleItem) async {
    final db = await instance.database;
    return await db.insert('sale_items', saleItem.toMap());
  }

  // Credit transactions local cache methods
  Future<int> insertCreditTransaction(Map<String, dynamic> tx) async {
    final db = await instance.database;
    return await db.insert(
      'credit_transactions',
      tx,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCreditTransactionsByCustomer(
    String customerId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'credit_transactions',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllCreditTransactions() async {
    final db = await instance.database;
    return await db.query('credit_transactions', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final db = await instance.database;
    // Aggregate duplicates that may exist due to offline queue + sync overlap
    return await db.rawQuery(
      'SELECT productId, saleId, '
      'SUM(quantity) AS quantity, '
      'ROUND(SUM(totalPrice), 2) AS totalPrice, '
      // Derive unitPrice from summed totals to keep consistency
      'CASE WHEN SUM(quantity) > 0 THEN ROUND(SUM(totalPrice)/SUM(quantity), 2) ELSE 0 END AS unitPrice '
      'FROM sale_items WHERE saleId = ? '
      'GROUP BY saleId, productId',
      [saleId],
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItemsBySaleIds(
    List<String> saleIds,
  ) async {
    final db = await instance.database;
    if (saleIds.isEmpty) {
      return [];
    }
    final ids = saleIds.map((id) => '?').join(',');
    return await db.rawQuery(
      'SELECT productId, saleId, '
      'SUM(quantity) AS quantity, '
      'ROUND(SUM(totalPrice), 2) AS totalPrice, '
      'CASE WHEN SUM(quantity) > 0 THEN ROUND(SUM(totalPrice)/SUM(quantity), 2) ELSE 0 END AS unitPrice '
      'FROM sale_items WHERE saleId IN ($ids) '
      'GROUP BY saleId, productId',
      saleIds,
    );
  }

  Future<void> markSaleAsSynced(String saleId) async {
    final db = await instance.database;
    await db.update(
      'sales',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final rows = await db.query('products');
    return rows.map((m) => Product.fromMap(m)).toList();
  }

  Future<void> updateProductMinStock(String productId, int newMinStock) async {
    final db = await instance.database;
    await db.update(
      'products',
      {
        'min_stock': newMinStock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<Map<String, dynamic>>> getLosses() async {
    final db = await instance.database;
    return await db.query('losses', orderBy: 'timestamp DESC');
  }

  // Price History Methods
  Future<void> insertPriceHistory(Map<String, dynamic> priceHistory) async {
    final db = await instance.database;
    await db.insert(
      'price_history',
      priceHistory,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPriceHistory(String productId) async {
    final db = await instance.database;
    return await db.query(
      'price_history',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> deletePriceHistory(String id) async {
    final db = await instance.database;
    await db.delete('price_history', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
