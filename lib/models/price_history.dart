import 'package:cloud_firestore/cloud_firestore.dart';

class PriceHistory {
  final String id;
  final String productId;
  final double price;
  final DateTime timestamp;

  PriceHistory({
    required this.id,
    required this.productId,
    required this.price,
    required this.timestamp,
  });

  // Factory constructor to create a PriceHistory instance from a Firestore document
  factory PriceHistory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PriceHistory(
      id: doc.id,
      productId: data['productId'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Method to convert a PriceHistory instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'price': price,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}