import 'package:prostock/models/sale_item.dart';

class CreditSaleItem {
  final String productId;
  final String? batchId; // Batch ID for tracking
  final int quantity;
  final double unitPrice;
  final double unitCost; // Cost at time of sale (for accurate COGS)
  final double batchCost; // Original batch cost
  final double totalPrice;

  CreditSaleItem({
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    double? batchCost,
    required this.totalPrice,
  }) : batchCost = batchCost ?? unitCost;

  factory CreditSaleItem.fromSaleItem(SaleItem saleItem) {
    return CreditSaleItem(
      productId: saleItem.productId,
      batchId: saleItem.batchId,
      quantity: saleItem.quantity,
      unitPrice: saleItem.unitPrice,
      unitCost: saleItem.unitCost,
      batchCost: saleItem.batchCost,
      totalPrice: saleItem.totalPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'batchId': batchId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unitCost': unitCost,
      'batchCost': batchCost,
      'totalPrice': totalPrice,
    };
  }

  factory CreditSaleItem.fromMap(Map<String, dynamic> map) {
    return CreditSaleItem(
      productId: map['productId'],
      batchId: map['batchId']?.toString(),
      quantity: map['quantity'],
      unitPrice: map['unitPrice'],
      unitCost: map['unitCost'] ?? 0.0,
      batchCost: map['batchCost'] ?? map['unitCost'] ?? 0.0,
      totalPrice: map['totalPrice'],
    );
  }
}
