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
      Provider.of<CreditProvider>(
        context,
        listen: false,
      ).getTransactionsByCustomer(widget.customer.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.customer.name} - Transaction History'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Consumer<CreditProvider>(
          builder: (context, provider, child) {
            final transactions = provider.transactions;

            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (transactions.isEmpty) {
              return const Center(child: Text('No transactions found'));
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
