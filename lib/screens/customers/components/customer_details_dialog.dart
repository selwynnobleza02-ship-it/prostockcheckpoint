import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';

class CustomerDetailsDialog extends StatelessWidget {
  final Customer customer;

  const CustomerDetailsDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(customer.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phone: ${customer.phone ?? 'N/A'}'),
          Text('Email: ${customer.email ?? 'N/A'}'),
          Text('Address: ${customer.address ?? 'N/A'}'),
          const SizedBox(height: 16),
          Text('Balance: ${customer.balance.toStringAsFixed(2)}'),
          Text('Credit Limit: ${customer.creditLimit.toStringAsFixed(2)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (context) => AddCustomerDialog(customer: customer),
            );
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
