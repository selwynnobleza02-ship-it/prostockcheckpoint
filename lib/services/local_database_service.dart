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
      version: 6,
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
  quantity $integerType,
  unitPrice $doubleType,
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
  type TEXT NOT NULL,
  notes TEXT
)
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

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final db = await instance.database;
    return await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
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
    return await db.query(
      'sale_items',
      where: 'saleId IN ($ids)',
      whereArgs: saleIds,
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
