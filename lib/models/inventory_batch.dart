import 'package:uuid/uuid.dart';

class InventoryBatch {
  final String id;
  final String productId;
  final String batchNumber;
  final int quantityReceived;
  final int quantityRemaining;
  final double unitCost;
  final DateTime dateReceived;
  final String? supplierId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryBatch({
    String? id,
    required this.productId,
    required this.batchNumber,
    required this.quantityReceived,
    required this.quantityRemaining,
    required this.unitCost,
    required this.dateReceived,
    this.supplierId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now() {
    _validateBatch();
  }

  void _validateBatch() {
    if (batchNumber.trim().isEmpty) {
      throw ArgumentError('Batch number cannot be empty');
    }
    if (quantityReceived <= 0) {
      throw ArgumentError('Quantity received must be greater than zero');
    }
    if (quantityRemaining < 0) {
      throw ArgumentError('Quantity remaining cannot be negative');
    }
    if (quantityRemaining > quantityReceived) {
      throw ArgumentError('Quantity remaining cannot exceed quantity received');
    }
    if (unitCost < 0) {
      throw ArgumentError('Unit cost cannot be negative');
    }
  }

  // Computed properties
  int get quantitySold => quantityReceived - quantityRemaining;
  bool get isDepleted => quantityRemaining <= 0;
  bool get hasStock => quantityRemaining > 0;
  double get totalValue => quantityRemaining * unitCost;
  double get soldValue => quantitySold * unitCost;

  // Percentage sold
  double get percentageSold {
    if (quantityReceived == 0) return 0;
    return (quantitySold / quantityReceived) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'batch_number': batchNumber,
      'quantity_received': quantityReceived,
      'quantity_remaining': quantityRemaining,
      'unit_cost': unitCost,
      'date_received': dateReceived.toIso8601String(),
      'supplier_id': supplierId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory InventoryBatch.fromMap(Map<String, dynamic> map) {
    return InventoryBatch(
      id: map['id']?.toString(),
      productId: map['product_id']?.toString() ?? '',
      batchNumber: map['batch_number']?.toString() ?? '',
      quantityReceived: map['quantity_received'] ?? 0,
      quantityRemaining: map['quantity_remaining'] ?? 0,
      unitCost: (map['unit_cost'] ?? 0).toDouble(),
      dateReceived: DateTime.parse(map['date_received']),
      supplierId: map['supplier_id']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  InventoryBatch copyWith({
    String? id,
    String? productId,
    String? batchNumber,
    int? quantityReceived,
    int? quantityRemaining,
    double? unitCost,
    DateTime? dateReceived,
    String? supplierId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      quantityRemaining: quantityRemaining ?? this.quantityRemaining,
      unitCost: unitCost ?? this.unitCost,
      dateReceived: dateReceived ?? this.dateReceived,
      supplierId: supplierId ?? this.supplierId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'InventoryBatch(id: $id, batch: $batchNumber, remaining: $quantityRemaining/$quantityReceived @ ₱$unitCost)';
  }
}
