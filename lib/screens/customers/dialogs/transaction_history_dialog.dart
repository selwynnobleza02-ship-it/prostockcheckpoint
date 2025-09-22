import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/utils/currency_utils.dart';

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
      print('Loading transactions for customer: ${widget.customer.id}');
      await Provider.of<CreditProvider>(
        context,
        listen: false,
      ).getTransactionsByCustomer(widget.customer.id);
      print('Transactions loaded successfully');
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
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
