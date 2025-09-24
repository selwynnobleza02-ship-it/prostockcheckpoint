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
import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/services/demand_analysis_service.dart';
import 'package:prostock/services/notification_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class CreditProvider with ChangeNotifier {
  final CustomerProvider _customerProvider;
  final InventoryProvider _inventoryProvider;
  final CreditService _creditService;
  late final DemandAnalysisService _demandAnalysisService;

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
       _creditService = creditService {
    _demandAnalysisService = DemandAnalysisService(
      LocalDatabaseService.instance,
      NotificationService(),
    );
  }

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

      // Trigger immediate demand analysis after credit sale
      _triggerDemandAnalysis();

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
      print(
        'CreditProvider: Starting payment recording for customer: $customerId, amount: $amount',
      );

      final transaction = CreditTransaction(
        customerId: customerId,
        amount: amount,
        date: DateTime.now(),
        type: 'payment',
        notes: notes,
      );

      // Generate a local ID for mirroring in SQLite (Firestore add() doesn't return ID here)
      final localId = const Uuid().v4();

      if (_inventoryProvider.isOnline) {
        print('CreditProvider: Recording payment transaction...');
        await _creditService.recordPayment(transaction);
        print('CreditProvider: Payment transaction recorded successfully');

        print('CreditProvider: Updating customer balance...');
        await _customerProvider.updateCustomerBalance(customerId, -amount);
        print('CreditProvider: Customer balance updated successfully');
        // Mirror online credit transaction locally for offline history
        try {
          final localMap = transaction.toLocalMap();
          localMap['id'] = localId;
          await LocalDatabaseService.instance.insertCreditTransaction(localMap);
        } catch (_) {}
      } else {
        // Queue offline operations: insertCreditTransaction + updateCustomerBalance
        // Insert immediately into local cache for offline history
        try {
          final localMap = transaction.toLocalMap();
          localMap['id'] = localId;
          await LocalDatabaseService.instance.insertCreditTransaction(localMap);
        } catch (_) {}

        // Also update local balance immediately and queue remote sync via provider
        await _customerProvider.updateCustomerBalance(customerId, -amount);

        final opTx = OfflineOperation(
          type: OperationType.insertCreditTransaction,
          collectionName: 'credit_transactions',
          documentId: localId,
          // Store plain JSON without Firestore Timestamp for offline queue
          data: {...transaction.toLocalMap(), 'id': localId},
          timestamp: DateTime.now(),
        );
        await _inventoryProvider.queueOperation(opTx);

        // Show offline material banner notification
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentMaterialBanner();
        messenger.showMaterialBanner(
          MaterialBanner(
            content: const Text(
              'Offline: Payment recorded locally. It will sync when online.',
            ),
            leading: const Icon(Icons.cloud_off),
            backgroundColor: Colors.amber.shade100,
            actions: [
              TextButton(
                onPressed: () => messenger.hideCurrentMaterialBanner(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }

      // Create a sale record for the payment
      print('CreditProvider: Creating sale record for payment...');
      await salesProvider.createSaleFromPayment(customerId, amount);
      print('CreditProvider: Sale record created successfully');

      print('CreditProvider: Payment recording completed successfully');
      return true;
    } catch (e) {
      print('CreditProvider: Error recording payment: $e');
      _error = 'Failed to record payment: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> getTransactionsByCustomer(String customerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('CreditProvider: Fetching transactions for customer: $customerId');

      // Check if there are any transactions at all
      final hasTransactions = await _creditService.hasAnyTransactions();
      print('CreditProvider: Database has transactions: $hasTransactions');

      _transactions = await _creditService.getTransactionsByCustomer(
        customerId,
      );
      print('CreditProvider: Found ${_transactions.length} transactions');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('CreditProvider: Error fetching transactions: $e');
      _error = 'Failed to load transactions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggers immediate demand analysis after a credit sale to check for threshold suggestions
  void _triggerDemandAnalysis() {
    // Run in background without blocking the UI
    Future.microtask(() async {
      try {
        final suggestions = await _demandAnalysisService.computeSuggestions();
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
          context: 'CreditProvider._triggerDemandAnalysis',
        );
      }
    });
  }
}
