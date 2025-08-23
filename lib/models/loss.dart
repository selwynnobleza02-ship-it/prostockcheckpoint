class Loss {
  final String? id;
  final String productId;
  final int quantity;
  final double totalCost;
  final String reason;
  final DateTime timestamp;

  Loss({
    this.id,
    required this.productId,
    required this.quantity,
    required this.totalCost,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'totalCost': totalCost,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Loss.fromMap(Map<String, dynamic> map) {
    return Loss(
      id: map['id'],
      productId: map['productId'],
      quantity: map['quantity'],
      totalCost: map['totalCost'],
      reason: map['reason'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
