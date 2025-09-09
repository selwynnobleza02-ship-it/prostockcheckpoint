import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';

class SalesReportTab extends StatelessWidget {
  const SalesReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();

    return Consumer<SalesProvider>(
      builder: (context, provider, child) {
        final totalSales = reportService.calculateTotalSales(provider.sales);
        final todaySales = reportService.calculateTodaySales(provider.sales);

        return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      'Today\'s Sales',
                      CurrencyUtils.formatCurrency(todaySales),
                      Icons.today,
                      Colors.green,
                    ),
                    buildSummaryCard(
                      context,
                      'Total Sales',
                      CurrencyUtils.formatCurrency(totalSales),
                      Icons.receipt_long,
                      Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Sales',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (provider.sales.isEmpty)
                  const Center(child: Text('No sales recorded yet'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.sales.take(10).length,
                    itemBuilder: (context, index) {
                      final sale = provider.sales[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Text(
                              '₱',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text('Sale #${sale.id}'),
                          subtitle: Text(
                            '${sale.createdAt.day}/${sale.createdAt.month}/${sale.createdAt.year} - ${sale.paymentMethod}',
                          ),
                          trailing: Text(
                            CurrencyUtils.formatCurrency(sale.totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          onTap: () => showHistoricalReceipt(context, sale),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
      },
    );
  }
}
