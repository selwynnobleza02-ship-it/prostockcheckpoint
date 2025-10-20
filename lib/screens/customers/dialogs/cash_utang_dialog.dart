import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/confirmation_dialog.dart';

class CashUtangDialog extends StatefulWidget {
  final Customer customer;

  const CashUtangDialog({super.key, required this.customer});

  @override
  State<CashUtangDialog> createState() => _CashUtangDialogState();
}

class _CashUtangDialogState extends State<CashUtangDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_validateAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateAmount() {
    if (_amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text);
      if (amount != null) {
        final newBalance = widget.customer.balance + amount;

        setState(() {
          if (amount <= 0) {
            _error = 'Amount must be greater than zero';
          } else if (newBalance > widget.customer.creditLimit &&
              widget.customer.creditLimit > 0) {
            _error =
                'Total balance would exceed credit limit of ${widget.customer.creditLimit}';
          } else {
            _error = null;
          }
        });
      }
    } else {
      setState(() {
        _error = null;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _recordCashLoan() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    // Get notes or use default
    final notes = _notesController.text.isNotEmpty
        ? _notesController.text
        : 'Cash loan to ${widget.customer.name}';

    // Show confirmation dialog
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Confirm Cash Loan',
      content:
          'Are you sure you want to loan ₱${amount.toStringAsFixed(2)} to ${widget.customer.name}?\n\n'
          'Current Balance: ${CurrencyUtils.formatCurrency(widget.customer.balance)}\n'
          'New Balance: ${CurrencyUtils.formatCurrency(widget.customer.balance + amount)}',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final creditProvider = Provider.of<CreditProvider>(
        context,
        listen: false,
      );
      final success = await creditProvider.recordCashLoan(
        context: context,
        customerId: widget.customer.id,
        amount: amount,
        notes: notes,
      );

      if (success) {
        if (mounted) {
          // Close dialog immediately after successful loan
          Navigator.pop(context);
          // Show success message after dialog is closed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cash loan of ₱${amount.toStringAsFixed(2)} recorded successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show the specific error message from CreditProvider
        final errorMessage =
            creditProvider.error ?? 'Failed to record cash loan.';
        _showErrorSnackBar(errorMessage);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.attach_money, color: Colors.green[600], size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Cash Utang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customer.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Balance: ${CurrencyUtils.formatCurrency(widget.customer.balance)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.customer.balance > 0
                          ? Colors.red[600]
                          : Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.customer.creditLimit > 0)
                    Text(
                      'Credit Limit: ${CurrencyUtils.formatCurrency(widget.customer.creditLimit)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Amount Input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Cash Loan Amount',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Notes Input
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Purpose/Notes',
                border: OutlineInputBorder(),
                hintText: 'Reason for cash loan...',
              ),
              maxLines: 2,
            ),

            // Error Display
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview
            if (_amountController.text.isNotEmpty && _error == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New Balance: ${CurrencyUtils.formatCurrency(_getNewBalance())}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading || _error != null ? null : _recordCashLoan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Record Cash Loan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  double _getNewBalance() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return widget.customer.balance + amount;
  }
}
