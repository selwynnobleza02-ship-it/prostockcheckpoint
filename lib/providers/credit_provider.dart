import 'package:flutter/material.dart';
import '../models/credit_transaction.dart';
import '../services/firestore_service.dart';
import '../utils/error_logger.dart'; // Import ErrorLogger
import 'customer_provider.dart';

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
      _transactions = await FirestoreService.instance.getAllCreditTransactions();
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
      final id = await FirestoreService.instance.insertCreditTransaction(
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

  /// Records a payment made by a customer
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

      final newBalance = await FirestoreService.instance.updateCustomerBalance(customerId, -amount);
      customerProvider.updateLocalCustomerBalance(customerId, newBalance);

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

  /// Records a credit sale for a customer
  Future<bool> recordCreditSale(
    String customerId,
    double amount, {
    String? description,
  }) async {
    if (amount <= 0) {
      _error = 'Invalid credit amount';
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
        type: 'credit',
        description: description ?? 'Credit sale',
        createdAt: DateTime.now(),
      );

      await addCreditTransaction(transaction);

      final newBalance = await FirestoreService.instance.updateCustomerBalance(customerId, amount);
      customerProvider.updateLocalCustomerBalance(customerId, newBalance);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to record credit sale: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      ErrorLogger.logError(
        'Error recording credit sale',
        error: e,
        context: 'CreditProvider.recordCreditSale',
      );
      return false;
    }
  }

  /// Gets all transactions for a specific customer
  List<CreditTransaction> getTransactionsByCustomer(String customerId) {
    return _transactions.where((t) => t.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  /// Gets the total credit amount for a customer
  double getTotalCreditForCustomer(String customerId) {
    return _transactions
        .where((t) => t.customerId == customerId && t.type == 'credit')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Gets the total payments made by a customer
  double getTotalPaymentsForCustomer(String customerId) {
    return _transactions
        .where((t) => t.customerId == customerId && t.type == 'payment')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Gets the current balance for a customer based on transactions
  double getCurrentBalanceForCustomer(String customerId) {
    final totalCredit = getTotalCreditForCustomer(customerId);
    final totalPayments = getTotalPaymentsForCustomer(customerId);
    return totalCredit - totalPayments;
  }

  /// Clears all transactions (for testing purposes)
  void clearTransactions() {
    _transactions.clear();
    notifyListeners();
  }
}
