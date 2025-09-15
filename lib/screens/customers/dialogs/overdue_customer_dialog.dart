
import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';

class OverdueCustomerDialog extends StatelessWidget {
  final Customer customer;

  const OverdueCustomerDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Overdue Customer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer: ${customer.name}'),
          Text('Credit Balance: ${customer.balance}'),
          // Add more details here later
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Action 1: Send reminder
          },
          child: const Text('Send Reminder'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
