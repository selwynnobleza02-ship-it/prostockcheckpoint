import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/models/batch_allocation.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/batch_service.dart';
import 'package:prostock/services/firestore/sale_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/offline_manager.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/utils/constants.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../utils/currency_utils.dart';
import '../utils/error_logger.dart';
import 'inventory_provider.dart';

import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/services/demand_analysis_service.dart';
import 'package:prostock/services/notification_service.dart';

class SalesProvider with ChangeNotifier {
  List<Sale> _sales = [];
  List<SaleItem> _saleItems = [];
  final List<SaleItem> _currentSaleItems = [];
  bool _isLoading = false;
  String? _error;
  DocumentSnapshot? _lastDocument;

  final InventoryProvider _inventoryProvider;
  final OfflineManager _offlineManager;
  final AuthProvider _authProvider;
  final CreditProvider _creditProvider;
  final BatchService _batchService = BatchService();
  late final DemandAnalysisService _demandAnalysisService;

  final Map<String, List<Sale>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 3);
  static const int _pageSize = 30;
  bool _hasMoreData = true;

  SalesProvider({
    required InventoryProvider inventoryProvider,
    required OfflineManager offlineManager,
    required AuthProvider authProvider,
    required CreditProvider creditProvider,
  }) : _inventoryProvider = inventoryProvider,
       _offlineManager = offlineManager,
       _authProvider = authProvider,
       _creditProvider = creditProvider {
    _demandAnalysisService = DemandAnalysisService(
      LocalDatabaseService.instance,
      NotificationService(),
    );
  }

  List<Sale> get sales => _sales
      .where((s) => !_isPaymentSale(s.paymentMethod))
      .toList(growable: false);
  List<SaleItem> get saleItems => _saleItems;
  List<SaleItem> get currentSaleItems => _currentSaleItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  double get currentSaleTotal =>
      _currentSaleItems.fold(0.0, (total, item) => total + item.totalPrice);

  String get formattedCurrentSaleTotal =>
      CurrencyUtils.formatCurrency(currentSaleTotal);

  Future<void> loadSales({
    bool refresh = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final cacheKey =
        'sales_${startDate?.millisecondsSinceEpoch ?? 'all'}_${endDate?.millisecondsSinceEpoch ?? 'all'}';

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
      List<Sale> onlineSales = [];
      if (_offlineManager.isOnline) {
        final saleService = SaleService(FirebaseFirestore.instance);
        final result = await saleService.getSalesPaginated(
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

      final localSalesData = await LocalDatabaseService.instance.getSales();
      final localSales = localSalesData.map((e) => Sale.fromMap(e)).toList();
      final pendingSales = await _offlineManager.getPendingSales();
      log('SalesProvider: Fetched ${localSales.length} local sales.');
      log('SalesProvider: Fetched ${pendingSales.length} pending sales.');

      final Map<String, Sale> mergedSalesMap = {
        for (var s in onlineSales) s.id!: s,
        for (var s in localSales) s.id!: s,
        for (var s in pendingSales) s.id!: s,
      };

      _sales = mergedSalesMap.values
          .where((s) => !_isPaymentSale(s.paymentMethod))
          .toList();
      _sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      log('SalesProvider: Merged ${_sales.length} total sales.');

      if (_sales.isNotEmpty) {
        final saleIds = _sales.map((s) => s.id!).toList();
        if (_offlineManager.isOnline) {
          final saleService = SaleService(FirebaseFirestore.instance);
          _saleItems = await saleService.getSaleItemsBySaleIds(saleIds);
        } else {
          final localSaleItems = await LocalDatabaseService.instance
              .getSaleItemsBySaleIds(saleIds);
          _saleItems = localSaleItems
              .map((item) => SaleItem.fromMap(item))
              .toList();
        }
      }

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

  Future<void> loadMoreSales({DateTime? startDate, DateTime? endDate}) async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final saleService = SaleService(FirebaseFirestore.instance);
      final result = await saleService.getSalesPaginated(
        limit: _pageSize,
        lastDocument: _lastDocument,
        startDate: startDate,
        endDate: endDate,
      );

      _sales.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMoreData = result.items.length == _pageSize;

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

  bool _shouldRefreshCache(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _cacheExpiry;
  }

  List<Sale>? _getCachedData(String key) {
    return _cache[key];
  }

  void _setCachedData(String key, List<Sale> data) {
    _cache[key] = List.from(
      data.where((s) => !_isPaymentSale(s.paymentMethod)),
    );
    _cacheTimestamps[key] = DateTime.now();
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  Future<void> addItemToCurrentSale(Product product, int quantity) async {
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

    try {
      // Check if this product already exists in cart
      final existingItems = _currentSaleItems
          .where((item) => item.productId == product.id)
          .toList();

      int totalQuantityInCart = existingItems.fold(
        0,
        (total, item) => total + item.quantity,
      );
      int totalQuantityNeeded = totalQuantityInCart + quantity;

      // Allocate stock using FIFO
      final allocations = await _batchService.allocateStockFIFO(
        product.id!,
        totalQuantityNeeded,
      );

      // Remove existing items for this product
      _currentSaleItems.removeWhere((item) => item.productId == product.id);

      // Add new items based on FIFO allocations with batch-specific pricing
      for (final allocation in allocations) {
        // Calculate selling price based on THIS batch's unit cost
        final calculatedPrice = await TaxService.calculateSellingPriceWithRule(
          allocation.unitCost, // Use batch-specific cost, not average
          productId: product.id,
          categoryName: product.category,
        );
        // Check for manual price override
        final batchPrice = product.getPriceForSale(calculatedPrice);

        _currentSaleItems.add(
          SaleItem(
            saleId: '',
            productId: product.id!,
            batchId: allocation.batchId,
            quantity: allocation.quantity,
            unitPrice: batchPrice, // Batch-specific price
            unitCost: allocation.unitCost,
            batchCost: allocation.unitCost,
            totalPrice: batchPrice * allocation.quantity,
          ),
        );
      }

      // Update visual stock
      _inventoryProvider.decreaseVisualStock(product.id!, quantity);
      _error = null;
      notifyListeners();
    } catch (e) {
      if (e is InsufficientStockException) {
        _error =
            'Insufficient stock. Available: ${e.available}, Requested: ${e.requested}';
      } else {
        _error = 'Error adding item to sale: ${e.toString()}';
      }
      notifyListeners();
      ErrorLogger.logError(
        'Error adding item to current sale',
        error: e,
        context: 'SalesProvider.addItemToCurrentSale',
      );
    }
  }

  void removeItemFromCurrentSale(int index) {
    if (index >= 0 && index < _currentSaleItems.length) {
      final item = _currentSaleItems[index];
      _inventoryProvider.increaseVisualStock(item.productId, item.quantity);
      _currentSaleItems.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> updateItemQuantity(int index, int newQuantity) async {
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

    // Get all items for this product in cart
    final productItems = _currentSaleItems
        .where((item) => item.productId == product.id)
        .toList();
    final currentTotalQty = productItems.fold(
      0,
      (total, item) => total + item.quantity,
    );

    if (newQuantity == 0) {
      // Remove this specific item
      _inventoryProvider.increaseVisualStock(product.id!, currentItem.quantity);
      _currentSaleItems.removeAt(index);
    } else {
      // Calculate the difference
      final quantityDifference = newQuantity - currentItem.quantity;

      if (quantityDifference > 0) {
        // Increasing quantity - need more stock
        final availableStock = await _inventoryProvider.getVisualStock(
          product.id!,
        );
        if (quantityDifference > availableStock) {
          _error =
              'Insufficient stock for ${product.name}. Available: $availableStock';
          notifyListeners();
          return;
        }
        _inventoryProvider.decreaseVisualStock(product.id!, quantityDifference);
      } else if (quantityDifference < 0) {
        // Decreasing quantity - free up stock
        _inventoryProvider.increaseVisualStock(
          product.id!,
          -quantityDifference,
        );
      }

      // Recalculate total needed quantity
      final newTotalQty = currentTotalQty + quantityDifference;

      try {
        // Re-allocate using FIFO
        final allocations = await _batchService.allocateStockFIFO(
          product.id!,
          newTotalQty,
        );

        // Remove all items for this product
        _currentSaleItems.removeWhere((item) => item.productId == product.id);

        // Add re-allocated items with batch-specific pricing
        for (final allocation in allocations) {
          // Calculate selling price based on THIS batch's unit cost
          final calculatedPrice =
              await TaxService.calculateSellingPriceWithRule(
                allocation.unitCost, // Use batch-specific cost, not average
                productId: product.id,
                categoryName: product.category,
              );
          // Check for manual price override
          final batchPrice = product.getPriceForSale(calculatedPrice);

          _currentSaleItems.add(
            SaleItem(
              saleId: '',
              productId: product.id!,
              batchId: allocation.batchId,
              quantity: allocation.quantity,
              unitPrice: batchPrice, // Batch-specific price
              unitCost: allocation.unitCost,
              batchCost: allocation.unitCost,
              totalPrice: batchPrice * allocation.quantity,
            ),
          );
        }
      } catch (e) {
        _error = 'Error updating quantity: ${e.toString()}';
        notifyListeners();
        return;
      }
    }

    _error = null;
    notifyListeners();
  }

  Future<Receipt?> completeSale({
    String? customerId,
    required String paymentMethod,
    DateTime? dueDate,
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

    Receipt? receipt;

    try {
      log('Completing sale...');
      // Stock validation removed - already handled by FIFO allocation in addItemToCurrentSale()
      // allocateStockFIFO() validates availability and throws InsufficientStockException if needed

      final currentUser = _authProvider.currentUser;
      if (currentUser == null || currentUser.id == null) {
        throw Exception('User not authenticated or user ID is null');
      }
      if (paymentMethod == 'credit') {
        // Delegate to CreditProvider for credit sales (no Sale record creation)
        receipt = await _creditProvider.recordCreditSale(
          customerId: customerId!,
          items: _currentSaleItems,
          total: currentSaleTotal,
          dueDate: dueDate,
          userId: currentUser.id!,
        );
        if (receipt == null) {
          _error = _creditProvider.error;
          return null;
        }
      } else {
        final sale = Sale(
          customerId: customerId,
          totalAmount: currentSaleTotal,
          paymentMethod: paymentMethod,
          status: 'completed',
          createdAt: DateTime.now(),
          dueDate: dueDate,
          userId: currentUser.id!,
        );

        // Local-first for all connectivity states
        final saleId = const Uuid().v4();
        final offlineSale = sale.copyWith(id: saleId);

        final List<Map<String, dynamic>> saleItems = [];
        for (final item in _currentSaleItems) {
          saleItems.add(item.copyWith(saleId: saleId).toMap());
        }

        await _offlineManager.queueOperation(
          OfflineOperation(
            id: offlineSale.id!,
            type: OperationType.createSaleTransaction,
            collectionName: 'sales',
            documentId: offlineSale.id,
            data: {'sale': offlineSale.toMap(), 'saleItems': saleItems},
            timestamp: DateTime.now(),
          ),
        );

        // Reduce batch quantities for each sale item
        for (final item in _currentSaleItems) {
          if (item.batchId != null) {
            ErrorLogger.logInfo(
              'Processing sale item: ${item.productId}, batch: ${item.batchId}, quantity: ${item.quantity}',
              context: 'SalesProvider.completeSale',
            );

            // Reduce from specific batch and check if it was depleted
            final wasDepleted = await _batchService.reduceBatchQuantity(
              item.batchId!,
              item.quantity,
            );

            ErrorLogger.logInfo(
              'Batch ${item.batchId} depleted: $wasDepleted',
              context: 'SalesProvider.completeSale',
            );

            // If batch was depleted, check if we need to record price history for next batch
            if (wasDepleted) {
              ErrorLogger.logInfo(
                'Batch depleted! Checking for price history update...',
                context: 'SalesProvider.completeSale',
              );
              await _recordPriceHistoryForNextBatch(item.productId);
            }
          }
          // Also reduce product stock total
          await _inventoryProvider.reduceStock(
            item.productId,
            item.quantity,
            offline: !_inventoryProvider.isOnline,
          );
        }

        receipt = _createReceipt(saleId, customerId, paymentMethod);
      }

      // Don't await these, let them run in the background
      _authProvider.logActivity(
        'COMPLETE_SALE',
        details: 'Sale completed with total: ${receipt.total}',
        amount: receipt.total,
      );
      loadSales(); // No await

      // Trigger immediate demand analysis after sale
      _triggerDemandAnalysis();

      _currentSaleItems.clear();
      return receipt;
    } catch (e) {
      _error = 'Error completing sale: \${e.toString()}';
      ErrorLogger.logError(
        'Error completing sale',
        error: e,
        context: 'SalesProvider.completeSale',
      );
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSaleFromPayment(String customerId, double amount) async {
    final currentUser = _authProvider.currentUser;
    if (currentUser == null || currentUser.id == null) {
      throw Exception('User not authenticated or user ID is null');
    }

    final sale = Sale(
      customerId: customerId,
      totalAmount: amount,
      paymentMethod: 'credit_payment',
      status: 'completed',
      createdAt: DateTime.now(),
      userId: currentUser.id!,
    );

    // Local-first for payment-created sales as well
    final saleId = const Uuid().v4();
    final offlineSale = sale.copyWith(id: saleId);
    await _offlineManager.queueOperation(
      OfflineOperation(
        id: offlineSale.id!,
        type: OperationType.createSaleTransaction,
        collectionName: 'sales',
        documentId: offlineSale.id,
        data: {'sale': offlineSale.toMap(), 'saleItems': []},
        timestamp: DateTime.now(),
      ),
    );
    loadSales();
  }

  Receipt _createReceipt(
    String saleId,
    String? customerId,
    String paymentMethod,
  ) {
    // Group items by product to avoid duplicates
    final groupedItems = _groupItemsByProduct(_currentSaleItems);

    final List<ReceiptItem> receiptItems = [];
    for (final groupedItem in groupedItems) {
      final product = _inventoryProvider.getProductById(
        groupedItem['productId'] as String,
      );
      receiptItems.add(
        ReceiptItem(
          productName: product?.name ?? 'Unknown Product',
          quantity: groupedItem['totalQuantity'] as int,
          unitPrice: groupedItem['unitPrice'] as double,
          totalPrice: groupedItem['totalPrice'] as double,
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
    for (var item in _currentSaleItems) {
      _inventoryProvider.increaseVisualStock(item.productId, item.quantity);
    }
    _currentSaleItems.clear();
    _error = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> _groupItemsByProduct(List<SaleItem> items) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in items) {
      if (grouped.containsKey(item.productId)) {
        // Add to existing group
        final existing = grouped[item.productId]!;
        existing['totalQuantity'] =
            (existing['totalQuantity'] as int) + item.quantity;
        existing['totalPrice'] =
            (existing['totalPrice'] as double) + item.totalPrice;
      } else {
        // Create new group
        grouped[item.productId] = {
          'productId': item.productId,
          'unitPrice': item.unitPrice,
          'totalQuantity': item.quantity,
          'totalPrice': item.totalPrice,
        };
      }
    }

    return grouped.values.toList();
  }

  bool _isPaymentSale(String method) {
    final m = method.toLowerCase();
    return m == 'credit_payment' ||
        m == 'debt_payment' ||
        m == 'credit payment' ||
        m == 'debt payment';
  }

  Future<Map<String, dynamic>?> getSalesAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final saleService = SaleService(FirebaseFirestore.instance);
      return await saleService.getSalesAnalytics(
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

  /// Record price history when a batch is depleted and the next batch becomes active
  Future<void> _recordPriceHistoryForNextBatch(String productId) async {
    try {
      // Get the next available batch (FIFO order)
      final batches = await _batchService.getBatchesByFIFO(productId);

      if (batches.isEmpty) {
        // No more batches available - product is out of stock
        ErrorLogger.logInfo(
          'No remaining batches for product $productId - out of stock',
          context: 'SalesProvider._recordPriceHistoryForNextBatch',
        );
        return;
      }

      final nextBatch = batches.first;

      // Get last batch number for reason message
      final lastPriceQuery = await FirebaseFirestore.instance
          .collection(AppConstants.priceHistoryCollection)
          .where('productId', isEqualTo: productId)
          .get();

      String? lastBatchNumber;
      if (lastPriceQuery.docs.isNotEmpty) {
        final sortedDocs = lastPriceQuery.docs.toList()
          ..sort((a, b) {
            final aTimestamp = (a.data()['timestamp'] as Timestamp).toDate();
            final bTimestamp = (b.data()['timestamp'] as Timestamp).toDate();
            return bTimestamp.compareTo(aTimestamp);
          });
        final lastPrice = PriceHistory.fromFirestore(sortedDocs.first);
        lastBatchNumber = lastPrice.batchNumber;
      }

      final reason = lastBatchNumber != null
          ? 'Batch $lastBatchNumber depleted, now using batch ${nextBatch.batchNumber}'
          : 'Now using batch ${nextBatch.batchNumber}';

      // Use inventory provider's helper to record price history with displayed price
      await _inventoryProvider.recordPriceHistoryIfChanged(
        productId,
        reason,
        batchId: nextBatch.id,
        batchNumber: nextBatch.batchNumber,
        cost: nextBatch.unitCost,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error recording price history for next batch',
        error: e,
        context: 'SalesProvider._recordPriceHistoryForNextBatch',
      );
      // Don't rethrow - this is not critical for sale completion
    }
  }

  /// Triggers immediate demand analysis after a sale to check for threshold suggestions
  void _triggerDemandAnalysis() {
    // Run in background without blocking the UI
    Future.microtask(() async {
      try {
        final suggestions = await _demandAnalysisService.computeSuggestions(
          highDemandThresholdPerDay: 20.0,
          minDeltaUnits: 5,
          minDeltaPercent: 0.2,
        );
        if (suggestions.isNotEmpty) {
          await _demandAnalysisService.markSuggestedNow(
            suggestions.map((s) => s.product.id!).toList(),
          );
          await _demandAnalysisService.runDailyAndNotify();
        }
      } catch (e) {
        ErrorLogger.logError(
          'Error in immediate demand analysis',
          error: e,
          context: 'SalesProvider._triggerDemandAnalysis',
        );
      }
    });
  }
}
