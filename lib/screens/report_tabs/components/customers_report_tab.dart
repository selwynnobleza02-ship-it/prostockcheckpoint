import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';

class CustomersReportTab extends StatelessWidget {
  const CustomersReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        final totalCustomers = reportService.calculateTotalCustomers(provider.customers);
        final customersWithBalance =
            reportService.calculateCustomersWithBalance(provider.customers);
        final totalBalance = reportService.calculateTotalBalance(provider.customers);

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
                    'Customers with Balance',
                    customersWithBalance.toString(),
                    Icons.credit_card_off,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSummaryCard(
                context,
                'Total Outstanding Balance',
                CurrencyUtils.formatCurrency(totalBalance),
                Icons.credit_card,
                Colors.red,
              ),
              const SizedBox(height: 24),
              if (customersWithBalance > 0) ...[
                const Text(
                  'Customers with Balance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.customers.where((c) => c.balance > 0).length,
                  itemBuilder: (context, index) {
                    final customer = provider.customers
                        .where((c) => c.balance > 0)
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
                          CurrencyUtils.formatCurrency(customer.balance),
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
                        'No Outstanding Balance',
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
