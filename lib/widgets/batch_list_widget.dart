import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prostock/models/inventory_batch.dart';
import 'package:prostock/models/product.dart';

class BatchListWidget extends StatelessWidget {
  final List<InventoryBatch> batches;
  final bool showDepleted;
  final Product? product;

  const BatchListWidget({
    super.key,
    required this.batches,
    this.showDepleted = false,
    this.product,
  });

  bool _isSystemNote(String? note) {
    if (note == null) return false;
    return note.toLowerCase().contains('initial stock migration') ||
        note.toLowerCase().contains('fifo system');
  }

  @override
  Widget build(BuildContext context) {
    final displayBatches = showDepleted
        ? batches
        : batches.where((b) => b.hasStock).toList();

    if (displayBatches.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No batches available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayBatches.length,
      itemBuilder: (context, index) {
        final batch = displayBatches[index];
        final isActive = batch.hasStock && !batch.isDepleted;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Batch number and status
                Row(
                  children: [
                    // Batch Number Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Batch ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Status Badge
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sold Out',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info Grid
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Date and Cost Row
                      Row(
                        children: [
                          // Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date Received',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'MMM d, y',
                                  ).format(batch.dateReceived),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Cost per unit
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Cost per Unit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${batch.unitCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Expiration Date Row
                      if (product?.expirationDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: product!.isExpired
                                  ? Colors.red.shade50
                                  : product!.isExpiringSoon
                                  ? Colors.orange.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: product!.isExpired
                                    ? Colors.red.shade300
                                    : product!.isExpiringSoon
                                    ? Colors.orange.shade300
                                    : Colors.blue.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  product!.isExpired
                                      ? Icons.error_outline
                                      : product!.isExpiringSoon
                                      ? Icons.warning_amber_rounded
                                      : Icons.event,
                                  size: 16,
                                  color: product!.isExpired
                                      ? Colors.red.shade700
                                      : product!.isExpiringSoon
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product!.isExpired
                                            ? 'Expired'
                                            : 'Expiration Date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: product!.isExpired
                                              ? Colors.red.shade700
                                              : product!.isExpiringSoon
                                              ? Colors.orange.shade700
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat(
                                          'MMM d, y',
                                        ).format(product!.expirationDate!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: product!.isExpired
                                              ? Colors.red.shade900
                                              : product!.isExpiringSoon
                                              ? Colors.orange.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (product!.isExpiringSoon &&
                                          !product!.isExpired)
                                        Text(
                                          '${product!.daysUntilExpiration} days remaining',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Stock Status
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${batch.quantityRemaining}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? Colors.green.shade700
                                            : Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      ' / ${batch.quantityReceived}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'units',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: batch.quantityReceived > 0
                              ? batch.quantitySold / batch.quantityReceived
                              : 0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            batch.isDepleted
                                ? Colors.grey
                                : (batch.percentageSold > 75
                                      ? Colors.orange
                                      : Colors.green),
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sold: ${batch.quantitySold} units',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${batch.percentageSold.toStringAsFixed(0)}% sold',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Total Value
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Value',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '₱${batch.totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                // User notes only (hide system notes)
                if (batch.notes != null &&
                    batch.notes!.isNotEmpty &&
                    !_isSystemNote(batch.notes))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        batch.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
