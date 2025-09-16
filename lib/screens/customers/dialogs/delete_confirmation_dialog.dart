import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final Customer customer;

  const DeleteConfirmationDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Customer'),
      content: Text(
        'Are you sure you want to delete ${customer.name}? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final provider = Provider.of<CustomerProvider>(
              context,
              listen: false,
            );
            final success = await provider.deleteCustomer(customer.id);
            if (context.mounted) {
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Customer "${customer.name}" deleted successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to delete customer. ${provider.error ?? ''}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
