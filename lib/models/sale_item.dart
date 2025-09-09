import 'package:prostock/utils/app_constants.dart';

class SaleItem {
  final String? id;
  late final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  }) {
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
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id']?.toString(),
      saleId: map['saleId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
    );
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}