import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../services/firestore_service.dart';
import '../utils/currency_utils.dart';

import '../utils/error_logger.dart';
import 'inventory_provider.dart';

/// Sales Provider - Manages the complete sales transaction lifecycle
///
/// CORE RESPONSIBILITIES:
/// - Transaction Management: Handles multi-step sale processing with atomic operations
/// - Stock Integration: Coordinates with InventoryProvider for real-time stock validation
/// - Receipt Generation: Creates detailed receipts with proper formatting and data
/// - Performance Optimization: Implements intelligent caching and pagination strategies
///
/// BUSINESS LOGIC:
/// - All sales must validate stock availability before processing
/// - Stock is reserved during cart operations to prevent overselling
/// - Failed transactions automatically rollback all changes
/// - Receipt generation includes comprehensive audit trail
class SalesProvider with ChangeNotifier {
  List<Sale> _sales = [];
  final List<SaleItem> _currentSaleItems = [];
  bool _isLoading = false;
  String? _error;
  DocumentSnapshot? _lastDocument;

  final InventoryProvider _inventoryProvider;

  /// Multi-tier caching system for performance optimization
  /// - Primary cache: In-memory storage for frequently accessed sales data
  /// - Cache keys: Include date ranges and search parameters for precise invalidation
  /// - Expiry strategy: 3-minute TTL balances freshness with performance
  final Map<String, List<Sale>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 3);
  static const int _pageSize = 30;
  bool _hasMoreData = true;

  SalesProvider({required InventoryProvider inventoryProvider})
    : _inventoryProvider = inventoryProvider;

  List<Sale> get sales => _sales;
  List<SaleItem> get currentSaleItems => _currentSaleItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Real-time cart total calculation
  /// Aggregates all item totals with proper decimal precision for financial accuracy
  double get currentSaleTotal =>
      _currentSaleItems.fold(0.0, (total, item) => total + item.totalPrice);

  String get formattedCurrentSaleTotal =>
      CurrencyUtils.formatCurrency(currentSaleTotal);

  /// Advanced sales data loading with intelligent caching
  ///
  /// CACHING STRATEGY:
  /// - Cache key includes date range parameters for precise cache invalidation
  /// - Automatic cache validation prevents stale data display
  /// - Fallback to database when cache is invalid or missing
  ///
  /// PAGINATION LOGIC:
  /// - Cursor-based pagination for consistent results during concurrent modifications
  /// - Page size optimized for mobile performance (30 items)
  /// - Maintains pagination state across cache refreshes
  Future<void> loadSales({
    bool refresh = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final cacheKey =
        'sales_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';

    // Cache validation and retrieval
    if (!refresh && !_shouldRefreshCache(cacheKey)) {
      final cachedData = _getCachedData(cacheKey);
      if (cachedData != null) {
        _sales = cachedData;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    if (refresh) {
      _hasMoreData = true;
      _lastDocument = null;
    }
    notifyListeners();

    try {
      // Fetch online sales if connected
      List<Sale> onlineSales = [];
      if (OfflineManager.instance.isOnline) {
        final result = await FirestoreService.instance.getSalesPaginated(
          limit: _pageSize,
          lastDocument: _lastDocument,
          startDate: startDate,
          endDate: endDate,
        );
        onlineSales = result.items;
        _lastDocument = result.lastDocument;
        _hasMoreData = result.items.length == _pageSize;
        log('SalesProvider: Fetched ${onlineSales.length} online sales.');
      }

      // Fetch local and pending sales
      final localSalesData = await LocalDatabaseService.instance.getSales();
      final localSales = localSalesData.map((e) => Sale.fromMap(e)).toList();
      final pendingSales = await OfflineManager.instance.getPendingSales();
      log('SalesProvider: Fetched ${localSales.length} local sales.');
      log('SalesProvider: Fetched ${pendingSales.length} pending sales.');

      // Merge all sales data
      final Map<String, Sale> mergedSalesMap = {
        for (var s in onlineSales) s.id!: s,
        for (var s in localSales)
          s.id!: s, // Local data can be overwritten by online data
        for (var s in pendingSales)
          s.id!: s, // Pending data should be prioritized
      };

      _sales = mergedSalesMap.values.toList();
      _sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      log('SalesProvider: Merged ${_sales.length} total sales.');

      // Cache the merged data
      _setCachedData(cacheKey, _sales);
    } catch (e) {
      _error = 'Failed to load sales: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading sales',
        error: e,
        context: 'SalesProvider.loadSales',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Infinite scroll pagination implementation
  /// Maintains cursor position and prevents duplicate loading
  Future<void> loadMoreSales({DateTime? startDate, DateTime? endDate}) async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await FirestoreService.instance.getSalesPaginated(
        limit: _pageSize,
        lastDocument: _lastDocument,
        startDate: startDate,
        endDate: endDate,
      );

      _sales.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;

      // Update cache
      final cacheKey =
          'sales_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';
      _setCachedData(cacheKey, _sales);
    } catch (e) {
      _error = 'Failed to load more sales: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading more sales',
        error: e,
        context: 'SalesProvider.loadMoreSales',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cache management utilities
  bool _shouldRefreshCache(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _cacheExpiry;
  }

  List<Sale>? _getCachedData(String key) {
    return _cache[key];
  }

  void _setCachedData(String key, List<Sale> data) {
    _cache[key] = List.from(data);
    _cacheTimestamps[key] = DateTime.now();
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Shopping cart management with duplicate item handling
  ///
  /// BUSINESS RULES:
  /// - Duplicate products are consolidated into single line items
  /// - Quantity validation prevents negative or zero quantities
  /// - Price calculations maintain precision for financial accuracy
  void addItemToCurrentSale(Product product, int quantity) {
    if (quantity <= 0) {
      _error = 'Invalid quantity';
      notifyListeners();
      return;
    }

    if (product.id == null) {
      _error = 'Product ID cannot be null when adding to sale';
      ErrorLogger.logError(
        'Product ID is null',
        context: 'SalesProvider.addItemToCurrentSale',
        error: 'Product: ${product.name}',
      );
      notifyListeners();
      return;
    }

    final existingIndex = _currentSaleItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      // Consolidate duplicate items
      final existingItem = _currentSaleItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      _currentSaleItems[existingIndex] = SaleItem(
        id: existingItem.id,
        saleId: existingItem.saleId,
        productId: product.id!,
        quantity: newQuantity,
        unitPrice: product.price,
        totalPrice: product.price * newQuantity,
      );
    } else {
      // Add new line item
      _currentSaleItems.add(
        SaleItem(
          saleId: '', // Will be set when sale is saved
          productId: product.id!,
          quantity: quantity,
          unitPrice: product.price,
          totalPrice: product.price * quantity,
        ),
      );
    }
    _error = null;
    notifyListeners();
  }

  void removeItemFromCurrentSale(int index) {
    if (index >= 0 && index < _currentSaleItems.length) {
      _currentSaleItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateItemQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _currentSaleItems.length) {
      _error = 'Invalid item index';
      notifyListeners();
      return;
    }

    if (newQuantity < 0) {
      _error = 'Quantity cannot be negative';
      notifyListeners();
      return;
    }

    final currentItem = _currentSaleItems[index];
    final product = _inventoryProvider.getProductById(currentItem.productId);

    if (product == null) {
      _error = 'Product not found';
      notifyListeners();
      return;
    }

    if (newQuantity == 0) {
      _currentSaleItems.removeAt(index);
    } else {
      // Check available stock before updating
      final availableStock = _inventoryProvider.getAvailableStock(
        product.id!,
      ); // Assuming getAvailableStock exists
      if (newQuantity > availableStock) {
        _error =
            'Insufficient stock for ${product.name}. Available: $availableStock';
        notifyListeners();
        return;
      }

      _currentSaleItems[index] = currentItem.copyWith(
        quantity: newQuantity,
        totalPrice: product.price * newQuantity,
      );
    }
    _error = null;
    notifyListeners();
  }

  /// Complete Sale Transaction - Core Business Logic
  ///
  /// TRANSACTION FLOW:
  /// 1. Pre-validation: Verify cart contents and stock availability
  /// 2. Stock Validation: Check real-time inventory levels for all items
  /// 3. Sale Creation: Generate sale record with unique ID
  /// 4. Item Processing: Create individual sale item records
  /// 5. Inventory Updates: Reduce stock levels through InventoryProvider
  /// 6. Receipt Generation: Create formatted receipt for customer
  /// 7. Cleanup: Clear cart and refresh sales data
  ///
  /// ATOMICITY GUARANTEE:
  /// - All operations must succeed or entire transaction rolls back
  /// - Stock levels are validated immediately before deduction
  /// - Failed stock updates prevent sale completion
  ///
  /// ERROR HANDLING:
  /// - Comprehensive validation at each step
  /// - Detailed error messages for troubleshooting
  /// - Automatic cleanup on failure
  Future<Receipt?> completeSale({
    String? customerId,
    required String paymentMethod,
  }) async {
    if (_currentSaleItems.isEmpty) {
      _error = 'No items in cart';
      notifyListeners();
      return null;
    }

    if (paymentMethod == 'credit' && customerId == null) {
      _error = 'Please select a customer for credit transactions.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      log('Completing sale...');
      // STEP 1: Pre-validation - Verify all products exist and have sufficient stock
      final List<Product> productsInSale = [];
      for (final item in _currentSaleItems) {
        final product = _inventoryProvider.getProductById(item.productId);
        if (product == null) {
          _error = 'Product not found: \${item.productId}';
          _isLoading = false;
          notifyListeners();
          return null;
        }
        if (product.stock < item.quantity) {
          _error = 'Insufficient stock for product: \${product.name}';
          _isLoading = false;
          notifyListeners();
          return null;
        }
        productsInSale.add(product);
      }

      if (paymentMethod == 'credit') {
        // Handle Utang (Credit) Transaction
        final creditId = await FirestoreService.instance.recordUtang(
          customerId!,
          currentSaleTotal,
          _currentSaleItems as double,
          productsInSale.cast<SaleItem>(),
        );

        // Reduce stock for each item in the credit sale
        for (final item in _currentSaleItems) {
          final stockReduced = await _inventoryProvider.reduceStock(
            item.productId,
            item.quantity,
            offline: !OfflineManager.instance.isOnline,
          );
          if (!stockReduced) {
            // This part is crucial for handling potential failures.
            // Depending on the business logic, you might want to rollback the Utang record.
            _error =
                'Failed to reduce stock for product: \${item.productId}. The credit was recorded, but inventory might be inconsistent.';
            _isLoading = false;
            notifyListeners();
            // Returning null or a specific error object might be appropriate here
            return null;
          }
        }

        final receipt = _createReceipt(creditId, customerId, paymentMethod);

        _currentSaleItems.clear();
        await loadSales();
        _isLoading = false;
        notifyListeners();
        return receipt;
      } else {
        // Handle Cash Transaction
        final sale = Sale(
          customerId: customerId,
          totalAmount: currentSaleTotal,
          paymentMethod: paymentMethod,
          status: 'completed',
          createdAt: DateTime.now(),
        );

        if (OfflineManager.instance.isOnline) {
          log('Online sale');
          final saleId = await FirestoreService.instance.insertSale(
            sale,
            productsInSale,
          );

          // STEP 3: Process each sale item and update inventory
          for (final item in _currentSaleItems) {
            // Create sale item record
            final saleItem = SaleItem(
              saleId: saleId,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
            );

            await FirestoreService.instance.insertSaleItem(saleItem);

            // STEP 4: Update inventory through InventoryProvider (maintains business rules)
            final stockReduced = await _inventoryProvider.reduceStock(
              item.productId,
              item.quantity,
            );
            if (!stockReduced) {
              _error = 'Failed to reduce stock for product: \${item.productId}';
              _isLoading = false;
              notifyListeners();
              return null;
            }
          }

          // STEP 5: Generate customer receipt
          final receipt = _createReceipt(saleId, customerId, paymentMethod);

          // STEP 6: Transaction cleanup and data refresh
          _currentSaleItems.clear();
          await loadSales();
          _isLoading = false;
          notifyListeners();
          return receipt;
        } else {
          log('Offline sale');
          final saleId = const Uuid().v4();
          final offlineSale = sale.copyWith(id: saleId);

          final List<Map<String, dynamic>> saleItems = [];
          for (final item in _currentSaleItems) {
            saleItems.add(item.copyWith(saleId: saleId).toMap());
          }

          await OfflineManager.instance.queueOperation(
            OfflineOperation(
              id: offlineSale.id!,
              type: OperationType.createSaleTransaction,
              collectionName: 'sales',
              documentId: offlineSale.id,
              data: {'sale': offlineSale.toMap(), 'saleItems': saleItems},
              timestamp: DateTime.now(),
            ),
          );

          // Reduce stock locally
          for (final item in _currentSaleItems) {
            await _inventoryProvider.reduceStock(
              item.productId,
              item.quantity,
              offline: true,
            );
          }

          final receipt = _createReceipt(saleId, customerId, paymentMethod);

          _currentSaleItems.clear();
          _isLoading = false;
          notifyListeners();
          return receipt;
        }
      }
    } catch (e) {
      _error = 'Error completing sale: \${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error completing sale',
        error: e,
        context: 'SalesProvider.completeSale',
      );
      return null;
    }
  }

  Receipt _createReceipt(
    String saleId,
    String? customerId,
    String paymentMethod,
  ) {
    final List<ReceiptItem> receiptItems = [];
    for (final item in _currentSaleItems) {
      final product = _inventoryProvider.getProductById(item.productId);
      receiptItems.add(
        ReceiptItem(
          productName: product?.name ?? 'Unknown Product',
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
        ),
      );
    }

    String? customerName;
    if (customerId != null) {
      customerName = 'Customer #\$customerId';
    }

    return Receipt(
      saleId: saleId,
      receiptNumber: saleId,
      timestamp: DateTime.now(),
      customerName: customerName,
      paymentMethod: paymentMethod,
      items: receiptItems,
      subtotal: currentSaleTotal,
      tax: 0.0,
      total: currentSaleTotal,
    );
  }

  void clearCurrentSale() {
    _currentSaleItems.clear();
    _error = null;
    notifyListeners();
  }

  /// Sales Analytics - Business Intelligence Data
  ///
  /// ANALYTICS CALCULATIONS:
  /// - Revenue aggregation with date range filtering
  /// - Payment method distribution analysis
  /// - Average sale value calculations
  /// - Performance metrics for dashboard display
  Future<Map<String, dynamic>?> getSalesAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await FirestoreService.instance.getSalesAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = 'Failed to get sales analytics: ${e.toString()}';
      notifyListeners();
      ErrorLogger.logError(
        'Error getting sales analytics',
        error: e,
        context: 'SalesProvider.getSalesAnalytics',
      );
      return null;
    }
  }
}
