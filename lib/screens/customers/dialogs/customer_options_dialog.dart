import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:prostock/screens/customers/dialogs/transaction_history_dialog.dart';
import 'package:prostock/screens/pos/pos_screen.dart';

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
              Provider.of<CustomerProvider>(
                context,
                listen: false,
              ).showManageBalanceDialog(context, customer.id);
            },
            child: const Text('Manage Balance'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) =>
                    TransactionHistoryDialog(customer: customer),
              );
            },
            child: const Text('Transaction History'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      POSScreen(customer: customer, paymentMethod: 'credit'),
                ),
              );
            },
            child: const Text('Utang'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final customerProvider = Provider.of<CustomerProvider>(
                context,
                listen: false,
              );
              final success = await customerProvider
                  .deleteCustomerWithConfirmation(context, customer.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Customer'),
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
