import 'package:cloud_firestore/cloud_firestore.dart';

class CostHistory {
  final String id;
  final String productId;
  final double cost;
  final DateTime timestamp;

  CostHistory({
    required this.id,
    required this.productId,
    required this.cost,
    required this.timestamp,
  });

  // Factory constructor to create a CostHistory instance from a Firestore document
  factory CostHistory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CostHistory(
      id: doc.id,
      productId: data['productId'] ?? '',
      cost: (data['cost'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Method to convert a CostHistory instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'cost': cost,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Factory constructor to create a CostHistory instance from a map
  factory CostHistory.fromMap(Map<String, dynamic> data) {
    return CostHistory(
      id: data['id'] ?? '',
      productId: data['productId'] ?? '',
      cost: (data['cost'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
