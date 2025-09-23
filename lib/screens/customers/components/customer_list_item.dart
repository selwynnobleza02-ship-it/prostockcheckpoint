import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/screens/customers/dialogs/balance_management_dialog.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:prostock/screens/customers/dialogs/transaction_history_dialog.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';
import 'package:provider/provider.dart';
import 'package:prostock/screens/pos/pos_screen.dart';

class CustomerListItem extends StatelessWidget {
  final Customer customer;

  const CustomerListItem({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(
      context,
      listen: false,
    );
    final isOverdue = customerProvider.overdueCustomers.any(
      (c) => c.id == customer.id,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue
              ? Colors.red
              : (customer.balance > 0 ? Colors.orange : Colors.green),
          child: Text(
            customer.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(customer.name),
            if (isOverdue)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.warning, color: Colors.red, size: 16),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null) Text('Phone: ${customer.phone}'),
            if (customer.email != null) Text('Email: ${customer.email}'),
            Text(
              'Balance: ${CurrencyUtils.formatCurrency(customer.balance)}',
              style: TextStyle(
                color: isOverdue
                    ? Colors.red
                    : (customer.balance > 0 ? Colors.orange : Colors.green),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'utang', child: Text('Manage Balance')),
            const PopupMenuItem(
              value: 'history',
              child: Text('Transaction History'),
            ),
            // Replaced Delete with Utang (POS Credit)
            const PopupMenuItem(value: 'utang_pos', child: Text('Utang')),
          ],
          onSelected: (value) async {
            // Check context.mounted before any async operations that use context
            if (!context.mounted) return;

            switch (value) {
              case 'view':
                showDialog(
                  context: context,
                  builder: (context) =>
                      CustomerDetailsDialog(customer: customer),
                );
                break;
              case 'edit':
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
                break;
              case 'utang':
                showDialog(
                  context: context,
                  builder: (context) =>
                      BalanceManagementDialog(customer: customer),
                );
                break;
              case 'history':
                showDialog(
                  context: context,
                  builder: (context) =>
                      TransactionHistoryDialog(customer: customer),
                );
                break;
              case 'utang_pos':
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        POSScreen(customer: customer, paymentMethod: 'credit'),
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}
