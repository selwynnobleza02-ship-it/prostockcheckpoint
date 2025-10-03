import 'package:cloud_firestore/cloud_firestore.dart';

class TaxRule {
  final String id;
  final String? categoryName; // null for global rule
  final String? productId; // null for category/global rule
  final double tubo; // Fixed tubo amount in pesos
  final bool isInclusive;
  final int priority; // Higher number = higher priority
  final DateTime createdAt;
  final DateTime updatedAt;

  TaxRule({
    required this.id,
    this.categoryName,
    this.productId,
    required this.tubo,
    required this.isInclusive,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryName': categoryName,
      'productId': productId,
      'tubo': tubo,
      'isInclusive': isInclusive,
      'priority': priority,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TaxRule.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(n);
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return TaxRule(
      id: map['id'] ?? '',
      categoryName: map['categoryName'],
      productId: map['productId'],
      tubo: (map['tubo'] ?? map['rate'] ?? 2.0)
          .toDouble(), // Support both old and new field names
      isInclusive: false, // Inclusive disabled, always added on top
      priority: map['priority'] ?? 0,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  TaxRule copyWith({
    String? id,
    String? categoryName,
    String? productId,
    double? tubo,
    bool? isInclusive,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaxRule(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      productId: productId ?? this.productId,
      tubo: tubo ?? this.tubo,
      isInclusive: isInclusive ?? this.isInclusive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isGlobal => categoryName == null && productId == null;
  bool get isCategory => categoryName != null && productId == null;
  bool get isProduct => productId != null;

  String get description {
    if (isProduct) {
      return 'Product-specific rule';
    } else if (isCategory) {
      return 'Category: $categoryName';
    } else {
      return 'Global rule';
    }
  }
}
