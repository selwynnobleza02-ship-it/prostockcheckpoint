
import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/screens/customers/dialogs/balance_management_dialog.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:prostock/screens/customers/dialogs/transaction_history_dialog.dart';

class CustomerOptionsDialog extends StatelessWidget {
  final Customer customer;

  const CustomerOptionsDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(customer.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => CustomerDetailsDialog(customer: customer),
              );
            },
            child: const Text('View Details'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => BalanceManagementDialog(customer: customer),
              );
            },
            child: const Text('Manage Balance'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => TransactionHistoryDialog(customer: customer),
              );
            },
            child: const Text('Transaction History'),
          ),
        ],
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
