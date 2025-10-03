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
    const validMethods = [
      'cash',
      'credit',
      'card',
      'gcash',
      'paymaya',
      // Special methods for customer debt settlements recorded as sales
      'credit_payment',
      'debt_payment',
      'credit payment', // backward-compat for spaced label
      'debt payment',
    ];
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
    // Support both snake_case (local DB) and camelCase (Firestore) field names
    final dynamic totalAmountRaw = map['total_amount'] ?? map['totalAmount'];
    if (totalAmountRaw == null) {
      throw ArgumentError('Total amount cannot be null');
    }

    final String userId = (map['user_id'] ?? map['userId'] ?? '').toString();
    final String? customerId = (map['customer_id'] ?? map['customerId'])
        ?.toString();
    final String paymentMethod =
        (map['payment_method'] ?? map['paymentMethod'] ?? '').toString();
    final String status = (map['status'] ?? 'pending').toString();

    // createdAt may be an ISO string (local) or a Firestore Timestamp
    final dynamic createdAtRaw = map['created_at'] ?? map['createdAt'];
    DateTime createdAt;
    if (createdAtRaw == null) {
      createdAt = DateTime.now();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAt = DateTime.parse(createdAtRaw);
    } else {
      // Attempt to call toDate() if it's a Firestore Timestamp-like object
      try {
        createdAt = createdAtRaw.toDate();
      } catch (_) {
        createdAt = DateTime.now();
      }
    }

    // dueDate may be ISO string or Firestore Timestamp or null
    final dynamic dueDateRaw = map['due_date'] ?? map['dueDate'];
    DateTime? dueDate;
    if (dueDateRaw == null) {
      dueDate = null;
    } else if (dueDateRaw is DateTime) {
      dueDate = dueDateRaw;
    } else if (dueDateRaw is String) {
      dueDate = DateTime.parse(dueDateRaw);
    } else {
      try {
        dueDate = dueDateRaw.toDate();
      } catch (_) {
        dueDate = null;
      }
    }

    final int isSynced =
        (map['is_synced'] ?? map['isSynced'] ?? AppDefaults.notSynced) as int;

    return Sale(
      id: map['id']?.toString(),
      userId: userId,
      customerId: customerId,
      totalAmount: (totalAmountRaw as num).toDouble(),
      paymentMethod: paymentMethod,
      status: status,
      createdAt: createdAt,
      dueDate: dueDate,
      isSynced: isSynced,
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
