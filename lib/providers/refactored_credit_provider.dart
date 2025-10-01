import 'package:flutter/material.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/receipt.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/services/unified_operation_manager.dart';
import 'package:prostock/services/operation_manager_factory.dart';
import 'package:prostock/services/operations/credit_operations.dart';
import 'package:prostock/utils/error_logger.dart';

/// Refactored Credit Provider that uses the unified operation manager
/// Eliminates duplication issues in credit operations
class RefactoredCreditProvider with ChangeNotifier {
  UnifiedOperationManager? _operationManager;
  final CustomerProvider _customerProvider;

  final List<Customer> _overdueCustomers = [];
  final List<CreditTransaction> _transactions = [];

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  RefactoredCreditProvider({
    UnifiedOperationManager? operationManager,
    required CustomerProvider customerProvider,
  }) : _operationManager = operationManager,
       _customerProvider = customerProvider;

  /// Initialize the provider with operation manager
  Future<void> initialize() async {
    _operationManager ??= await OperationManagerFactory.getInstance();
  }

  // Getters
  List<Customer> get overdueCustomers => _overdueCustomers;
  List<CreditTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Record a credit sale using unified operation
  Future<Receipt?> recordCreditSale({
    required String customerId,
    required List<SaleItem> items,
    required double total,
  }) async {
    // Ensure initialization
    if (_operationManager == null) {
      await initialize();
    }

    if (_operationManager == null) {
      _error = 'Operation manager not available';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate customer
      final customer = await _customerProvider.getCustomerById(customerId);
      if (customer == null) {
        _error = 'Customer not found';
        return null;
      }

      if (customer.balance + total > customer.creditLimit) {
        _error = 'Credit limit exceeded';
        return null;
      }

      // Create unified credit sale operation
      final operation = CreateCreditSaleOperation(
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
        _error = result.error ?? 'Failed to record credit sale';
        return null;
      }

      // Create receipt
      final receipt = _createReceipt(
        operation.operationId,
        customer.name,
        items,
        total,
      );

      _isLoading = false;
      notifyListeners();

      return receipt;
    } catch (e) {
      _error = 'Failed to record credit sale: ${e.toString()}';
      ErrorLogger.logError(
        'Error recording credit sale',
        error: e,
        context: 'RefactoredCreditProvider.recordCreditSale',
      );
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Record a credit payment using unified operation
  Future<bool> recordPayment({
    required BuildContext context,
    required String customerId,
    required double amount,
    required String notes,
  }) async {
    // Ensure initialization
    if (_operationManager == null) {
      await initialize();
    }

    if (_operationManager == null) {
      _error = 'Operation manager not available';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      ErrorLogger.logInfo(
        'Starting payment recording',
        context: 'RefactoredCreditProvider.recordPayment',
        metadata: {'customerId': customerId, 'amount': amount},
      );

      // Create unified credit payment operation
      final operation = CreateCreditPaymentOperation(
        customerId: customerId,
        amount: amount,
        notes: notes,
        isOnline: _operationManager?.isOnline ?? false,
      );

      // Execute operation
      final result = await _operationManager!.executeOperation(operation);

      if (!result.isSuccess) {
        _error = result.error ?? 'Failed to record payment';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      ErrorLogger.logInfo(
        'Payment recording completed successfully',
        context: 'RefactoredCreditProvider.recordPayment',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to record payment: ${e.toString()}';
      ErrorLogger.logError(
        'Error recording payment',
        error: e,
        context: 'RefactoredCreditProvider.recordPayment',
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch overdue customers
  Future<void> fetchOverdueCustomers(BuildContext context) async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // This would fetch overdue customers from the database
      // For now, just mark as initialized
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch overdue customers: ${e.toString()}';
      ErrorLogger.logError(
        'Error fetching overdue customers',
        error: e,
        context: 'RefactoredCreditProvider.fetchOverdueCustomers',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get transactions by customer
  Future<void> getTransactionsByCustomer(String customerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      ErrorLogger.logInfo(
        'Fetching transactions for customer',
        context: 'RefactoredCreditProvider.getTransactionsByCustomer',
        metadata: {'customerId': customerId},
      );

      // This would fetch transactions from the database
      // For now, just clear the loading state
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load transactions: ${e.toString()}';
      ErrorLogger.logError(
        'Error fetching transactions',
        error: e,
        context: 'RefactoredCreditProvider.getTransactionsByCustomer',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create receipt for credit sale
  Receipt _createReceipt(
    String saleId,
    String customerName,
    List<SaleItem> items,
    double total,
  ) {
    // Group items by product to avoid duplicates
    final groupedItems = _groupItemsByProduct(items);

    final List<ReceiptItem> receiptItems = [];
    for (final groupedItem in groupedItems) {
      receiptItems.add(
        ReceiptItem(
          productName: 'Product ${groupedItem['productId']}',
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
      customerName: customerName,
      paymentMethod: 'credit',
      items: receiptItems,
      subtotal: total,
      tax: 0.0,
      total: total,
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
