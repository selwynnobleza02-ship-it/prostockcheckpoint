import 'package:flutter/material.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/services/firestore/credit_service.dart';

class CreditProvider with ChangeNotifier {
  final CustomerProvider _customerProvider;
  final SalesProvider _salesProvider;
  final CreditService _creditService;

  List<Customer> _overdueCustomers = [];
  List<Customer> get overdueCustomers => _overdueCustomers;

  List<CreditTransaction> _transactions = [];
  List<CreditTransaction> get transactions => _transactions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isInitialized = false;

  CreditProvider({
    required CustomerProvider customerProvider,
    required SalesProvider salesProvider,
    required CreditService creditService,
  })  : _customerProvider = customerProvider,
        _salesProvider = salesProvider,
        _creditService = creditService;

  Future<void> fetchOverdueCustomers() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    final today = DateTime.now();
    final overdueSales = _salesProvider.sales.where((sale) {
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

  Future<bool> recordPayment({
    required String customerId,
    required double amount,
    required String notes,
  }) async {
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