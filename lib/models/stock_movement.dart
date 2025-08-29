import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovement {
  final String id;
  final String productId;
  final String productName; // Denormalized for easier display
  final String movementType; // e.g., 'sale', 'stock_in', 'adjustment'
  final int quantity; // Can be positive or negative
  final String? reason;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantity,
    this.reason,
    required this.createdAt,
  });

  factory StockMovement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockMovement(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'Unknown Product',
      movementType: data['movementType'] ?? 'unknown',
      quantity: data['quantity'] ?? 0,
      reason: data['reason'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  factory StockMovement.fromMap(Map<String, dynamic> data) {
    return StockMovement(
      id: data['id'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'Unknown Product',
      movementType: data['movementType'] ?? 'unknown',
      quantity: data['quantity'] ?? 0,
      reason: data['reason'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
