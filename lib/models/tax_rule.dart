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
    return TaxRule(
      id: map['id'] ?? '',
      categoryName: map['categoryName'],
      productId: map['productId'],
      tubo: (map['tubo'] ?? map['rate'] ?? 2.0)
          .toDouble(), // Support both old and new field names
      isInclusive: map['isInclusive'] ?? true,
      priority: map['priority'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
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
