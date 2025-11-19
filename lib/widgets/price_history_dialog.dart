import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/services/firestore/product_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/utils/currency_utils.dart';

class PriceHistoryDialog extends StatefulWidget {
  final String productId;

  const PriceHistoryDialog({super.key, required this.productId});

  @override
  PriceHistoryDialogState createState() => PriceHistoryDialogState();
}

class PriceHistoryDialogState extends State<PriceHistoryDialog> {
  late Future<List<PriceHistory>> _priceHistoryFuture;

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
  }

  void _loadPriceHistory() {
    final productService = ProductService(FirebaseFirestore.instance);
    setState(() {
      _priceHistoryFuture = productService.getPriceHistory(widget.productId);
    });
  }

  String _getPriceChangeText(PriceHistory current, PriceHistory? previous) {
    if (previous == null) {
      return 'First Price';
    }

    final difference = current.price - previous.price;
    if (difference.abs() < 0.01) {
      return '(Same)';
    }

    final percentage = (difference / previous.price * 100).abs();
    final sign = difference > 0 ? '▲' : '▼';
    final changeText = difference > 0 ? '+' : '';

    return '$sign $changeText${CurrencyUtils.formatCurrency(difference.abs())} ($changeText${percentage.toStringAsFixed(1)}%)';
  }

  Color _getPriceChangeColor(PriceHistory current, PriceHistory? previous) {
    if (previous == null) return Colors.blue;

    final difference = current.price - previous.price;
    if (difference.abs() < 0.01) return Colors.grey;

    return difference > 0 ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Price History'),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPriceHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      content: FutureBuilder<List<PriceHistory>>(
        future: _priceHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading price history.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No price history found.'));
          }

          final priceHistory = snapshot.data!;

          return SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: priceHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final history = priceHistory[index];
                final previousHistory = index < priceHistory.length - 1
                    ? priceHistory[index + 1]
                    : null;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price with change indicator
                      Row(
                        children: [
                          Text(
                            CurrencyUtils.formatCurrency(history.price),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getPriceChangeText(history, previousHistory),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _getPriceChangeColor(
                                history,
                                previousHistory,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Timestamp
                      Text(
                        DateFormat.yMMMd().add_jm().format(history.timestamp),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),

                      // Batch information
                      if (history.batchNumber != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Batch: ${history.batchNumber}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Cost and markup information
                      if (history.cost != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cost: ${CurrencyUtils.formatCurrency(history.cost!)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Markup: ${history.markupPercentage?.toStringAsFixed(1) ?? '0'}%',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Reason
                      if (history.reason != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              history.reason!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
