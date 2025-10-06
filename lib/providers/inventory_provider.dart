import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/models/update_result.dart';
import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/loss_reason.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/models/cost_history.dart';
import 'package:prostock/services/firestore/inventory_service.dart';
import 'package:prostock/services/firestore/product_service.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/local_database_service.dart';
import '../utils/error_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/providers/auth_provider.dart'; // New import
import 'package:prostock/services/notification_service.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/utils/constants.dart';

class InventoryProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  final Map<String, int> _reservedStock = {};
  final Map<String, int> _reorderPoints = {};
  final Map<String, int> _visualStock = {};
  final Map<String, _StockAlertState> _lastAlertStates = {};

  final LocalDatabaseService _localDatabaseService =
      LocalDatabaseService.instance;
  final OfflineManager _offlineManager;
  final AuthProvider _authProvider; // New field

  InventoryProvider({
    required OfflineManager offlineManager,
    required AuthProvider authProvider,
  }) : _offlineManager = offlineManager,
       _authProvider = authProvider; // Initialize new field

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, int> get visualStock => _visualStock;
  bool get isOnline => _offlineManager.isOnline;
  OfflineManager get offlineManager => _offlineManager;

  Future<void> queueOperation(OfflineOperation operation) async {
    await _offlineManager.queueOperation(operation);
  }

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

  void initializeVisualStock() {
    _visualStock.clear();
    for (var product in _products) {
      if (product.id != null) {
        _visualStock[product.id!] = product.stock;
      }
    }
    notifyListeners();
  }

  void decreaseVisualStock(String productId, int quantity) {
    if (_visualStock.containsKey(productId)) {
      _visualStock[productId] = (_visualStock[productId]! - quantity).clamp(
        0,
        _visualStock[productId]!,
      );
      notifyListeners();
    }
  }

  void increaseVisualStock(String productId, int quantity) {
    final product = getProductById(productId);
    if (product != null && _visualStock.containsKey(productId)) {
      _visualStock[productId] = (_visualStock[productId]! + quantity).clamp(
        0,
        product.stock,
      );
      notifyListeners();
    }
  }

  int getVisualStock(String productId) {
    return _visualStock[productId] ?? getProductById(productId)?.stock ?? 0;
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

      // Apply local search filtering if searchQuery is provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        _products = _filterProductsLocally(localProducts, searchQuery);
      } else {
        _products = localProducts;
      }

      initializeVisualStock();
      notifyListeners();

      // Only fetch from Firestore if online and no search query (or refresh requested)
      if ((refresh || localProducts.isEmpty || _offlineManager.isOnline) &&
          (searchQuery == null || searchQuery.isEmpty)) {
        final productService = ProductService(FirebaseFirestore.instance);
        final result = await productService.getProductsPaginated(
          limit: 50,
          lastDocument: null,
          searchQuery: null, // Don't search on Firestore for general loading
        );

        final List<Product> firestoreProducts = result.items;

        final Map<String, Product> mergedProductsMap = {
          for (var p in firestoreProducts)
            if (p.id != null) p.id!: p,
        };
        for (var p in localProducts) {
          if (p.id != null) {
            mergedProductsMap[p.id!] = p;
          }
        }

        _products = mergedProductsMap.values.toList();
        await _saveProductsToLocalDB(_products);
        initializeVisualStock();
      } else if (searchQuery != null &&
          searchQuery.isNotEmpty &&
          _offlineManager.isOnline) {
        // If online and searching, try Firestore search first, fallback to local
        try {
          final productService = ProductService(FirebaseFirestore.instance);
          final result = await productService.getProductsPaginated(
            limit: 50,
            lastDocument: null,
            searchQuery: searchQuery,
          );

          if (result.items.isNotEmpty) {
            _products = result.items;
            initializeVisualStock();
          }
        } catch (e) {
          // Fallback to local search if Firestore search fails
          _products = _filterProductsLocally(localProducts, searchQuery);
          initializeVisualStock();
        }
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

  List<Product> _filterProductsLocally(
    List<Product> products,
    String searchQuery,
  ) {
    final query = searchQuery.toLowerCase().trim();
    if (query.isEmpty) return products;

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
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

    // Optimistic: add locally first, rollback if both remote and queue fail
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
        try {
          final productService = ProductService(FirebaseFirestore.instance);
          final inventoryService = InventoryService(FirebaseFirestore.instance);
          await productService.addProductWithPriceHistory(newProduct);
          await inventoryService.insertStockMovement(
            newProduct.id!,
            newProduct.name,
            'stock_in',
            newProduct.stock,
            'Initial stock',
          );
        } catch (e) {
          // Fallback to offline queue if online write fails
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
          final sellingPrice = await TaxService.calculateSellingPrice(
            newProduct.cost,
          );
          final priceHistory = PriceHistory(
            id: const Uuid().v4(),
            productId: newProduct.id!,
            price: sellingPrice,
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
      } else {
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
        final sellingPrice = await TaxService.calculateSellingPrice(
          newProduct.cost,
        );
        final priceHistory = PriceHistory(
          id: const Uuid().v4(),
          productId: newProduct.id!,
          price: sellingPrice,
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
      initializeVisualStock();
      notifyListeners();
      return newProduct;
    } catch (e) {
      // Rollback: remove local product and DB row if present
      try {
        final db = await _localDatabaseService.database;
        await db.delete('products', where: 'id = ?', whereArgs: [product.id]);
      } catch (_) {}
      _products.removeWhere((p) => p.id == product.id);
      initializeVisualStock();
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

  Future<UpdateResult> updateProduct(Product product) async {
    try {
      final db = await _localDatabaseService.database;
      final originalProductIndex = _products.indexWhere(
        (p) => p.id == product.id,
      );
      Product? originalProduct = originalProductIndex != -1
          ? _products[originalProductIndex]
          : null;

      if (_offlineManager.isOnline) {
        final productService = ProductService(FirebaseFirestore.instance);
        final existingProduct = await productService.getProductById(
          product.id!,
        );

        if (existingProduct != null &&
            existingProduct.version > product.version) {
          ErrorLogger.logInfo(
            'Conflict detected for product ${product.id}',
            context: 'InventoryProvider.updateProduct',
          );
          return UpdateResult(
            success: false,
            conflict: Conflict.product(
              localProduct: product,
              remoteProduct: existingProduct,
            ),
          );
        }

        final productToUpdate = product.copyWith(version: product.version + 1);

        final bool priceChanged =
            originalProduct != null &&
            originalProduct.cost != productToUpdate.cost;

        await productService.updateProductWithPriceHistory(
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
          initializeVisualStock();
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
            version: updatedProduct.version,
          ),
        );

        if (originalProduct != null &&
            originalProduct.cost != updatedProduct.cost) {
          // Track price history
          final sellingPrice = await TaxService.calculateSellingPrice(
            updatedProduct.cost,
          );
          final priceHistory = PriceHistory(
            id: const Uuid().v4(),
            productId: updatedProduct.id!,
            price: sellingPrice,
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

          // Track cost history
          final costHistory = CostHistory(
            id: const Uuid().v4(),
            productId: updatedProduct.id!,
            cost: updatedProduct.cost,
            timestamp: DateTime.now(),
          );
          await _offlineManager.queueOperation(
            OfflineOperation(
              id: costHistory.id,
              type: OperationType.insertCostHistory,
              collectionName: 'costHistory',
              documentId: costHistory.id,
              data: costHistory.toMap(),
              timestamp: DateTime.now(),
            ),
          );
        }

        final index = _products.indexWhere((p) => p.id == updatedProduct.id);
        if (index != -1) {
          _products[index] = updatedProduct;
          initializeVisualStock();
          notifyListeners();
        }
      }

      return UpdateResult(success: true);
    } catch (e) {
      _error = 'Error updating product: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error updating product',
        error: e,
        context: 'InventoryProvider.updateProduct',
      );
      return UpdateResult(success: false);
    }
  }

  Future<UpdateResult> updateStock(
    String productId,
    int newStock, {
    String? reason,
  }) async {
    // Optimistic: update memory and DB first, rollback on failure of both remote and queue
    try {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index == -1) return UpdateResult(success: false);

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
        try {
          final productService = ProductService(FirebaseFirestore.instance);
          final inventoryService = InventoryService(FirebaseFirestore.instance);
          await productService.updateProduct(updatedProduct);

          final movementType = stockChange > 0 ? 'stock_in' : 'stock_out';
          await inventoryService.insertStockMovement(
            productId,
            product.name,
            movementType,
            stockChange.abs(),
            reason ?? 'Manual adjustment',
          );
        } catch (e) {
          // Fallback to queue on failure
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
      initializeVisualStock();

      _checkStockAlerts(updatedProduct);

      notifyListeners();
      return UpdateResult(success: true);
    } catch (e) {
      // Rollback local DB/memory to previous stock
      try {
        final db = await _localDatabaseService.database;
        final original = getProductById(productId);
        if (original != null) {
          await db.update(
            'products',
            original.copyWith(stock: original.stock).toMap(),
            where: 'id = ?',
            whereArgs: [productId],
          );
        }
      } catch (_) {}
      _error = 'Error updating stock: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error updating stock',
        error: e,
        context: 'InventoryProvider.updateStock',
      );
      return UpdateResult(success: false);
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
          final productService = ProductService(FirebaseFirestore.instance);
          final product = await productService.getProductByBarcode(barcode);
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
      final result = await updateStock(
        productId,
        newStock,
        reason: 'Stock received via barcode scan',
      );

      if (!result.success) {
        _error = 'Failed to update stock';
        notifyListeners();
      }

      return result.success;
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
    // Optimistic: update locally, rollback if queue also fails
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
        try {
          final productService = ProductService(FirebaseFirestore.instance);
          final inventoryService = InventoryService(FirebaseFirestore.instance);
          await productService.updateProduct(updatedProduct);

          final movementType = 'stock_out';
          await inventoryService.insertStockMovement(
            productId,
            product.name,
            movementType,
            quantity,
            reason ?? 'Sale',
          );
        } catch (e) {
          // Fallback to queue if online write fails
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
          // Also queue stock movement so it appears in reports after sync
          await _offlineManager.queueOperation(
            OfflineOperation(
              type: OperationType.insertStockMovement,
              collectionName: AppConstants.stockMovementsCollection,
              data: {
                'productId': productId,
                'productName': product.name,
                'movementType': 'stock_out',
                'quantity': quantity,
                'reason': reason ?? 'Sale',
                'createdAt': FieldValue.serverTimestamp(),
              },
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        // If explicitly offline mode or connectivity is offline, queue the update
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
        // Queue stock movement for offline reduce stock (e.g., sales/credit)
        await _offlineManager.queueOperation(
          OfflineOperation(
            type: OperationType.insertStockMovement,
            collectionName: AppConstants.stockMovementsCollection,
            data: {
              'productId': productId,
              'productName': product.name,
              'movementType': 'stock_out',
              'quantity': quantity,
              'reason': reason ?? 'Sale',
              'createdAt': FieldValue.serverTimestamp(),
            },
            timestamp: DateTime.now(),
          ),
        );
      }

      _products[index] = updatedProduct;
      initializeVisualStock();

      releaseReservedStock(productId, quantity);

      _checkStockAlerts(updatedProduct);

      notifyListeners();
      return true;
    } catch (e) {
      // Rollback local DB/memory to previous stock
      try {
        final db = await _localDatabaseService.database;
        final product = getProductById(productId);
        if (product != null) {
          await db.update(
            'products',
            product.copyWith(stock: product.stock + quantity).toMap(),
            where: 'id = ?',
            whereArgs: [productId],
          );
          final index = _products.indexWhere((p) => p.id == productId);
          if (index != -1) {
            _products[index] = product.copyWith(
              stock: product.stock + quantity,
            );
            initializeVisualStock();
          }
        }
      } catch (_) {}
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

  Future<bool> addLoss({
    required String productId,
    required int quantity,
    required LossReason reason,
  }) async {
    try {
      final product = getProductById(productId);
      if (product == null) {
        _error = 'Product not found';
        notifyListeners();
        return false;
      }

      if (product.stock < quantity) {
        _error = 'Insufficient stock for ${product.name}';
        notifyListeners();
        return false;
      }

      final totalCost = product.cost * quantity;
      final lossId = const Uuid().v4();
      final currentUserId = _authProvider.currentUser?.id;

      final newLoss = Loss(
        id: lossId,
        productId: productId,
        quantity: quantity,
        totalCost: totalCost,
        reason: reason,
        timestamp: DateTime.now(),
        recordedBy: currentUserId,
      );

      // Reduce stock first
      final stockReduced = await reduceStock(
        productId,
        quantity,
        reason: reason.toDisplayString(), // Pass the display string of the enum
      );

      if (!stockReduced) {
        _error = 'Failed to reduce stock for loss';
        notifyListeners();
        return false;
      }

      // Then record the loss
      final db = await _localDatabaseService.database;
      await db.insert(
        'losses',
        newLoss.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (_offlineManager.isOnline) {
        try {
          final inventoryService = InventoryService(FirebaseFirestore.instance);
          await inventoryService.insertLoss(newLoss);
        } catch (e) {
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
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error adding loss: ${e.toString()}';
      ErrorLogger.logError(
        'Error adding loss',
        error: e,
        context: 'InventoryProvider.addLoss',
      );
      notifyListeners();
      return false;
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
        final result = await updateStock(
          entry.key,
          entry.value,
          reason: reason,
        );
        if (!result.success) {
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

          final result = await updateStock(
            productId,
            physicalCount,
            reason: 'Stock reconciliation',
          );
          if (!result.success) {
            _error = 'Failed to reconcile stock for product ID: $productId';
            _isLoading = false;
            notifyListeners();
            return false;
          }
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
    if (product.id == null) return;

    final String productId = product.id!;
    final int currentStock = product.stock;
    final int lowThreshold = product.minStock;

    final _StockAlertState currentState = currentStock == 0
        ? _StockAlertState.out
        : (currentStock <= lowThreshold
              ? _StockAlertState.low
              : _StockAlertState.normal);

    final _StockAlertState? previousState = _lastAlertStates[productId];
    _lastAlertStates[productId] = currentState;

    // Only notify on state transitions to avoid spamming
    if (previousState == currentState) return;

    final notificationService = NotificationService();

    if (currentState == _StockAlertState.out) {
      notificationService.showNotification(
        productId.hashCode,
        'Out of stock',
        '${product.name} is out of stock',
        'out_of_stock:$productId',
      );
      return;
    }

    if (currentState == _StockAlertState.low) {
      notificationService.showNotification(
        productId.hashCode ^ 1,
        'Low stock',
        '${product.name} is low on stock ($currentStock left)',
        'low_stock:$productId',
      );
      return;
    }

    if (currentState == _StockAlertState.normal &&
        (previousState == _StockAlertState.low ||
            previousState == _StockAlertState.out)) {
      // Optional: notify restock
      notificationService.showNotification(
        productId.hashCode ^ 2,
        'Restocked',
        '${product.name} has been restocked',
        'restocked:$productId',
      );
    }
  }
}

enum _StockAlertState { normal, low, out }
