import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';
import 'package:provider/provider.dart';

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
          if (customer.imageUrl != null)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                customer.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, size: 50);
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, size: 100, color: Colors.grey),
            ),
          const SizedBox(height: 16),
          if (customer.phone != null)
            _buildDetailRow('Phone', customer.phone!),
          if (customer.email != null)
            _buildDetailRow('Email', customer.email!),
          if (customer.address != null)
            _buildDetailRow('Address', customer.address!),
          _buildDetailRow(
            'Balance',
            CurrencyUtils.formatCurrency(customer.balance),
          ),
          _buildDetailRow(
            'Credit Limit',
            CurrencyUtils.formatCurrency(customer.creditLimit),
          ),
          _buildDetailRow(
            'Member Since',
            '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (context) => AddCustomerDialog(
                customer: customer,
                offlineManager:
                    Provider.of<CustomerProvider>(context, listen: false)
                        .offlineManager,
              ),
            );
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
