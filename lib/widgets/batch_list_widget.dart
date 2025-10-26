import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prostock/models/inventory_batch.dart';

class BatchListWidget extends StatelessWidget {
  final List<InventoryBatch> batches;
  final bool showDepleted;

  const BatchListWidget({
    super.key,
    required this.batches,
    this.showDepleted = false,
  });

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
        final isOldest = index == 0 && batch.hasStock;

        return Card(
          elevation: isOldest ? 3 : 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: batch.isDepleted
              ? Colors.grey.shade100
              : (isOldest ? Colors.blue.shade50 : null),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: batch.isDepleted
                  ? Colors.grey
                  : (isOldest ? Colors.blue : Colors.green),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    batch.batchNumber,
                    style: TextStyle(
                      fontWeight: isOldest
                          ? FontWeight.bold
                          : FontWeight.normal,
                      decoration: batch.isDepleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (isOldest && !batch.isDepleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'FIFO NEXT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (batch.isDepleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DEPLETED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Received: ${DateFormat('MMM d, y').format(batch.dateReceived)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Cost: ₱${batch.unitCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${batch.quantityRemaining}/${batch.quantityReceived}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Sold: ${batch.quantitySold} (${batch.percentageSold.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (batch.notes != null && batch.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      batch.notes!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${batch.totalValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Total Value',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
