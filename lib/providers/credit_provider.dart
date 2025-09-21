import 'package:flutter/material.dart';
import 'package:prostock/models/credit_sale_item.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/models/receipt.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/services/firestore/credit_service.dart';
import 'package:provider/provider.dart';

class CreditProvider with ChangeNotifier {
  final CustomerProvider _customerProvider;
  final InventoryProvider _inventoryProvider;
  final CreditService _creditService;

  List<Customer> _overdueCustomers = [];
  List<Customer> get overdueCustomers => _overdueCustomers;

  List<CreditTransaction> _transactions = [];
  List<CreditTransaction> get transactions => _transactions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isInitialized = false;
  String? _error;
  String? get error => _error;

  CreditProvider({
    required CustomerProvider customerProvider,
    required InventoryProvider inventoryProvider, // Added
    required CreditService creditService,
  }) : _customerProvider = customerProvider,
       _inventoryProvider = inventoryProvider, // Added
       _creditService = creditService;

  Future<void> fetchOverdueCustomers(BuildContext context) async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final today = DateTime.now();
    final overdueSales = salesProvider.sales.where((sale) {
      return sale.dueDate != null && sale.dueDate!.isBefore(today);
    }).toList();

    final customerIds = overdueSales.map((sale) => sale.customerId).toSet();

    _overdueCustomers = _customerProvider.customers
        .where((customer) => customerIds.contains(customer.id))
        .toList();

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<Receipt?> recordCreditSale({
    required String customerId,
    required List<SaleItem> items,
    required double total,
  }) async {
    final customer = await _customerProvider.getCustomerById(customerId);
    if (customer == null) {
      _error = 'Customer not found';
      notifyListeners();
      return null;
    }

    if (customer.balance + total > customer.creditLimit) {
      _error = 'Credit limit exceeded';
      notifyListeners();
      return null;
    }

    final transaction = CreditTransaction(
      customerId: customerId,
      amount: total,
      date: DateTime.now(),
      type: 'purchase',
      items: items.map((item) => CreditSaleItem.fromSaleItem(item)).toList(),
    );

    try {
      await _creditService.recordCreditSale(transaction);

      for (final item in items) {
        await _inventoryProvider.reduceStock(item.productId, item.quantity);
      }

      await _customerProvider.updateCustomerBalance(customerId, total);

      return Receipt(
        saleId: transaction.id ?? '',
        receiptNumber: transaction.id ?? '',
        timestamp: transaction.date,
        customerName: customer.name,
        paymentMethod: 'credit',
        items: items
            .map(
              (item) => ReceiptItem(
                productName:
                    _inventoryProvider.getProductById(item.productId)?.name ??
                    'N/A',
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
              ),
            )
            .toList(),
        subtotal: total,
        tax: 0.0,
        total: total,
      );
    } catch (e) {
      _error = 'Failed to record credit sale: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> recordPayment({
    required BuildContext context,
    required String customerId,
    required double amount,
    required String notes,
  }) async {
    // Obtain provider before any async gaps to avoid using BuildContext after awaits
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    try {
      final transaction = CreditTransaction(
        customerId: customerId,
        amount: amount,
        date: DateTime.now(),
        type: 'payment',
        notes: notes,
      );
      await _creditService.recordPayment(transaction);
      await _customerProvider.updateCustomerBalance(customerId, -amount);

      // Create a sale record for the payment
      await salesProvider.createSaleFromPayment(customerId, amount);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> getTransactionsByCustomer(String customerId) async {
    _isLoading = true;
    notifyListeners();

    _transactions = await _creditService.getTransactionsByCustomer(customerId);

    _isLoading = false;
    notifyListeners();
  }
}
