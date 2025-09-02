import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/utils/currency_utils.dart';

class BalanceManagementDialog extends StatefulWidget {
  final Customer customer;

  const BalanceManagementDialog({super.key, required this.customer});

  @override
  State<BalanceManagementDialog> createState() => _BalanceManagementDialogState();
}

class _BalanceManagementDialogState extends State<BalanceManagementDialog> {
  final _paymentController = TextEditingController();

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage Balance - ${widget.customer.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Balance:'),
                    Text(
                      CurrencyUtils.formatCurrency(widget.customer.balance),
                      style: TextStyle(
                        color: widget.customer.balance > 0
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _paymentController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Payment Amount',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
              helperText: 'Enter amount customer is paying',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(_paymentController.text);
            if (amount != null && amount > 0) {
              final creditProvider = Provider.of<CreditProvider>(
                context,
                listen: false,
              );

              final success = await creditProvider.recordPayment(
                widget.customer.id!,
                amount,
                description: 'Payment received from ${widget.customer.name}',
              );

              if (success) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Payment of ₱${amount.toStringAsFixed(2)} recorded successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to record payment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: const Text('Record Payment'),
        ),
      ],
    );
  }
}
