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

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) { // Version 3 is when offline_operations was introduced
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
    }
    // Add other upgrade paths for future versions here
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
        updated_at TEXT NOT NULL
      )
      ''');
    await db.execute('''
      CREATE TABLE offline_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        collection_name TEXT NOT NULL,
        document_id TEXT,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
      ''');
  }
}