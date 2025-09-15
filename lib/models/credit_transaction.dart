import 'package:cloud_firestore/cloud_firestore.dart';

class CreditTransaction {
  final String? id;
  final String customerId;
  final double amount;
  final DateTime date;
  final String type; // e.g., 'payment', 'credit'
  final String? notes;

  CreditTransaction({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    required this.type,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'type': type,
      'notes': notes,
    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map, String id) {
    return CreditTransaction(
      id: id,
      customerId: map['customerId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}