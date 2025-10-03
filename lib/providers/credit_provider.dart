import 'package:flutter/material.dart';
import 'package:prostock/models/credit_sale_item.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/models/receipt.dart';
import 'package:prostock/models/sale.dart';
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
    DateTime? dueDate,
    required String userId,
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
      // Local-first: write transaction locally and queue for sync
      final localId = const Uuid().v4();
      try {
        final localMap = transaction.toLocalMap();
        localMap['id'] = localId;
        await LocalDatabaseService.instance.insertCreditTransaction(localMap);
      } catch (_) {}

      // Update balance locally (will queue remote update if offline)
      await _customerProvider.updateCustomerBalance(customerId, total);

      // Reduce stock and record stock movement (online inserts immediately, offline queues)
      for (final item in items) {
        await _inventoryProvider.reduceStock(
          item.productId,
          item.quantity,
          reason: 'Credit sale',
          offline: !_inventoryProvider.isOnline,
        );
      }

      // Queue remote insert of the credit transaction
      final opTx = OfflineOperation(
        type: OperationType.insertCreditTransaction,
        collectionName: 'credit_transactions',
        documentId: localId,
        data: {...transaction.toLocalMap(), 'id': localId},
        timestamp: DateTime.now(),
      );
      await _inventoryProvider.queueOperation(opTx);

      // Trigger immediate demand analysis after credit sale
      _triggerDemandAnalysis();

      // Create Sale record for notification system if dueDate is provided
      if (dueDate != null) {
        try {
          // Create Sale record for notification system using passed userId
          final saleId = const Uuid().v4();
          final sale = Sale(
            id: saleId,
            customerId: customerId,
            totalAmount: total,
            paymentMethod: 'credit',
            status: 'completed',
            createdAt: DateTime.now(),
            dueDate: dueDate,
            userId: userId,
          );

          // Store sale locally for notification system
          await LocalDatabaseService.instance.insertSale(sale);

          // Store sale items for complete record
          for (final item in items) {
            final localItem = SaleItem(
              saleId: saleId,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
            );
            await LocalDatabaseService.instance.insertSaleItem(localItem);
          }
        } catch (e) {
          ErrorLogger.logError(
            'Error creating Sale record for notifications',
            error: e,
            context: 'CreditProvider.recordCreditSale',
          );
        }
      }

      // Group items by product to avoid duplicates
      final groupedItems = _groupItemsByProduct(items);

      return Receipt(
        saleId: localId,
        receiptNumber: localId,
        timestamp: transaction.date,
        customerName: customer.name,
        paymentMethod: 'credit',
        items: groupedItems
            .map(
              (groupedItem) => ReceiptItem(
                productName:
                    _inventoryProvider
                        .getProductById(groupedItem['productId'] as String)
                        ?.name ??
                    'N/A',
                quantity: groupedItem['totalQuantity'] as int,
                unitPrice: groupedItem['unitPrice'] as double,
                totalPrice: groupedItem['totalPrice'] as double,
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
      ErrorLogger.logInfo(
        'Starting payment recording',
        context: 'CreditProvider.recordPayment',
        metadata: {'customerId': customerId, 'amount': amount},
      );

      final transaction = CreditTransaction(
        customerId: customerId,
        amount: amount,
        date: DateTime.now(),
        type: 'payment',
        notes: notes,
      );

      // Basic validations
      if (amount <= 0) {
        _error = 'Payment amount must be greater than zero';
        notifyListeners();
        return false;
      }

      // Generate a local ID for mirroring in SQLite (Firestore add() doesn't return ID here)
      final localId = const Uuid().v4();

      // Local-first for payments: write locally, queue for sync, update balance
      try {
        final localMap = transaction.toLocalMap();
        localMap['id'] = localId;
        await LocalDatabaseService.instance.insertCreditTransaction(localMap);
      } catch (_) {}

      final balanceUpdated = await _customerProvider.updateCustomerBalance(
        customerId,
        -amount,
      );
      if (!balanceUpdated) {
        _error = _customerProvider.error ?? 'Failed to update customer balance';
        notifyListeners();
        return false;
      }

      final opTx = OfflineOperation(
        type: OperationType.insertCreditTransaction,
        collectionName: 'credit_transactions',
        documentId: localId,
        // Store plain JSON without Firestore Timestamp for offline queue
        data: {...transaction.toLocalMap(), 'id': localId},
        timestamp: DateTime.now(),
      );
      await _inventoryProvider.queueOperation(opTx);

      // Create a sale record for the payment
      ErrorLogger.logInfo(
        'Creating sale record for payment',
        context: 'CreditProvider.recordPayment',
      );
      await salesProvider.createSaleFromPayment(customerId, amount);
      ErrorLogger.logInfo(
        'Sale record created successfully',
        context: 'CreditProvider.recordPayment',
      );

      ErrorLogger.logInfo(
        'Payment recording completed successfully',
        context: 'CreditProvider.recordPayment',
      );
      return true;
    } catch (e) {
      ErrorLogger.logError(
        'Error recording payment',
        error: e,
        context: 'CreditProvider.recordPayment',
      );
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
      ErrorLogger.logInfo(
        'Fetching transactions for customer',
        context: 'CreditProvider.getTransactionsByCustomer',
        metadata: {'customerId': customerId},
      );

      // Check if there are any transactions at all
      final hasTransactions = await _creditService.hasAnyTransactions();
      ErrorLogger.logInfo(
        'Database transactions presence checked',
        context: 'CreditProvider.getTransactionsByCustomer',
        metadata: {'hasTransactions': hasTransactions},
      );

      _transactions = await _creditService.getTransactionsByCustomer(
        customerId,
      );
      ErrorLogger.logInfo(
        'Transactions loaded',
        context: 'CreditProvider.getTransactionsByCustomer',
        metadata: {'count': _transactions.length},
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      ErrorLogger.logError(
        'Error fetching transactions',
        error: e,
        context: 'CreditProvider.getTransactionsByCustomer',
      );
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
}
