import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';
import '../services/local_database_service.dart';
import '../utils/error_logger.dart'; // Added ErrorLogger import
// Required for JSON encoding

class InventoryProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  final Map<String, int> _reservedStock = {}; // productId -> reserved quantity
  final Map<String, int> _reorderPoints = {}; // productId -> reorder point

  final LocalDatabaseService _localDatabaseService =
      LocalDatabaseService.instance;
  final OfflineManager _offlineManager;

  InventoryProvider({required OfflineManager offlineManager})
    : _offlineManager = offlineManager;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Product> get lowStockProducts =>
      _products.where((product) => product.isLowStock).toList();

  List<Product> get criticalStockProducts => _products
      .where(
        (product) =>
            product.stock <= (_reorderPoints[product.id.toString()] ?? 5),
      )
      .toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadProducts({bool refresh = false, String? searchQuery}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _localDatabaseService.database;
      final List<Product> localProducts = (await db.query(
        'products',
      )).map((json) => Product.fromMap(json)).toList();

      _products = localProducts; // Always load local products first
      notifyListeners();

      if (refresh || localProducts.isEmpty || _offlineManager.isOnline) {
        final result = await FirestoreService.instance.getProductsPaginated(
          limit: 50,
          lastDocument: null,
          searchQuery: searchQuery,
        );

        final List<Product> firestoreProducts = result.items;

        final Map<String, Product> mergedProductsMap = {
          for (var p in firestoreProducts)
            if (p.id != null) p.id!: p,
        };
        for (var p in localProducts) {
          if (p.id != null) {
            mergedProductsMap[p.id!] = p; // Local version takes precedence
          }
        }

        _products = mergedProductsMap.values.toList();
        await _saveProductsToLocalDB(_products); // Save merged list to local DB
      }
    } catch (e) {
      _error = 'Failed to load products: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading products',
        error: e,
        context: 'InventoryProvider.loadProducts',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveProductsToLocalDB(List<Product> products) async {
    final db = await _localDatabaseService.database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<Product?> addProduct(Product product) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final productId = const Uuid().v4();
      final newProduct = product.copyWith(id: productId);

      final db = await _localDatabaseService.database;
      await db.insert(
        'products',
        newProduct.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _products.add(newProduct);
      _reorderPoints[newProduct.id!] = (newProduct.stock * 0.1).ceil().clamp(
        5,
        50,
      );

      if (_offlineManager.isOnline) {
        await FirestoreService.instance.addProductWithPriceHistory(newProduct);
      } else {
        // Queue operations for later synchronization
        await _offlineManager.queueOperation(
          OfflineOperation(
            id: newProduct.id!,
            type: OperationType.insertProduct,
            collectionName: 'products',
            documentId: newProduct.id,
            data: newProduct.toMap(),
            timestamp: DateTime.now(),
          ),
        );
        // Also queue the price history
        final priceHistory = PriceHistory(
          id: const Uuid().v4(),
          productId: newProduct.id!,
          price: newProduct.price,
          timestamp: DateTime.now(),
        );
        await _offlineManager.queueOperation(
          OfflineOperation(
            id: priceHistory.id,
            type: OperationType.insertPriceHistory,
            collectionName: 'priceHistory',
            documentId: priceHistory.id,
            data: priceHistory.toMap(),
            timestamp: DateTime.now(),
          ),
        );
      }

      _isLoading = false;
      notifyListeners();
      return newProduct;
    } catch (e) {
      _error = 'Failed to add product: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error adding product',
        error: e,
        context: 'InventoryProvider.addProduct',
      );
      return null;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final db = await _localDatabaseService.database;
      final originalProductIndex = _products.indexWhere(
        (p) => p.id == product.id,
      );
      Product? originalProduct = originalProductIndex != -1
          ? _products[originalProductIndex]
          : null;

      if (_offlineManager.isOnline) {
        final existingProduct = await FirestoreService.instance.getProductById(
          product.id!,
        );

        Product productToUpdate;
        if (existingProduct != null &&
            existingProduct.version > product.version) {
          // Conflict detected
          productToUpdate = _mergeProducts(existingProduct, product);
        } else {
          productToUpdate = product.copyWith(version: product.version + 1);
        }

        // Check if the price has changed
        final bool priceChanged =
            originalProduct != null &&
            originalProduct.price != productToUpdate.price;

        await FirestoreService.instance.updateProductWithPriceHistory(
          productToUpdate,
          priceChanged,
        );

        await db.update(
          'products',
          productToUpdate.toMap(),
          where: 'id = ?',
          whereArgs: [productToUpdate.id],
        );
        final index = _products.indexWhere((p) => p.id == productToUpdate.id);
        if (index != -1) {
          _products[index] = productToUpdate;
          notifyListeners();
        }
      } else {
        final updatedProduct = product.copyWith(version: product.version + 1);
        await db.update(
          'products',
          updatedProduct.toMap(),
          where: 'id = ?',
          whereArgs: [updatedProduct.id],
        );
        await _offlineManager.queueOperation(
          OfflineOperation(
            id: updatedProduct.id!,
            type: OperationType.updateProduct,
            collectionName: 'products',
            documentId: updatedProduct.id,
            data: updatedProduct.toMap(),
            timestamp: DateTime.now(),
          ),
        );

        // Queue price history if price changed
        if (originalProduct != null &&
            originalProduct.price != updatedProduct.price) {
          final priceHistory = PriceHistory(
            id: const Uuid().v4(),
            productId: updatedProduct.id!,
            price: updatedProduct.price,
            timestamp: DateTime.now(),
          );
          await _offlineManager.queueOperation(
            OfflineOperation(
              id: priceHistory.id,
              type: OperationType.insertPriceHistory,
              collectionName: 'priceHistory',
              documentId: priceHistory.id,
              data: priceHistory.toMap(),
              timestamp: DateTime.now(),
            ),
          );
        }

        final index = _products.indexWhere((p) => p.id == updatedProduct.id);
        if (index != -1) {
          _products[index] = updatedProduct;
          notifyListeners();
        }
      }

      return true;
    } catch (e) {
      _error = 'Error updating product: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error updating product',
        error: e,
        context: 'InventoryProvider.updateProduct',
      );
      return false;
    }
  }

  Product _mergeProducts(Product remote, Product local) {
    // Simple merge strategy: last write wins for most fields
    // More sophisticated logic can be added here based on business rules
    return remote.copyWith(
      name: local.name,
      barcode: local.barcode,
      cost: local.cost,
      stock: local.stock,
      minStock: local.minStock,
      category: local.category,
      updatedAt: DateTime.now(),
      version: remote.version + 1, // Ensure the version is incremented
    );
  }

  Future<bool> updateStock(
    String productId,
    int newStock, {
    String? reason,
  }) async {
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index == -1) return false;

      final product = _products[index];
      final oldStock = product.stock;
      final stockChange = newStock - oldStock;

      final updatedProduct = product.copyWith(
        stock: newStock,
        updatedAt: DateTime.now(),
      );

      final db = await _localDatabaseService.database;
      await db.update(
        'products',
        updatedProduct.toMap(),
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (_offlineManager.isOnline) {
        await FirestoreService.instance.updateProduct(updatedProduct);

        // Record stock movement
        final movementType = stockChange > 0 ? 'stock_in' : 'stock_out';
        await FirestoreService.instance.insertStockMovement(
          productId,
          product.name,
          movementType,
          stockChange.abs(),
          reason ?? 'Manual adjustment',
        );
      } else {
        await _offlineManager.queueOperation(
          OfflineOperation(
            id: updatedProduct.id!,
            type: OperationType.updateProduct,
            collectionName: 'products',
            documentId: updatedProduct.id,
            data: updatedProduct.toMap(),
            timestamp: DateTime.now(),
          ),
        );
      }

      _products[index] = updatedProduct;

      _checkStockAlerts(updatedProduct);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error updating stock: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error updating stock',
        error: e,
        context: 'InventoryProvider.updateStock',
      );
      return false;
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final db = await _localDatabaseService.database;
      final maps = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      if (maps.isNotEmpty) {
        return Product.fromMap(maps.first);
      } else {
        if (_offlineManager.isOnline) {
          // Try to get the product from Firestore using its barcode
          final product = await FirestoreService.instance.getProductByBarcode(
            barcode,
          );
          if (product != null) {
            await _saveProductsToLocalDB([product]);
          }
          return product;
        }
      }
      return null;
    } catch (e) {
      _error = 'Error getting product by barcode: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error getting product by barcode',
        error: e,
        context: 'InventoryProvider.getProductByBarcode',
      );
      return null;
    }
  }

  bool isStockAvailable(String productId, int requestedQuantity) {
    final product = getProductById(productId);
    if (product == null) return false;

    final reservedQuantity = _reservedStock[productId] ?? 0;
    final availableStock = product.stock - reservedQuantity;

    return availableStock >= requestedQuantity;
  }

  bool reserveStock(String productId, int quantity) {
    if (!isStockAvailable(productId, quantity)) {
      _error = 'Insufficient stock available for reservation';
      notifyListeners();
      return false;
    }

    _reservedStock[productId] = (_reservedStock[productId] ?? 0) + quantity;
    notifyListeners();
    return true;
  }

  void releaseReservedStock(String productId, int quantity) {
    final currentReserved = _reservedStock[productId] ?? 0;
    final newReserved = (currentReserved - quantity).clamp(0, currentReserved);

    if (newReserved == 0) {
      _reservedStock.remove(productId);
    } else {
      _reservedStock[productId] = newReserved;
    }
    notifyListeners();
  }

  int getAvailableStock(String productId) {
    final product = getProductById(productId);
    if (product == null) return 0;

    final reservedQuantity = _reservedStock[productId] ?? 0;
    return (product.stock - reservedQuantity).clamp(0, product.stock);
  }

  Future<bool> receiveStock(String productId, int quantity) async {
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index == -1) {
        _error = 'Product not found';
        notifyListeners();
        return false;
      }

      if (quantity <= 0) {
        _error = 'Quantity must be greater than zero';
        notifyListeners();
        return false;
      }

      final product = _products[index];
      final newStock = product.stock + quantity;
      final success = await updateStock(
        productId,
        newStock,
        reason: 'Stock received via barcode scan',
      );

      if (!success) {
        _error = 'Failed to update stock';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Error receiving stock: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error receiving stock',
        error: e,
        context: 'InventoryProvider.receiveStock',
      );
      return false;
    }
  }

  Future<bool> reduceStock(
    String productId,
    int quantity, {
    String? reason,
    bool offline = false,
  }) async {
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index == -1) {
        _error = 'Product not found';
        notifyListeners();
        return false;
      }

      final product = _products[index];
      if (product.stock < quantity) {
        _error = 'Insufficient stock for ${product.name}';
        notifyListeners();
        return false;
      }

      if (reason == 'Damage') {
        final loss = Loss(
          productId: productId,
          quantity: quantity,
          totalCost: product.cost * quantity,
          reason: reason!,
          timestamp: DateTime.now(),
        );
        await addLoss(loss);
      }

      final newStock = product.stock - quantity;
      final updatedProduct = product.copyWith(
        stock: newStock,
        updatedAt: DateTime.now(),
      );

      final db = await _localDatabaseService.database;
      await db.update(
        'products',
        updatedProduct.toMap(),
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (!offline && _offlineManager.isOnline) {
        await FirestoreService.instance.updateProduct(updatedProduct);

        // Record stock movement
        final movementType = 'stock_out';
        await FirestoreService.instance.insertStockMovement(
          productId,
          product.name,
          movementType,
          quantity,
          reason ?? 'Sale',
        );
      } else if (offline) {
        await _offlineManager.queueOperation(
          OfflineOperation(
            id: updatedProduct.id!,
            type: OperationType.updateProduct,
            collectionName: 'products',
            documentId: updatedProduct.id,
            data: updatedProduct.toMap(),
            timestamp: DateTime.now(),
          ),
        );
      }

      _products[index] = updatedProduct;

      releaseReservedStock(productId, quantity);

      _checkStockAlerts(updatedProduct);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error reducing stock: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error reducing stock',
        error: e,
        context: 'InventoryProvider.reduceStock',
      );
      return false;
    }
  }

  Future<void> addLoss(Loss loss) async {
    try {
      final db = await _localDatabaseService.database;
      final lossId = const Uuid().v4();
      final newLoss = Loss(
        id: lossId,
        productId: loss.productId,
        quantity: loss.quantity,
        totalCost: loss.totalCost,
        reason: loss.reason,
        timestamp: loss.timestamp,
      );

      await db.insert(
        'losses',
        newLoss.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (_offlineManager.isOnline) {
        await FirestoreService.instance.insertLoss(newLoss);
      } else {
        await _offlineManager.queueOperation(
          OfflineOperation(
            id: newLoss.id!,
            type: OperationType.insertLoss,
            collectionName: 'losses',
            documentId: newLoss.id,
            data: newLoss.toMap(),
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error adding loss',
        error: e,
        context: 'InventoryProvider.addLoss',
      );
    }
  }

  Future<bool> batchUpdateStock(
    Map<String, int> stockUpdates, {
    String? reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      for (final entry in stockUpdates.entries) {
        final success = await updateStock(
          entry.key,
          entry.value,
          reason: reason,
        );
        if (!success) {
          _error = 'Failed to update stock for product ID: ${entry.key}';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error in batch stock update: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error in batch stock update',
        error: e,
        context: 'InventoryProvider.batchUpdateStock',
      );
      return false;
    }
  }

  Future<bool> reconcileStock(Map<String, int> physicalCounts) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final discrepancies = <String, Map<String, int>>{};

      for (final entry in physicalCounts.entries) {
        final productId = entry.key;
        final physicalCount = entry.value;
        final product = getProductById(productId);

        if (product != null && product.stock != physicalCount) {
          discrepancies[productId] = {
            'system': product.stock,
            'physical': physicalCount,
            'difference': (physicalCount - product.stock).toInt(),
          };

          // Update to physical count
          await updateStock(
            productId,
            physicalCount,
            reason: 'Stock reconciliation',
          );
        }
      }

      if (discrepancies.isNotEmpty) {
        ErrorLogger.logInfo(
          'Stock reconciliation completed with ${discrepancies.length} discrepancies',
          context: 'InventoryProvider.reconcileStock',
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error in stock reconciliation: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error in stock reconciliation',
        error: e,
        context: 'InventoryProvider.reconcileStock',
      );
      return false;
    }
  }

  void setReorderPoint(String productId, int reorderPoint) {
    _reorderPoints[productId] = reorderPoint;
    notifyListeners();
  }

  int getReorderPoint(String productId) {
    return _reorderPoints[productId] ?? 5;
  }

  List<Product> getProductsNeedingReorder() {
    return _products.where((product) {
      if (product.id == null) return false;
      final reorderPoint = _reorderPoints[product.id!] ?? 5;
      return product.stock <= reorderPoint;
    }).toList();
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshProducts() async {
    await loadProducts(refresh: true);
  }

  void _checkStockAlerts(Product product) {
    // Implementation for checking stock alerts
  }
}
