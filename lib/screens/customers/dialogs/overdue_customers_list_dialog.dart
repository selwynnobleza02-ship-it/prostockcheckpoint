
import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/screens/customers/dialogs/overdue_customer_dialog.dart';

class OverdueCustomersListDialog extends StatelessWidget {
  final List<Customer> overdueCustomers;

  const OverdueCustomersListDialog({super.key, required this.overdueCustomers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Overdue Customers'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: overdueCustomers.length,
          itemBuilder: (context, index) {
            final customer = overdueCustomers[index];
            return ListTile(
              title: Text(customer.name),
              subtitle: Text('Credit Balance: ${customer.balance}'),
              onTap: () {
                Navigator.of(context).pop(); // Close this dialog
                showDialog(
                  context: context,
                  builder: (context) => OverdueCustomerDialog(customer: customer),
                );
              },
            );
          },
        ),
      ),
      actions: [
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
