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
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  // Determine which theme color container to use based on the input color
  Color containerColor;
  Color onContainerColor;

  // Map common colors to theme equivalents
  if (color == Colors.green) {
    containerColor = colorScheme.primaryContainer;
    onContainerColor = colorScheme.onPrimaryContainer;
  } else if (color == Colors.red) {
    containerColor = colorScheme.errorContainer;
    onContainerColor = colorScheme.onErrorContainer;
  } else if (color == Colors.orange) {
    containerColor = colorScheme.tertiaryContainer;
    onContainerColor = colorScheme.onTertiaryContainer;
  } else if (color == Colors.blue) {
    containerColor = colorScheme.secondaryContainer;
    onContainerColor = colorScheme.onSecondaryContainer;
  } else {
    // Default to primary for other colors
    containerColor = colorScheme.primaryContainer;
    onContainerColor = colorScheme.onPrimaryContainer;
  }

  return Card(
    elevation: 1,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colorScheme.onPrimary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title: $value',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon in colored container
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: onContainerColor, size: 20),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              title,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Value with hint icon
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatLargeNumber(value),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (_formatLargeNumber(value) != value) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: colorScheme.outline.withOpacity(0.6),
                  ),
                ],
              ],
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
