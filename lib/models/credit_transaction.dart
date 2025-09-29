import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
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

  // Local-only map for SQLite/offline queue (no Firestore Timestamp types)
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'customerId': customerId,
      'amount': amount,
      'date': date.toIso8601String(),
      'createdAt': date.toIso8601String(),
      'type': type,
      'notes': notes,
      // Persist as JSON string for SQLite
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map, String id) {
    // Handle both 'date' and 'createdAt' fields for backward compatibility
    // Support both Timestamp and String formats
    DateTime? date;

    final dateValue = map['date'] ?? map['createdAt'];
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is String) {
      try {
        date = DateTime.parse(dateValue);
      } catch (e) {
        date = DateTime.now();
      }
    } else {
      date = DateTime.now();
    }

    return CreditTransaction(
      id: id,
      customerId: map['customerId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: date,
      type: map['type'] ?? '',
      notes: map['notes'] ?? '',
      items: _parseItems(map['items']),
    );
  }

  static List<CreditSaleItem> _parseItems(dynamic items) {
    if (items == null) return const [];

    // Handle Firestore format (List<dynamic>)
    if (items is List<dynamic>) {
      return items.map((item) => CreditSaleItem.fromMap(item)).toList();
    }

    // Handle SQLite format (JSON string)
    if (items is String) {
      try {
        final List<dynamic> itemsList = jsonDecode(items);
        return itemsList.map((item) => CreditSaleItem.fromMap(item)).toList();
      } catch (e) {
        return const [];
      }
    }

    return const [];
  }
}
