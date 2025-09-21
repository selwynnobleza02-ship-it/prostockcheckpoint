import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prostock/models/customer.dart';

class ManageBalanceDialog extends StatefulWidget {
  final Customer customer;
  final Function(String customerId, double amount) onUpdateBalance;

  const ManageBalanceDialog({
    super.key,
    required this.customer,
    required this.onUpdateBalance,
  });

  @override
  State<ManageBalanceDialog> createState() => _ManageBalanceDialogState();
}

class _ManageBalanceDialogState extends State<ManageBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  BalanceOperation _selectedOperation = BalanceOperation.add;

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
        final newBalance = _selectedOperation == BalanceOperation.add
            ? widget.customer.balance + amount
            : widget.customer.balance - amount;

        setState(() {
          if (newBalance < 0) {
            _error = 'Balance cannot be negative';
          } else if (newBalance > widget.customer.creditLimit &&
              widget.customer.creditLimit > 0) {
            _error =
                'Balance exceeds credit limit of ${widget.customer.creditLimit}';
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

  void _onOperationChanged(BalanceOperation operation) {
    setState(() {
      _selectedOperation = operation;
    });
    _validateAmount();
  }

  Future<void> _submitBalanceUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final actualAmount = _selectedOperation == BalanceOperation.add
        ? amount
        : -amount;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onUpdateBalance(widget.customer.id, actualAmount);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Balance ${_selectedOperation == BalanceOperation.add ? 'added' : 'deducted'} successfully',
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.blue[600], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Manage Balance',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    'Current Balance: ₱${widget.customer.balance.toStringAsFixed(2)}',
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
                      'Credit Limit: ₱${widget.customer.creditLimit.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Operation Type
            Text(
              'Operation Type',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<BalanceOperation>(
              segments: const [
                ButtonSegment<BalanceOperation>(
                  value: BalanceOperation.add,
                  label: Text('Add'),
                  icon: Icon(Icons.add),
                ),
                ButtonSegment<BalanceOperation>(
                  value: BalanceOperation.deduct,
                  label: Text('Deduct'),
                  icon: Icon(Icons.remove),
                ),
              ],
              selected: {_selectedOperation},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  _onOperationChanged(selection.first);
                }
              },
            ),

            const SizedBox(height: 16),

            // Amount Input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₱',
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
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Reason for balance change...',
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
                        'New Balance: ₱${_getNewBalance().toStringAsFixed(2)}',
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
          onPressed: _isLoading || _error != null ? null : _submitBalanceUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
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
              : Text(
                  _selectedOperation == BalanceOperation.add ? 'Add' : 'Deduct',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  double _getNewBalance() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return _selectedOperation == BalanceOperation.add
        ? widget.customer.balance + amount
        : widget.customer.balance - amount;
  }
}

enum BalanceOperation { add, deduct }
