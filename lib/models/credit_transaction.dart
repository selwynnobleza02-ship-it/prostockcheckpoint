import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/models/credit_sale_item.dart';

class CreditTransaction {
  final String? id;
  final String customerId;
  final double amount;
  final DateTime date;
  final String type; // e.g., 'payment', 'purchase'
  final String? notes;
  final List<CreditSaleItem> items;

  CreditTransaction({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    required this.type,
    this.notes,
    this.items = const [],
  });

  CreditTransaction copyWith({
    String? id,
    String? customerId,
    double? amount,
    DateTime? date,
    String? type,
    String? notes,
    List<CreditSaleItem>? items,
  }) {
    return CreditTransaction(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(
        date,
      ), // Add createdAt field for consistency
      'type': type,
      'notes': notes,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map, String id) {
    // Handle both 'date' and 'createdAt' fields for backward compatibility
    Timestamp? dateTimestamp =
        map['date'] as Timestamp? ?? map['createdAt'] as Timestamp?;

    return CreditTransaction(
      id: id,
      customerId: map['customerId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: dateTimestamp?.toDate() ?? DateTime.now(),
      type: map['type'] ?? '',
      notes: map['notes'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((item) => CreditSaleItem.fromMap(item))
              .toList() ??
          const [],
    );
  }
}
