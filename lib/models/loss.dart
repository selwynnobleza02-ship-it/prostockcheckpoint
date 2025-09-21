import 'package:prostock/models/loss_reason.dart';

class Loss {
  final String? id;
  final String productId;
  final int quantity;
  final double totalCost;
  final LossReason reason;
  final DateTime timestamp;
  final String? recordedBy;

  Loss({
    this.id,
    required this.productId,
    required this.quantity,
    required this.totalCost,
    required this.reason,
    required this.timestamp,
    this.recordedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'totalCost': totalCost,
      'reason': reason.name, // Use enum name
      'timestamp': timestamp.toIso8601String(),
      'recordedBy': recordedBy,
    };
  }

  factory Loss.fromMap(Map<String, dynamic> map) {
    return Loss(
      id: map['id'],
      productId: map['productId'],
      quantity: map['quantity'],
      totalCost: map['totalCost'],
      reason: LossReason.values.firstWhere((e) => e.name == map['reason']), // Convert from name
      timestamp: DateTime.parse(map['timestamp']),
      recordedBy: map['recordedBy'],
    );
  }

  Loss copyWith({
    String? id,
    String? productId,
    int? quantity,
    double? totalCost,
    LossReason? reason,
    DateTime? timestamp,
    String? recordedBy,
  }) {
    return Loss(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      totalCost: totalCost ?? this.totalCost,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
      recordedBy: recordedBy ?? this.recordedBy,
    );
  }
}
