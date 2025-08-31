import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:prostock/screens/customers/dialogs/delete_confirmation_dialog.dart';
import 'package:prostock/screens/customers/dialogs/transaction_history_dialog.dart';
import 'package:prostock/screens/customers/dialogs/utang_management_dialog.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';

class CustomerListItem extends StatelessWidget {
  final Customer customer;

  const CustomerListItem({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: customer.hasUtang ? Colors.orange : Colors.green,
          child: Text(
            customer.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(customer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null) Text('Phone: ${customer.phone}'),
            if (customer.email != null) Text('Email: ${customer.email}'),
            Text(
              'Utang: ${CurrencyUtils.formatCurrency(customer.utangBalance)}',
              style: TextStyle(
                color: customer.hasUtang ? Colors.orange : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Text('View Details'),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'utang',
              child: Text('Manage Utang'),
            ),
            const PopupMenuItem(
              value: 'history',
              child: Text('Transaction History'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'view':
                showDialog(
                  context: context,
                  builder: (context) => CustomerDetailsDialog(customer: customer),
                );
                break;
              case 'edit':
                showDialog(
                  context: context,
                  builder: (context) => AddCustomerDialog(
                    customer: customer,
                  ),
                );
                break;
              case 'utang':
                showDialog(
                  context: context,
                  builder: (context) => UtangManagementDialog(customer: customer),
                );
                break;
              case 'history':
                showDialog(
                  context: context,
                  builder: (context) => TransactionHistoryDialog(customer: customer),
                );
                break;
              case 'delete':
                showDialog(
                  context: context,
                  builder: (context) => DeleteConfirmationDialog(customer: customer),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}
