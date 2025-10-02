import 'package:flutter/material.dart';
import 'package:prostock/models/receipt.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/services/firestore/customer_service.dart';
import 'package:prostock/services/firestore/product_service.dart';
import 'package:prostock/services/firestore/sale_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/widgets/receipt_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Widget buildSummaryCard(
  BuildContext context,
  String title,
  String value,
  IconData icon,
  Color color,
) {
  return Card(
    child: IntrinsicHeight(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.clearSnackBars();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$title: $value',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: color.withAlpha(230),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatLargeNumber(value),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          height: 14,
                          child: Visibility(
                            visible: _formatLargeNumber(value) != value,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Tap for details',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatLargeNumber(String value) {
  String cleanValue = value.replaceAll(RegExp(r'[₱,\s]'), '');
  double? numValue = double.tryParse(cleanValue);
  if (numValue == null) return value;

  if (numValue >= 1000000) {
    return '₱${(numValue / 1000000).toStringAsFixed(1)}M';
  } else if (numValue >= 1000) {
    return '₱${(numValue / 1000).toStringAsFixed(1)}K';
  } else {
    return value;
  }
}

Future<void> showHistoricalReceipt(BuildContext context, Sale sale) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final saleService = SaleService(FirebaseFirestore.instance);
    final customerService = CustomerService(FirebaseFirestore.instance);
    final productService = ProductService(FirebaseFirestore.instance);

    List<SaleItem> saleItems = [];
    if (sale.isSynced == 1) {
      saleItems = await saleService.getSaleItemsBySaleId(sale.id!);
    } else {
      final localItems = await LocalDatabaseService.instance.getSaleItems(
        sale.id!,
      );
      saleItems = localItems.map((item) => SaleItem.fromMap(item)).toList();
    }

    String? customerName;
    if (sale.customerId != null) {
      final customer = await customerService.getCustomerById(sale.customerId!);
      customerName = customer?.name;
    }

    // Group sale items by product to avoid duplicate lines
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final item in saleItems) {
      if (grouped.containsKey(item.productId)) {
        final existing = grouped[item.productId]!;
        existing['quantity'] = (existing['quantity'] as int) + item.quantity;
        existing['totalPrice'] =
            (existing['totalPrice'] as double) + item.totalPrice;
        // Keep unitPrice consistent; if it varies, recompute later from total/qty
      } else {
        grouped[item.productId] = {
          'productId': item.productId,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'totalPrice': item.totalPrice,
        };
      }
    }

    // Build receipt items from grouped data
    List<ReceiptItem> receiptItems = [];
    for (final groupedItem in grouped.values) {
      final productId = groupedItem['productId'] as String;
      final product = await productService.getProductById(productId);
      final quantity = groupedItem['quantity'] as int;
      final totalPrice = groupedItem['totalPrice'] as double;
      final unitPrice = quantity > 0
          ? (totalPrice / quantity)
          : (groupedItem['unitPrice'] as double);

      receiptItems.add(
        ReceiptItem(
          productName: product?.name ?? 'Unknown Product',
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: totalPrice,
        ),
      );
    }

    final receipt = Receipt(
      receiptNumber: sale.id.toString(),
      timestamp: sale.createdAt,
      customerName: customerName,
      paymentMethod: sale.paymentMethod,
      items: receiptItems,
      subtotal: sale.totalAmount,
      tax: 0.0,
      total: sale.totalAmount,
      saleId: sale.id.toString(),
    );

    if (context.mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => ReceiptDialog(receipt: receipt),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading receipt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
