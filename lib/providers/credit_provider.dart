import 'package:flutter/material.dart';
import 'package:prostock/services/firestore/sale_service.dart';
import '../models/credit_transaction.dart';
import '../utils/error_logger.dart'; // Import ErrorLogger
import 'customer_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreditProvider with ChangeNotifier {
  final CustomerProvider customerProvider;
  List<CreditTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  CreditProvider({required this.customerProvider});

  List<CreditTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final saleService = SaleService(FirebaseFirestore.instance);
      _transactions = await saleService.getAllCreditTransactions();
    } catch (e) {
      _error = 'Failed to load transactions: ${e.toString()}';
      ErrorLogger.logError(
        'Error loading transactions',
        error: e,
        context: 'CreditProvider.loadTransactions',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCreditTransaction(CreditTransaction transaction) async {
    try {
      final saleService = SaleService(FirebaseFirestore.instance);
      final id = await saleService.insertCreditTransaction(
        transaction,
      );
      final newTransaction = CreditTransaction(
        id: id,
        customerId: transaction.customerId,
        amount: transaction.amount,
        type: transaction.type,
        description: transaction.description,
        createdAt: transaction.createdAt,
      );
      _transactions.add(newTransaction);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add transaction: ${e.toString()}';
      ErrorLogger.logError(
        'Error adding credit transaction',
        error: e,
        context: 'CreditProvider.addCreditTransaction',
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> recordPayment(
    String customerId,
    double amount, {
    String? description,
  }) async {
    if (amount <= 0) {
      _error = 'Invalid payment amount';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final transaction = CreditTransaction(
        customerId: customerId,
        amount: amount,
        type: 'payment',
        description: description ?? 'Payment received',
        createdAt: DateTime.now(),
      );

      await addCreditTransaction(transaction);

      await customerProvider.updateCustomerBalance(customerId, -amount);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to record payment: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error recording payment',
        error: e,
        context: 'CreditProvider.recordPayment',
      );
      return false;
    }
  }

  List<CreditTransaction> getTransactionsByCustomer(String customerId) {
    return _transactions.where((t) => t.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void clearTransactions() {
    _transactions.clear();
    notifyListeners();
  }
}
