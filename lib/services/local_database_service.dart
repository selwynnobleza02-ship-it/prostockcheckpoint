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

    return await openDatabase(path, version: 9, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var i = oldVersion; i < newVersion; i++) {
      switch (i) {
        case 2:
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              operation_type TEXT NOT NULL,
              collection_name TEXT NOT NULL,
              document_id TEXT,
              data TEXT NOT NULL,
              timestamp TEXT NOT NULL
            )
            ''');
          break;
        case 3:
          await db.execute('ALTER TABLE products ADD COLUMN version INTEGER DEFAULT 1');
          break;
        case 4:
          await db.execute('ALTER TABLE offline_operations ADD COLUMN retry_count INTEGER DEFAULT 0');
          break;
        case 5:
          await db.execute('ALTER TABLE offline_operations ADD COLUMN operation_id TEXT');
          break;
        case 6:
          await _createSalesTables(db);
          break;
        case 7:
          await _createLossesTable(db);
          break;
        case 8:
          await db.execute('ALTER TABLE offline_operations ADD COLUMN version INTEGER');
          break;
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        stock INTEGER NOT NULL,
        min_stock INTEGER NOT NULL,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version INTEGER DEFAULT 1
      )
      ''');
    await db.execute('''
      CREATE TABLE offline_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT,
        operation_type TEXT NOT NULL,
        collection_name TEXT NOT NULL,
        document_id TEXT,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        version INTEGER
      )
      ''');
    await db.execute('''
      CREATE TABLE dead_letter_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT,
        operation_type TEXT NOT NULL,
        collection_name TEXT NOT NULL,
        document_id TEXT,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        error TEXT NOT NULL
      )
      ''');
    await _createSalesTables(db);
    await _createLossesTable(db);
  }

  Future<void> _createSalesTables(Database db) async {
    await db.execute('''
    CREATE TABLE sales (
      id TEXT PRIMARY KEY,
      customer_id TEXT,
      total_amount REAL NOT NULL,
      payment_method TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      is_synced INTEGER DEFAULT 0
    )
    ''');

    await db.execute('''
    CREATE TABLE sale_items (
      id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      total_price REAL NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
    )
    ''');
  }

  Future<void> _createLossesTable(Database db) async {
    await db.execute('''
    CREATE TABLE losses (
      id TEXT PRIMARY KEY,
      productId TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      totalCost REAL NOT NULL,
      reason TEXT NOT NULL,
      timestamp TEXT NOT NULL
    )
    ''');
  }

  Future<void> insertLoss(Map<String, dynamic> lossData) async {
    final db = await instance.database;
    await db.insert('losses', lossData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLosses() async {
    final db = await instance.database;
    return await db.query('losses', orderBy: 'timestamp DESC');
  }

  Future<void> insertSale(Map<String, dynamic> saleData) async {
    final db = await instance.database;
    await db.insert('sales', saleData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSaleItem(Map<String, dynamic> saleItemData) async {
    final db = await instance.database;
    await db.insert('sale_items', saleItemData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await instance.database;
    return await db.query('sales', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final db = await instance.database;
    return await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }
}