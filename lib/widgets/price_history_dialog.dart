import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prostock/models/price_history.dart';
import 'package:prostock/services/firestore/product_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:provider/provider.dart';

class PriceHistoryDialog extends StatefulWidget {
  final String productId;

  const PriceHistoryDialog({super.key, required this.productId});

  @override
  PriceHistoryDialogState createState() => PriceHistoryDialogState();
}

class PriceHistoryDialogState extends State<PriceHistoryDialog> {
  late Future<List<PriceHistory>> _priceHistoryFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
  }

  Future<void> _loadPriceHistory() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final isOnline = inventoryProvider.isOnline;

      ErrorLogger.logInfo(
        'Loading price history for product ${widget.productId} (${isOnline ? "ONLINE" : "OFFLINE"})',
        context: 'PriceHistoryDialog._loadPriceHistory',
      );

      final productService = ProductService(FirebaseFirestore.instance);
      // Force online fetch if connected, otherwise use local database
      _priceHistoryFuture = productService.getPriceHistory(
        widget.productId,
        forceOnline: isOnline,
      );

      // Wait for the future to complete to update refresh state
      final history = await _priceHistoryFuture;

      ErrorLogger.logInfo(
        'Loaded ${history.length} price history entries for product ${widget.productId} from ${isOnline ? "Firestore" : "local database"}',
        context: 'PriceHistoryDialog._loadPriceHistory',
      );

      if (history.isNotEmpty) {
        ErrorLogger.logInfo(
          'Latest price: ${CurrencyUtils.formatCurrency(history.first.price)} at ${history.first.timestamp}',
          context: 'PriceHistoryDialog._loadPriceHistory',
        );
      }

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error loading price history',
        error: e,
        context: 'PriceHistoryDialog._loadPriceHistory',
      );

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing: ${e.toString()}')),
        );
      }
    }
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
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: true,
    );
    final isOnline = inventoryProvider.isOnline;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Price History', style: TextStyle(fontSize: 20)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isRefreshing ? null : _loadPriceHistory,
                    tooltip: 'Refresh',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Connection status indicator below title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOnline
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      content: FutureBuilder<List<PriceHistory>>(
        future: _priceHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading price history',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, color: Colors.grey, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'No price history found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Price changes will appear here',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final priceHistory = snapshot.data!;

          return SizedBox(
            width: double.maxFinite,
            height: 400, // Fixed height to prevent overflow
            child: Column(
              children: [
                // Summary header
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${priceHistory.length} price ${priceHistory.length == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        'Latest: ${CurrencyUtils.formatCurrency(priceHistory.first.price)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: priceHistory.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
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
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.blue.shade50.withOpacity(0.3)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price with change indicator
                            Row(
                              children: [
                                if (index == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                Text(
                                  CurrencyUtils.formatCurrency(history.price),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _getPriceChangeText(
                                      history,
                                      previousHistory,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _getPriceChangeColor(
                                        history,
                                        previousHistory,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Timestamp
                            Text(
                              DateFormat.yMMMd().add_jm().format(
                                history.timestamp,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
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
                                  Expanded(
                                    child: Text(
                                      history.reason!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic,
                                      ),
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
                ),
              ],
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
