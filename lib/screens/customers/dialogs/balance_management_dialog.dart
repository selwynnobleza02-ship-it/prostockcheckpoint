import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/confirmation_dialog.dart';

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

                  final confirmed = await showConfirmationDialog(
                    context: context,
                    title: 'Confirm Record Payment',
                    content:
                        'Are you sure you want to record a payment of ₱${amount.toStringAsFixed(2)} for ${widget.customer.name}?\n\nCurrent Balance: ${CurrencyUtils.formatCurrency(widget.customer.balance)}\nNew Balance: ${CurrencyUtils.formatCurrency(widget.customer.balance - amount)}',
                    confirmText: 'Confirm',
                    cancelText: 'Cancel',
                  );
                  if (confirmed != true) {
                    return;
                  }

                  if (!context.mounted) return;

                  final success = await creditProvider.recordPayment(
                    context: context,
                    customerId: widget.customer.id,
                    amount: amount,
                    notes: 'Payment received from ${widget.customer.name}',
                  );

                  if (success) {
                    if (context.mounted) {
                      // Close dialog immediately after successful payment
                      Navigator.pop(context);
                      // Show success message after dialog is closed
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
                    // Show the specific error message from CreditProvider
                    final errorMessage =
                        creditProvider.error ?? 'Failed to record payment.';
                    _showErrorSnackBar(errorMessage);
                  }
                }
              : null,
          child: const Text('Record Payment'),
        ),
      ],
    );
  }
}
