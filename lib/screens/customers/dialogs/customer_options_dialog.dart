import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/screens/customers/dialogs/cash_utang_dialog.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:prostock/screens/customers/dialogs/transaction_history_dialog.dart';
import 'package:prostock/screens/pos/pos_screen.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';

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
            child: const Text('Product Utang'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => CashUtangDialog(customer: customer),
              );
            },
            child: const Text('Cash Utang'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => AddCustomerDialog(
                  customer: customer,
                  offlineManager: Provider.of<CustomerProvider>(
                    context,
                    listen: false,
                  ).offlineManager,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Edit Customer'),
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
