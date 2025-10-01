import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/services/firestore/sale_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

/// Operation to create a sale transaction
class CreateSaleOperation extends BaseOperation {
  final Sale sale;
  final List<SaleItem> saleItems;
  final bool isOnline;

  CreateSaleOperation({
    required this.sale,
    required this.saleItems,
    this.isOnline = false,
    super.operationId,
    super.timestamp,
  }) : super(
         operationType: 'create_sale',
         priority: 5, // High priority for sales
       );

  @override
  Future<OperationResult> execute() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Validate sale data
      if (sale.id == null || sale.id!.isEmpty) {
        return OperationResult.failure(
          'Sale ID is required',
          errorCode: 'INVALID_SALE_ID',
        );
      }

      if (saleItems.isEmpty) {
        return OperationResult.failure(
          'Sale must have at least one item',
          errorCode: 'EMPTY_SALE_ITEMS',
        );
      }

      // Always save to local database first
      await _saveToLocalDatabase();

      // If online, also save to Firestore
      if (isOnline) {
        await _saveToFirestore();
      }

      stopwatch.stop();

      ErrorLogger.logInfo(
        'Sale ${sale.id} created successfully in ${stopwatch.elapsedMilliseconds}ms',
        context: 'CreateSaleOperation.execute',
      );

      return OperationResult.success({
        'sale': sale.toMap(),
        'saleItems': saleItems.map((item) => item.toMap()).toList(),
      }, executionTime: stopwatch.elapsed);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to create sale ${sale.id}',
        error: e,
        context: 'CreateSaleOperation.execute',
      );

      return OperationResult.failure(
        'Failed to create sale: ${e.toString()}',
        errorCode: 'SALE_CREATION_ERROR',
      );
    }
  }

  @override
  bool validate() {
    return super.validate() &&
        sale.id != null &&
        sale.id!.isNotEmpty &&
        saleItems.isNotEmpty &&
        sale.totalAmount > 0;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'sale': sale.toMap(),
      'saleItems': saleItems.map((item) => item.toMap()).toList(),
      'isOnline': isOnline,
    };
  }

  /// Create operation from map
  static CreateSaleOperation? fromMap(Map<String, dynamic> map) {
    try {
      final saleMap = map['sale'] as Map<String, dynamic>;
      final sale = Sale.fromMap(saleMap);

      final saleItemsList = map['saleItems'] as List<dynamic>;
      final saleItems = saleItemsList
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList();

      final isOnline = map['isOnline'] as bool? ?? false;

      return CreateSaleOperation(
        operationId: map['operationId'] as String?,
        sale: sale,
        saleItems: saleItems,
        isOnline: isOnline,
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'] as String)
            : null,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to deserialize CreateSaleOperation',
        error: e,
        context: 'CreateSaleOperation.fromMap',
      );
      return null;
    }
  }

  /// Save sale to local database
  Future<void> _saveToLocalDatabase() async {
    final db = await LocalDatabaseService.instance.database;

    // Save sale
    await db.insert(
      'sales',
      sale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save sale items
    for (final item in saleItems) {
      await db.insert(
        'sale_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Save sale to Firestore
  Future<void> _saveToFirestore() async {
    final saleService = SaleService(FirebaseFirestore.instance);

    // Save sale to Firestore
    await saleService.insertSale(sale, []); // Empty products list for now

    // Save sale items to Firestore
    for (final item in saleItems) {
      await saleService.insertSaleItem(item);
    }
  }
}

/// Operation to update stock for a sale
class UpdateStockForSaleOperation extends BaseOperation {
  final String productId;
  final int quantity;
  final String reason;
  final bool isOnline;

  UpdateStockForSaleOperation({
    required this.productId,
    required this.quantity,
    required this.reason,
    this.isOnline = false,
    super.operationId,
    super.timestamp,
  }) : super(
         operationType: 'update_stock_for_sale',
         priority: 4, // High priority for stock updates
       );

  @override
  Future<OperationResult> execute() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Validate input
      if (productId.isEmpty) {
        return OperationResult.failure(
          'Product ID is required',
          errorCode: 'INVALID_PRODUCT_ID',
        );
      }

      if (quantity <= 0) {
        return OperationResult.failure(
          'Quantity must be positive',
          errorCode: 'INVALID_QUANTITY',
        );
      }

      // Update local database
      await _updateLocalStock();

      // If online, also update Firestore
      if (isOnline) {
        await _updateFirestoreStock();
      }

      stopwatch.stop();

      ErrorLogger.logInfo(
        'Stock updated for product $productId: -$quantity in ${stopwatch.elapsedMilliseconds}ms',
        context: 'UpdateStockForSaleOperation.execute',
      );

      return OperationResult.success({
        'productId': productId,
        'quantity': quantity,
        'reason': reason,
      }, executionTime: stopwatch.elapsed);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to update stock for product $productId',
        error: e,
        context: 'UpdateStockForSaleOperation.execute',
      );

      return OperationResult.failure(
        'Failed to update stock: ${e.toString()}',
        errorCode: 'STOCK_UPDATE_ERROR',
      );
    }
  }

  @override
  bool validate() {
    return super.validate() &&
        productId.isNotEmpty &&
        quantity > 0 &&
        reason.isNotEmpty;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'productId': productId,
      'quantity': quantity,
      'reason': reason,
      'isOnline': isOnline,
    };
  }

  /// Create operation from map
  static UpdateStockForSaleOperation? fromMap(Map<String, dynamic> map) {
    try {
      return UpdateStockForSaleOperation(
        operationId: map['operationId'] as String?,
        productId: map['productId'] as String,
        quantity: map['quantity'] as int,
        reason: map['reason'] as String,
        isOnline: map['isOnline'] as bool? ?? false,
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'] as String)
            : null,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to deserialize UpdateStockForSaleOperation',
        error: e,
        context: 'UpdateStockForSaleOperation.fromMap',
      );
      return null;
    }
  }

  /// Update stock in local database
  Future<void> _updateLocalStock() async {
    final db = await LocalDatabaseService.instance.database;

    // Get current stock
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (result.isEmpty) {
      throw Exception('Product $productId not found');
    }

    final currentStock = result.first['stock'] as int;
    final newStock = currentStock - quantity;

    if (newStock < 0) {
      throw Exception('Insufficient stock for product $productId');
    }

    // Update stock
    await db.update(
      'products',
      {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Update stock in Firestore
  Future<void> _updateFirestoreStock() async {
    // This would be implemented with Firestore service
    // For now, just log the operation
    ErrorLogger.logInfo(
      'Stock update for product $productId would be synced to Firestore',
      context: 'UpdateStockForSaleOperation._updateFirestoreStock',
    );
  }
}
