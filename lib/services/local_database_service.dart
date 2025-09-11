import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
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

    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
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
  updated_at TEXT NOT NULL
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _createTables(db); // Ensure all tables exist

    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE sale_items ADD COLUMN saleId TEXT NOT NULL DEFAULT ''");
      } catch (e) {
        // Column might already exist, ignore
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0");
      } catch (e) {
        // Column might already exist, ignore
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await instance.database;
    return await db.query('sales');
  }

  Future<int> insertSale(Sale sale) async {
    final db = await instance.database;
    return await db.insert('sales', sale.toMap());
  }

  Future<int> insertSaleItem(SaleItem saleItem) async {
    final db = await instance.database;
    return await db.insert('sale_items', saleItem.toMap());
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final db = await instance.database;
    return await db.query('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
