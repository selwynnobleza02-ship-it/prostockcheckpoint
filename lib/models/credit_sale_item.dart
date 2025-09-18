import 'package:prostock/models/sale_item.dart';

class CreditSaleItem {
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  CreditSaleItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory CreditSaleItem.fromSaleItem(SaleItem saleItem) {
    return CreditSaleItem(
      productId: saleItem.productId,
      quantity: saleItem.quantity,
      unitPrice: saleItem.unitPrice,
      totalPrice: saleItem.totalPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory CreditSaleItem.fromMap(Map<String, dynamic> map) {
    return CreditSaleItem(
      productId: map['productId'],
      quantity: map['quantity'],
      unitPrice: map['unitPrice'],
      totalPrice: map['totalPrice'],
    );
  }
}
