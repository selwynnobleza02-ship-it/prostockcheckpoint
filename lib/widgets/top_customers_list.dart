import 'package:flutter/material.dart';
import 'package:prostock/utils/currency_utils.dart';
import '../models/customer.dart';
import '../models/sale.dart';

class TopCustomersList extends StatelessWidget {
  final List<Customer> customers;
  final List<Sale> sales;

  const TopCustomersList({
    super.key,
    required this.customers,
    required this.sales,
  });

  @override
  Widget build(BuildContext context) {
    final topCustomers = _getTopCustomers();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topCustomers.length,
        itemBuilder: (context, index) {
          final customerData = topCustomers[index];
          final customer = customerData.key;
          final totalSpent = customerData.value;

          return ListTile(
            leading: CircleAvatar(child: Text(customer.name.substring(0, 1))),
            title: Text(customer.name),
            subtitle: Text(customer.email ?? 'No email'),
            trailing: Text(
              CurrencyUtils.formatCurrency(totalSpent),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          );
        },
      ),
    );
  }

  List<MapEntry<Customer, double>> _getTopCustomers() {
    final Map<String, double> customerSpending = {};

    for (final sale in sales) {
      if (sale.customerId != null) {
        customerSpending[sale.customerId!] =
            (customerSpending[sale.customerId!] ?? 0) + sale.totalAmount;
      }
    }

    final sortedSpending = customerSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<MapEntry<Customer, double>> topCustomers = [];
    for (final entry in sortedSpending.take(5)) {
      final customer = customers.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => Customer(
          id: '',
          name: 'Unknown',
          email: '',
          phone: '',
          address: '',
          createdAt: DateTime.timestamp(),
          updatedAt: DateTime.timestamp(),
        ),
      );
      if (customer.id!.isNotEmpty) {
        topCustomers.add(MapEntry(customer, entry.value));
      }
    }

    return topCustomers;
  }
}
