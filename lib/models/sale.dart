import 'package:prostock/utils/app_constants.dart';

class Sale {
  late final String? id;
  final String userId;
  final String? customerId;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? dueDate;
  final int isSynced;

  Sale({
    this.id,
    required this.userId,
    this.customerId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.dueDate,
    this.isSynced = AppDefaults.notSynced,
  }) {
    _validateSale();
  }

  void _validateSale() {
    if (totalAmount <= 0) {
      throw ArgumentError('Total amount must be greater than zero');
    }
    if (totalAmount > ValidationConstants.maxTransactionAmount) {
      throw ArgumentError('Total amount cannot exceed ₱1,000,000');
    }
    if (!_isValidPaymentMethod(paymentMethod)) {
      throw ArgumentError('Invalid payment method');
    }
    if (!_isValidStatus(status)) {
      throw ArgumentError('Invalid sale status');
    }
    if (paymentMethod == 'credit' && dueDate == null) {
      throw ArgumentError('Due date is required for credit sales');
    }
  }

  bool _isValidPaymentMethod(String method) {
    const validMethods = ['cash', 'credit', 'card', 'gcash', 'paymaya'];
    return validMethods.contains(method.toLowerCase());
  }

  bool _isValidStatus(String saleStatus) {
    const validStatuses = ['pending', 'completed', 'cancelled', 'refunded'];
    return validStatuses.contains(saleStatus.toLowerCase());
  }

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get canBeModified => status.toLowerCase() == 'pending';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    final totalAmount = map['total_amount'];
    if (totalAmount == null) {
      throw ArgumentError('Total amount cannot be null');
    }
    return Sale(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString(),
      totalAmount: totalAmount.toDouble(),
      paymentMethod: map['payment_method'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      isSynced: map['is_synced'] ?? AppDefaults.notSynced,
    );
  }

  Sale copyWith({
    String? id,
    String? userId,
    String? customerId,
    double? totalAmount,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    DateTime? dueDate,
    int? isSynced,
  }) {
    return Sale(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
