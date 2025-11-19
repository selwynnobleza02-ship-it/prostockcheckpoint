import 'package:cloud_firestore/cloud_firestore.dart';

class PriceHistory {
  final String id;
  final String productId;
  final double price;
  final DateTime timestamp;
  final String? batchId;
  final String? batchNumber;
  final double? cost;
  final String? reason;

  PriceHistory({
    required this.id,
    required this.productId,
    required this.price,
    required this.timestamp,
    this.batchId,
    this.batchNumber,
    this.cost,
    this.reason,
  });

  // Factory constructor to create a PriceHistory instance from a Firestore document
  factory PriceHistory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PriceHistory(
      id: doc.id,
      productId: data['productId'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      batchId: data['batchId'] as String?,
      batchNumber: data['batchNumber'] as String?,
      cost: (data['cost'] as num?)?.toDouble(),
      reason: data['reason'] as String?,
    );
  }

  // Method to convert a PriceHistory instance to a map for Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'productId': productId,
      'price': price,
      'timestamp': Timestamp.fromDate(timestamp),
    };

    if (batchId != null) map['batchId'] = batchId!;
    if (batchNumber != null) map['batchNumber'] = batchNumber!;
    if (cost != null) map['cost'] = cost!;
    if (reason != null) map['reason'] = reason!;

    return map;
  }

  // Helper to calculate markup percentage
  double? get markupPercentage {
    if (cost == null || cost == 0) return null;
    return ((price - cost!) / cost!) * 100;
  }

  // Helper to calculate margin amount
  double? get marginAmount {
    if (cost == null) return null;
    return price - cost!;
  }
}
