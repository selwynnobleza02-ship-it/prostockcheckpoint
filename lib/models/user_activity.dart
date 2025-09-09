class UserActivity {
  final String? id;
  final String userId;
  final String action;
  final String? productName;
  final String? productBarcode;
  final int? quantity;
  final double? amount;
  final String? details;
  final DateTime timestamp;

  UserActivity({
    this.id,
    required this.userId,
    required this.action,
    this.productName,
    this.productBarcode,
    this.quantity,
    this.amount,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'product_name': productName,
      'product_barcode': productBarcode,
      'quantity': quantity,
      'amount': amount,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory UserActivity.fromMap(Map<String, dynamic> map) {
    return UserActivity(
      id: map['id'],
      userId: map['user_id'],
      action: map['action'],
      productName: map['product_name'],
      productBarcode: map['product_barcode'],
      quantity: map['quantity'],
      amount: map['amount']?.toDouble(),
      details: map['details'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
