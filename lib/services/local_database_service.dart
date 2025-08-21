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

    return await openDatabase(path, version: 6, onCreate: _createDB, onUpgrade: _onUpgrade);
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
        retry_count INTEGER DEFAULT 0
      )
      ''');
  }
}