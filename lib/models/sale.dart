class Sale {
  late final String? id;
  final String? customerId;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  Sale({
    this.id,
    this.customerId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  }) {
    _validateSale();
  }

  void _validateSale() {
    if (totalAmount <= 0) {
      throw ArgumentError('Total amount must be greater than zero');
    }
    if (totalAmount > 1000000) {
      throw ArgumentError('Total amount cannot exceed ₱1,000,000');
    }
    if (!_isValidPaymentMethod(paymentMethod)) {
      throw ArgumentError('Invalid payment method');
    }
    if (!_isValidStatus(status)) {
      throw ArgumentError('Invalid sale status');
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
      'customer_id': customerId,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    final totalAmount = map['total_amount'];
    if (totalAmount == null) {
      throw ArgumentError('Total amount cannot be null');
    }
    return Sale(
      id: map['id']?.toString(),
      customerId: map['customer_id']?.toString(),
      totalAmount: totalAmount.toDouble(),
      paymentMethod: map['payment_method'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Sale copyWith({
    String? id,
    String? customerId,
    double? totalAmount,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SaleItem {
  final String? id;
  late final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  }) {
    _validateSaleItem();
  }

  void _validateSaleItem() {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero');
    }
    if (quantity > 1000) {
      throw ArgumentError('Quantity cannot exceed 1000 items');
    }
    if (unitPrice <= 0) {
      throw ArgumentError('Unit price must be greater than zero');
    }
    if (totalPrice <= 0) {
      throw ArgumentError('Total price must be greater than zero');
    }
    // Validate that totalPrice matches quantity * unitPrice
    final expectedTotal = quantity * unitPrice;
    if ((totalPrice - expectedTotal).abs() > 0.01) {
      throw ArgumentError('Total price does not match quantity × unit price');
    }
  }

  bool get isValidCalculation =>
      (totalPrice - (quantity * unitPrice)).abs() <= 0.01;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id']?.toString(),
      saleId: map['sale_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      totalPrice: (map['total_price'] ?? 0).toDouble(),
    );
  }
}
