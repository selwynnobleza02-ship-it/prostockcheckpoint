import 'package:flutter/material.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/models/receipt.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/unified_operation_manager.dart';
import 'package:prostock/services/operation_manager_factory.dart';
import 'package:prostock/services/operations/sale_operations.dart';
import 'package:prostock/services/operations/credit_operations.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:uuid/uuid.dart';
import '../services/tax_service.dart';

/// Refactored Sales Provider that uses the unified operation manager
/// Eliminates duplication issues and ensures data consistency
class RefactoredSalesProvider with ChangeNotifier {
  UnifiedOperationManager? _operationManager;
  final AuthProvider _authProvider;
  final InventoryProvider _inventoryProvider;

  final List<Sale> _sales = [];
  final List<SaleItem> _saleItems = [];
  final List<SaleItem> _currentSaleItems = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  RefactoredSalesProvider({
    UnifiedOperationManager? operationManager,
    required AuthProvider authProvider,
    required InventoryProvider inventoryProvider,
  }) : _operationManager = operationManager,
       _authProvider = authProvider,
       _inventoryProvider = inventoryProvider;

  /// Initialize the provider with operation manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    _operationManager ??= await OperationManagerFactory.getInstance();

    _isInitialized = true;
  }

  // Getters
  List<Sale> get sales => _sales;
  List<SaleItem> get saleItems => _saleItems;
  List<SaleItem> get currentSaleItems => _currentSaleItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get currentSaleTotal =>
      _currentSaleItems.fold(0.0, (total, item) => total + item.totalPrice);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Complete a sale using the unified operation manager
  Future<Receipt?> completeSale({
    String? customerId,
    required String paymentMethod,
    DateTime? dueDate,
  }) async {
    // Ensure initialization
    if (!_isInitialized) {
      await initialize();
    }

    if (_operationManager == null) {
      _error = 'Operation manager not available';
      notifyListeners();
      return null;
    }

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
      final currentUser = _authProvider.currentUser;
      if (currentUser == null || currentUser.id == null) {
        throw Exception('User not authenticated or user ID is null');
      }

      final saleId = const Uuid().v4();

      if (paymentMethod == 'credit') {
        // Use unified credit sale operation
        return await _completeCreditSale(
          saleId: saleId,
          customerId: customerId!,
          items: _currentSaleItems,
          total: currentSaleTotal,
        );
      } else {
        // Use unified regular sale operation
        return await _completeRegularSale(
          saleId: saleId,
          customerId: customerId,
          paymentMethod: paymentMethod,
          dueDate: dueDate,
          userId: currentUser.id!,
        );
      }
    } catch (e) {
      _error = 'Error completing sale: ${e.toString()}';
      ErrorLogger.logError(
        'Error completing sale',
        error: e,
        context: 'RefactoredSalesProvider.completeSale',
      );
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Complete a credit sale using unified operation
  Future<Receipt?> _completeCreditSale({
    required String saleId,
    required String customerId,
    required List<SaleItem> items,
    required double total,
  }) async {
    try {
      // Create unified credit sale operation
      final operation = CreateCreditSaleOperation(
        operationId: saleId,
        customerId: customerId,
        items: items
            .map(
              (item) => {
                'productId': item.productId,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'totalPrice': item.totalPrice,
              },
            )
            .toList(),
        total: total,
        isOnline: _operationManager?.isOnline ?? false,
      );

      // Execute operation
      final result = await _operationManager!.executeOperation(operation);

      if (!result.isSuccess) {
        _error = result.error ?? 'Failed to complete credit sale';
        return null;
      }

      // Create receipt
      final receipt = _createReceipt(saleId, customerId, 'credit');

      // Clear current sale items
      _currentSaleItems.clear();

      // Refresh sales list
      await loadSales();

      return receipt;
    } catch (e) {
      ErrorLogger.logError(
        'Error completing credit sale',
        error: e,
        context: 'RefactoredSalesProvider._completeCreditSale',
      );
      return null;
    }
  }

  /// Complete a regular sale using unified operation
  Future<Receipt?> _completeRegularSale({
    required String saleId,
    String? customerId,
    required String paymentMethod,
    DateTime? dueDate,
    required String userId,
  }) async {
    try {
      // Create sale
      final sale = Sale(
        id: saleId,
        customerId: customerId,
        totalAmount: currentSaleTotal,
        paymentMethod: paymentMethod,
        status: 'completed',
        createdAt: DateTime.now(),
        dueDate: dueDate,
        userId: userId,
      );

      // Create unified sale operation
      final operation = CreateSaleOperation(
        operationId: saleId,
        sale: sale,
        saleItems: _currentSaleItems,
        isOnline: _operationManager?.isOnline ?? false,
      );

      // Execute operation; if manager not ready, fall back to local insert
      try {
        await _operationManager!.initialize();
        final result = await _operationManager!.executeOperation(operation);
        if (!result.isSuccess) {
          _error = result.error ?? 'Failed to complete sale';
          return null;
        }
      } on StateError catch (e) {
        // Manager not initialized - store sale locally and continue
        ErrorLogger.logError(
          'UnifiedOperationManager not initialized during sale execute',
          error: e,
          context: 'RefactoredSalesProvider._completeRegularSale',
        );
        try {
          await LocalDatabaseService.instance.insertSale(sale);
          for (final item in _currentSaleItems) {
            await LocalDatabaseService.instance.insertSaleItem(
              item.copyWith(saleId: saleId),
            );
          }
        } catch (dbErr) {
          _error = 'Failed to store sale locally: ${dbErr.toString()}';
          return null;
        }
      }

      // Create stock update operations for each item
      final stockOperations = _currentSaleItems
          .map(
            (item) => UpdateStockForSaleOperation(
              operationId: '${saleId}_stock_${item.productId}',
              productId: item.productId,
              quantity: item.quantity,
              reason: 'Sale',
              isOnline: _operationManager?.isOnline ?? false,
            ),
          )
          .toList();

      // Try to execute stock updates as a transaction; fall back to offline path
      try {
        final stockResult = await _operationManager!.executeTransaction(
          stockOperations,
        );
        if (!stockResult.isSuccess) {
          ErrorLogger.logError(
            'Stock update failed for sale $saleId',
            context: 'RefactoredSalesProvider._completeRegularSale',
          );
          // Don't fail the sale, just log the error
        }
      } on StateError catch (e) {
        // UnifiedOperationManager not initialized; rely on offline stock updates already queued elsewhere
        ErrorLogger.logError(
          'UnifiedOperationManager not initialized during stock update',
          error: e,
          context: 'RefactoredSalesProvider._completeRegularSale',
        );
      } catch (e) {
        ErrorLogger.logError(
          'Unexpected error during stock update transaction',
          error: e,
          context: 'RefactoredSalesProvider._completeRegularSale',
        );
      }

      // Create receipt
      final receipt = _createReceipt(saleId, customerId, paymentMethod);

      // Clear current sale items
      _currentSaleItems.clear();

      // Refresh sales list
      await loadSales();

      return receipt;
    } catch (e) {
      ErrorLogger.logError(
        'Error completing regular sale',
        error: e,
        context: 'RefactoredSalesProvider._completeRegularSale',
      );
      return null;
    }
  }

  /// Create a sale from payment (for credit payments)
  Future<void> createSaleFromPayment(String customerId, double amount) async {
    try {
      final currentUser = _authProvider.currentUser;
      if (currentUser == null || currentUser.id == null) {
        throw Exception('User not authenticated or user ID is null');
      }

      // Create unified credit payment operation
      final operation = CreateCreditPaymentOperation(
        customerId: customerId,
        amount: amount,
        notes: 'Credit payment',
        isOnline: _operationManager?.isOnline ?? false,
      );

      // Execute operation
      final result = await _operationManager!.executeOperation(operation);

      if (!result.isSuccess) {
        _error = result.error ?? 'Failed to create sale from payment';
        notifyListeners();
        return;
      }

      // Refresh sales list
      await loadSales();
    } catch (e) {
      _error = 'Error creating sale from payment: ${e.toString()}';
      ErrorLogger.logError(
        'Error creating sale from payment',
        error: e,
        context: 'RefactoredSalesProvider.createSaleFromPayment',
      );
      notifyListeners();
    }
  }

  /// Load sales from local database
  Future<void> loadSales() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure initialization
      if (!_isInitialized) {
        await initialize();
      }

      // If operation manager is still null, just return without error
      if (_operationManager == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // This would load from local database
      // For now, just clear the error
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load sales: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add item to current sale
  Future<void> addItemToCurrentSale(Product product, int quantity) async {
    if (quantity <= 0) {
      _error = 'Invalid quantity';
      notifyListeners();
      return;
    }

    if (product.id == null) {
      _error = 'Product ID cannot be null when adding to sale';
      notifyListeners();
      return;
    }

    final existingIndex = _currentSaleItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      final existingItem = _currentSaleItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      _currentSaleItems[existingIndex] = SaleItem(
        id: existingItem.id,
        saleId: existingItem.saleId,
        productId: product.id!,
        quantity: newQuantity,
        unitPrice: existingItem.unitPrice,
        totalPrice: existingItem.unitPrice * newQuantity,
      );
    } else {
      final sellingPrice = await TaxService.calculateSellingPriceWithRule(
        product.cost,
        productId: product.id,
        categoryName: product.category,
      );
      _currentSaleItems.add(
        SaleItem(
          saleId: '',
          productId: product.id!,
          quantity: quantity,
          unitPrice: sellingPrice,
          totalPrice: sellingPrice * quantity,
        ),
      );
    }

    _error = null;
    notifyListeners();
  }

  /// Remove item from current sale
  void removeItemFromCurrentSale(int index) {
    if (index >= 0 && index < _currentSaleItems.length) {
      _currentSaleItems.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear current sale
  void clearCurrentSale() {
    _currentSaleItems.clear();
    _error = null;
    notifyListeners();
  }

  /// Create receipt
  Receipt _createReceipt(
    String saleId,
    String? customerId,
    String paymentMethod,
  ) {
    // Group items by product to avoid duplicates
    final groupedItems = _groupItemsByProduct(_currentSaleItems);

    final List<ReceiptItem> receiptItems = [];
    for (final groupedItem in groupedItems) {
      final productId = groupedItem['productId'] as String;
      final product = _inventoryProvider.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(
          id: productId,
          name: 'Unknown Product',
          cost: 0,
          stock: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      receiptItems.add(
        ReceiptItem(
          productName: product.name,
          quantity: groupedItem['totalQuantity'] as int,
          unitPrice: groupedItem['unitPrice'] as double,
          totalPrice: groupedItem['totalPrice'] as double,
        ),
      );
    }

    return Receipt(
      saleId: saleId,
      receiptNumber: saleId,
      timestamp: DateTime.now(),
      customerName: customerId != null ? 'Customer #$customerId' : null,
      paymentMethod: paymentMethod,
      items: receiptItems,
      subtotal: currentSaleTotal,
      tax: 0.0,
      total: currentSaleTotal,
    );
  }

  /// Group items by product to avoid duplicates
  List<Map<String, dynamic>> _groupItemsByProduct(List<SaleItem> items) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in items) {
      if (grouped.containsKey(item.productId)) {
        final existing = grouped[item.productId]!;
        existing['totalQuantity'] =
            (existing['totalQuantity'] as int) + item.quantity;
        existing['totalPrice'] =
            (existing['totalPrice'] as double) + item.totalPrice;
      } else {
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
}
