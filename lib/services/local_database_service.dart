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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE customers (
  id $idType,
  name $textType,
  email $textType,
  phoneNumber $textType,
  address $textType,
  balance $doubleType,
  creditLimit $doubleType,
  lastActivity $textType,
  localImagePath $textType,
  imageUrl $textType,
  createdAt $textType,
  updatedAt $textType
)
''');

    await db.execute('''
CREATE TABLE sales (
  id $textType,
  customerId $textType,
  totalAmount $doubleType,
  paymentMethod $textType,
  status $textType,
  createdAt $textType,
  dueDate $textType,
  userId $textType
)
''');

    await db.execute('''
CREATE TABLE sale_items (
  id $textType,
  saleId $textType,
  productId $textType,
  quantity $integerType,
  unitPrice $doubleType,
  totalPrice $doubleType
)
''');
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
