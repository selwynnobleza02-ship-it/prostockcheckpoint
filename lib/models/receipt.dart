class Receipt {
  final String saleId;
  final String receiptNumber;
  final DateTime timestamp;
  final String? customerName;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double total;

  Receipt({
    required this.saleId,
    required this.receiptNumber,
    required this.timestamp,
    this.customerName,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    this.tax = 0.0,
    required this.total,
  });

  String get formattedReceiptNumber => 'RCP-${receiptNumber.padLeft(6, '0')}';
  String get formattedTimestamp =>
      '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}

class ReceiptItem {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  ReceiptItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}
