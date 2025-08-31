import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';

class CustomersReportTab extends StatelessWidget {
  const CustomersReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        final totalCustomers = provider.customers.length;
        final customersWithUtang = provider.customers
            .where((c) => c.hasUtang)
            .length;
        final totalUtang = provider.customers.fold(
          0.0,
          (sum, c) => sum + c.utangBalance,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  buildSummaryCard(
                    context,
                    'Total Customers',
                    totalCustomers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  buildSummaryCard(
                    context,
                    'Customers with Utang',
                    customersWithUtang.toString(),
                    Icons.credit_card_off,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSummaryCard(
                context,
                'Total Outstanding Utang',
                CurrencyUtils.formatCurrency(totalUtang),
                Icons.credit_card,
                Colors.red,
              ),
              const SizedBox(height: 24),
              if (customersWithUtang > 0) ...[
                const Text(
                  'Customers with Utang',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.customers.where((c) => c.hasUtang).length,
                  itemBuilder: (context, index) {
                    final customer = provider.customers
                        .where((c) => c.hasUtang)
                        .toList()[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(customer.name),
                        subtitle: Text('Phone: ${customer.phone ?? 'N/A'}'),
                        trailing: Text(
                          CurrencyUtils.formatCurrency(customer.utangBalance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No Outstanding Utang',
                        style: TextStyle(fontSize: 18, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
