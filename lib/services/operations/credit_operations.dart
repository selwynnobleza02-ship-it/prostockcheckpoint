import 'package:prostock/services/operations/base_operation.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/credit_sale_item.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/services/firestore/credit_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Operation to create a credit payment (unified operation that prevents duplication)
class CreateCreditPaymentOperation extends BaseOperation {
  final String customerId;
  final double amount;
  final String notes;
  final bool isOnline;

  CreateCreditPaymentOperation({
    required this.customerId,
    required this.amount,
    required this.notes,
    this.isOnline = false,
    super.operationId,
    super.timestamp,
  }) : super(
         operationType: 'create_credit_payment',
         priority: 6, // Highest priority for credit payments
       );

  @override
  Future<OperationResult> execute() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Validate input
      if (customerId.isEmpty) {
        return OperationResult.failure(
          'Customer ID is required',
          errorCode: 'INVALID_CUSTOMER_ID',
        );
      }

      if (amount <= 0) {
        return OperationResult.failure(
          'Amount must be positive',
          errorCode: 'INVALID_AMOUNT',
        );
      }

      // Create credit transaction
      final transaction = CreditTransaction(
        customerId: customerId,
        amount: amount,
        date: DateTime.now(),
        type: 'payment',
        notes: notes,
        items: const [],
      );

      // Create sale record for the payment
      final sale = Sale(
        id: operationId, // Use operation ID as sale ID
        customerId: customerId,
        totalAmount: amount,
        paymentMethod: 'credit_payment',
        status: 'completed',
        createdAt: DateTime.now(),
        userId: 'system', // This should be passed from context
      );

      // Save to local database
      await _saveToLocalDatabase(transaction, sale);

      // If online, also save to Firestore
      if (isOnline) {
        await _saveToFirestore(transaction, sale);
      }

      stopwatch.stop();

      ErrorLogger.logInfo(
        'Credit payment $operationId created successfully in ${stopwatch.elapsedMilliseconds}ms',
        context: 'CreateCreditPaymentOperation.execute',
      );

      return OperationResult.success({
        'transaction': transaction.toMap(),
        'sale': sale.toMap(),
      }, executionTime: stopwatch.elapsed);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to create credit payment $operationId',
        error: e,
        context: 'CreateCreditPaymentOperation.execute',
      );

      return OperationResult.failure(
        'Failed to create credit payment: ${e.toString()}',
        errorCode: 'CREDIT_PAYMENT_ERROR',
      );
    }
  }

  @override
  bool validate() {
    return super.validate() &&
        customerId.isNotEmpty &&
        amount > 0 &&
        notes.isNotEmpty;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'customerId': customerId,
      'amount': amount,
      'notes': notes,
      'isOnline': isOnline,
    };
  }

  /// Create operation from map
  static CreateCreditPaymentOperation? fromMap(Map<String, dynamic> map) {
    try {
      return CreateCreditPaymentOperation(
        operationId: map['operationId'] as String?,
        customerId: map['customerId'] as String,
        amount: (map['amount'] as num).toDouble(),
        notes: map['notes'] as String,
        isOnline: map['isOnline'] as bool? ?? false,
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'] as String)
            : null,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to deserialize CreateCreditPaymentOperation',
        error: e,
        context: 'CreateCreditPaymentOperation.fromMap',
      );
      return null;
    }
  }

  /// Save credit payment to local database
  Future<void> _saveToLocalDatabase(
    CreditTransaction transaction,
    Sale sale,
  ) async {
    final db = await LocalDatabaseService.instance.database;

    // Save credit transaction
    await db.insert(
      'credit_transactions',
      transaction.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save sale record
    await db.insert(
      'sales',
      sale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save credit payment to Firestore
  Future<void> _saveToFirestore(
    CreditTransaction transaction,
    Sale sale,
  ) async {
    final creditService = CreditService();

    // Save credit transaction to Firestore
    await creditService.recordPayment(transaction);

    // Save sale to Firestore (this would be handled by sale service)
    // For now, just log the operation
    ErrorLogger.logInfo(
      'Credit payment $operationId would be synced to Firestore',
      context: 'CreateCreditPaymentOperation._saveToFirestore',
    );
  }
}

/// Operation to create a credit sale
class CreateCreditSaleOperation extends BaseOperation {
  final String customerId;
  final List<Map<String, dynamic>> items;
  final double total;
  final bool isOnline;

  CreateCreditSaleOperation({
    required this.customerId,
    required this.items,
    required this.total,
    this.isOnline = false,
    super.operationId,
    super.timestamp,
  }) : super(
         operationType: 'create_credit_sale',
         priority: 5, // High priority for credit sales
       );

  @override
  Future<OperationResult> execute() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Validate input
      if (customerId.isEmpty) {
        return OperationResult.failure(
          'Customer ID is required',
          errorCode: 'INVALID_CUSTOMER_ID',
        );
      }

      if (items.isEmpty) {
        return OperationResult.failure(
          'Credit sale must have at least one item',
          errorCode: 'EMPTY_ITEMS',
        );
      }

      if (total <= 0) {
        return OperationResult.failure(
          'Total amount must be positive',
          errorCode: 'INVALID_TOTAL',
        );
      }

      // Create credit transaction
      final transaction = CreditTransaction(
        customerId: customerId,
        amount: total,
        date: DateTime.now(),
        type: 'purchase',
        items: items
            .map(
              (item) => CreditSaleItem(
                productId: item['productId'] as String,
                quantity: item['quantity'] as int,
                unitPrice: item['unitPrice'] as double,
                totalPrice: item['totalPrice'] as double,
              ),
            )
            .toList(),
      );

      // Create sale record
      final sale = Sale(
        id: operationId,
        customerId: customerId,
        totalAmount: total,
        paymentMethod: 'credit',
        status: 'completed',
        createdAt: DateTime.now(),
        userId: 'system', // This should be passed from context
      );

      // Save to local database
      await _saveToLocalDatabase(transaction, sale);

      // If online, also save to Firestore
      if (isOnline) {
        await _saveToFirestore(transaction, sale);
      }

      stopwatch.stop();

      ErrorLogger.logInfo(
        'Credit sale $operationId created successfully in ${stopwatch.elapsedMilliseconds}ms',
        context: 'CreateCreditSaleOperation.execute',
      );

      return OperationResult.success({
        'transaction': transaction.toMap(),
        'sale': sale.toMap(),
      }, executionTime: stopwatch.elapsed);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to create credit sale $operationId',
        error: e,
        context: 'CreateCreditSaleOperation.execute',
      );

      return OperationResult.failure(
        'Failed to create credit sale: ${e.toString()}',
        errorCode: 'CREDIT_SALE_ERROR',
      );
    }
  }

  @override
  bool validate() {
    return super.validate() &&
        customerId.isNotEmpty &&
        items.isNotEmpty &&
        total > 0;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'customerId': customerId,
      'items': items,
      'total': total,
      'isOnline': isOnline,
    };
  }

  /// Create operation from map
  static CreateCreditSaleOperation? fromMap(Map<String, dynamic> map) {
    try {
      return CreateCreditSaleOperation(
        operationId: map['operationId'] as String?,
        customerId: map['customerId'] as String,
        items: List<Map<String, dynamic>>.from(map['items'] as List),
        total: (map['total'] as num).toDouble(),
        isOnline: map['isOnline'] as bool? ?? false,
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'] as String)
            : null,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Failed to deserialize CreateCreditSaleOperation',
        error: e,
        context: 'CreateCreditSaleOperation.fromMap',
      );
      return null;
    }
  }

  /// Save credit sale to local database
  Future<void> _saveToLocalDatabase(
    CreditTransaction transaction,
    Sale sale,
  ) async {
    final db = await LocalDatabaseService.instance.database;

    // Save credit transaction
    await db.insert(
      'credit_transactions',
      transaction.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save sale record
    await db.insert(
      'sales',
      sale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save credit sale to Firestore
  Future<void> _saveToFirestore(
    CreditTransaction transaction,
    Sale sale,
  ) async {
    final creditService = CreditService();

    // Save credit transaction to Firestore
    await creditService.recordCreditSale(transaction);

    // Save sale to Firestore (this would be handled by sale service)
    ErrorLogger.logInfo(
      'Credit sale $operationId would be synced to Firestore',
      context: 'CreateCreditSaleOperation._saveToFirestore',
    );
  }
}
