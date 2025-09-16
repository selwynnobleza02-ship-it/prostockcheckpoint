import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/utils/currency_utils.dart';

class BalanceManagementDialog extends StatefulWidget {
  final Customer customer;

  const BalanceManagementDialog({super.key, required this.customer});

  @override
  State<BalanceManagementDialog> createState() =>
      _BalanceManagementDialogState();
}

class _BalanceManagementDialogState extends State<BalanceManagementDialog> {
  final _paymentController = TextEditingController();

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditProvider = Provider.of<CreditProvider>(context, listen: false);
    final bool canPay = widget.customer.balance > 0;

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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Payment Amount',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
              helperText: 'Enter amount customer is paying',
            ),
            enabled: canPay,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canPay
              ? () async {
                  final amount = double.tryParse(_paymentController.text);
                  if (amount == null || amount <= 0) {
                    _showErrorSnackBar(
                      'Payment amount must be a valid number greater than zero.',
                    );
                    return;
                  }

                  if (amount > widget.customer.balance) {
                    _showErrorSnackBar(
                      'Payment amount cannot exceed the current balance.',
                    );
                    return;
                  }

                  final success = await creditProvider.recordPayment(
                    customerId: widget.customer.id,
                    amount: amount,
                    notes: 'Payment received from ${widget.customer.name}',
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
                    _showErrorSnackBar('Failed to record payment.');
                  }
                }
              : null,
          child: const Text('Record Payment'),
        ),
      ],
    );
  }
}
