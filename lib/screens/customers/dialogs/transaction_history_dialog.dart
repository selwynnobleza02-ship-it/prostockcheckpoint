import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/models/credit_transaction.dart';

class TransactionHistoryDialog extends StatefulWidget {
  final Customer customer;

  const TransactionHistoryDialog({super.key, required this.customer});

  @override
  State<TransactionHistoryDialog> createState() =>
      _TransactionHistoryDialogState();
}

class _TransactionHistoryDialogState extends State<TransactionHistoryDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  Future<void> _loadTransactions() async {
    try {
      ErrorLogger.logInfo(
        'Loading transactions',
        context: 'TransactionHistoryDialog._loadTransactions',
        metadata: {'customerId': widget.customer.id},
      );
      await Provider.of<CreditProvider>(
        context,
        listen: false,
      ).getTransactionsByCustomer(widget.customer.id);
      ErrorLogger.logInfo(
        'Transactions loaded successfully',
        context: 'TransactionHistoryDialog._loadTransactions',
        metadata: {'customerId': widget.customer.id},
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error loading transactions',
        error: e,
        context: 'TransactionHistoryDialog._loadTransactions',
        metadata: {'customerId': widget.customer.id},
      );
      // Fallback to local cache when offline
      try {
        final rows = await LocalDatabaseService.instance
            .getCreditTransactionsByCustomer(widget.customer.id);
        final cached = rows
            .map((m) => CreditTransaction.fromMap(m, (m['id'] ?? '') as String))
            .toList();
        if (mounted) {
          Provider.of<CreditProvider>(context, listen: false)
            ..transactions.clear()
            ..transactions.addAll(cached);
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline: showing cached history if available.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.customer.name} - Transaction History'),
      content: SizedBox(
        width: double.maxFinite,
        height:
            MediaQuery.of(context).size.height *
            0.6, // Use 60% of screen height
        child: Consumer<CreditProvider>(
          builder: (context, provider, child) {
            final transactions = provider.transactions;

            if (provider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading transactions...'),
                  ],
                ),
              );
            }

            if (provider.error != null) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${provider.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadTransactions(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (transactions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                    SizedBox(height: 16),
                    Text('No transactions found'),
                    SizedBox(height: 8),
                    Text(
                      'This customer has no credit transactions yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final isPayment = transaction.type == 'payment';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPayment ? Colors.green : Colors.orange,
                    child: Icon(
                      isPayment ? Icons.payment : Icons.credit_card,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    isPayment ? 'Payment' : 'Credit Sale',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show product details for credit sales
                      if (transaction.type == 'purchase' &&
                          transaction.items.isNotEmpty)
                        ...transaction.items.map((item) {
                          final inventoryProvider =
                              Provider.of<InventoryProvider>(
                                context,
                                listen: false,
                              );
                          final product = inventoryProvider.getProductById(
                            item.productId,
                          );
                          final productName =
                              product?.name ?? 'Unknown Product';
                          return Text(
                            '• ${item.quantity}x $productName (₱${item.unitPrice.toStringAsFixed(2)} each)',
                            style: const TextStyle(fontSize: 12),
                          );
                        })
                      else
                        Text(transaction.notes ?? 'No description'),
                      Text(
                        '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${isPayment ? '-' : '+'}${CurrencyUtils.formatCurrency(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPayment ? Colors.green : Colors.orange,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
