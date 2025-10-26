import 'package:prostock/utils/app_constants.dart';
import 'package:uuid/uuid.dart';

class SaleItem {
  final String id;
  late final String saleId;
  final String productId;
  final String? batchId; // NEW: Which batch this item came from
  final int quantity;
  final double unitPrice;
  final double unitCost; // Cost at time of sale (for accurate COGS)
  final double
  batchCost; // NEW: Original batch cost (same as unitCost for FIFO)
  final double totalPrice;

  SaleItem({
    String? id,
    required this.saleId,
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    double? batchCost,
    required this.totalPrice,
  }) : id = id ?? const Uuid().v4(),
       batchCost = batchCost ?? unitCost {
    _validateSaleItem();
  }

  void _validateSaleItem() {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero');
    }
    if (quantity > ValidationConstants.maxSaleQuantity) {
      throw ArgumentError('Quantity cannot exceed 1000 items');
    }
    if (unitPrice <= 0) {
      throw ArgumentError('Unit price must be greater than zero');
    }
    if (unitCost < 0) {
      throw ArgumentError('Unit cost cannot be negative');
    }
    if (totalPrice <= 0) {
      throw ArgumentError('Total price must be greater than zero');
    }
    // Validate that totalPrice matches quantity * unitPrice
    final expectedTotal = quantity * unitPrice;
    if ((totalPrice - expectedTotal).abs() > 0.01) {
      throw ArgumentError('Total price does not match quantity × unit price');
    }
  }

  bool get isValidCalculation =>
      (totalPrice - (quantity * unitPrice)).abs() <= 0.01;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'batchId': batchId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unitCost': unitCost,
      'batchCost': batchCost,
      'totalPrice': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id']?.toString(),
      saleId: map['saleId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      batchId: map['batchId']?.toString(),
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      unitCost: (map['unitCost'] ?? 0).toDouble(),
      batchCost: (map['batchCost'] ?? map['unitCost'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
    );
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    String? batchId,
    int? quantity,
    double? unitPrice,
    double? unitCost,
    double? batchCost,
    double? totalPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      batchId: batchId ?? this.batchId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      batchCost: batchCost ?? this.batchCost,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}
