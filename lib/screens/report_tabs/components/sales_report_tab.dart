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
        final averageOrderValue = reportService.calculateAverageOrderValue(
          provider.sales,
        );
        final totalTransactions = provider.sales.length;

        // Calculate weekly sales
        final weekStartDate = DateTime.now().subtract(
          Duration(days: DateTime.now().weekday - 1),
        );
        final weekEndDate = weekStartDate.add(const Duration(days: 6));
        final weeklySales = provider.sales
            .where((sale) {
              return sale.createdAt.isAfter(weekStartDate) &&
                  sale.createdAt.isBefore(
                    weekEndDate.add(const Duration(days: 1)),
                  );
            })
            .fold(0.0, (sum, sale) => sum + sale.totalAmount);

        // Calculate monthly sales
        final now = DateTime.now();
        final monthStartDate = DateTime(now.year, now.month, 1);
        final monthEndDate = DateTime(now.year, now.month + 1, 0);
        final monthlySales = provider.sales
            .where((sale) {
              return sale.createdAt.isAfter(monthStartDate) &&
                  sale.createdAt.isBefore(
                    monthEndDate.add(const Duration(days: 1)),
                  );
            })
            .fold(0.0, (sum, sale) => sum + sale.totalAmount);

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced summary cards grid
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
                    'Weekly Sales',
                    CurrencyUtils.formatCurrency(weeklySales),
                    Icons.calendar_view_week,
                    Colors.blue,
                  ),
                  buildSummaryCard(
                    context,
                    'Monthly Sales',
                    CurrencyUtils.formatCurrency(monthlySales),
                    Icons.calendar_month,
                    Colors.orange,
                  ),
                  buildSummaryCard(
                    context,
                    'Total Sales',
                    CurrencyUtils.formatCurrency(totalSales),
                    Icons.receipt_long,
                    Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Additional metrics row
              Row(
                children: [
                  Expanded(
                    child: buildSummaryCard(
                      context,
                      'Total Transactions',
                      totalTransactions.toString(),
                      Icons.shopping_bag,
                      Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: buildSummaryCard(
                      context,
                      'Avg Order Value',
                      CurrencyUtils.formatCurrency(averageOrderValue),
                      Icons.trending_up,
                      Colors.teal,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sales Performance Analysis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Daily Average:')),
                        Flexible(
                          child: Text(
                            CurrencyUtils.formatCurrency(
                              totalSales /
                                  (provider.sales.isEmpty
                                      ? 1
                                      : _getUniqueDaysCount(provider.sales)),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Transactions Today:')),
                        Flexible(
                          child: Text(
                            _getTodayTransactionCount(
                              provider.sales,
                            ).toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Sales Growth:')),
                        Flexible(
                          child: Text(
                            '${_calculateGrowthPercentage(provider.sales).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _calculateGrowthPercentage(provider.sales) >=
                                      0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Recent Sales',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (provider.sales.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sales recorded yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start making sales to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.sales.take(10).length,
                  itemBuilder: (context, index) {
                    final sale = provider.sales[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.receipt,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Sale #${sale.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(sale.createdAt)}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              'Payment: ${sale.paymentMethod}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyUtils.formatCurrency(sale.totalAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              _getTimeAgo(sale.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
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

  int _getUniqueDaysCount(List<dynamic> sales) {
    if (sales.isEmpty) return 1;
    final uniqueDates = <String>{};
    for (final sale in sales) {
      final dateStr =
          '${sale.createdAt.year}-${sale.createdAt.month}-${sale.createdAt.day}';
      uniqueDates.add(dateStr);
    }
    return uniqueDates.length;
  }

  int _getTodayTransactionCount(List<dynamic> sales) {
    final today = DateTime.now();
    return sales
        .where(
          (sale) =>
              sale.createdAt.day == today.day &&
              sale.createdAt.month == today.month &&
              sale.createdAt.year == today.year,
        )
        .length;
  }

  double _calculateGrowthPercentage(List<dynamic> sales) {
    if (sales.length < 2) return 0.0;

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final todaySales = sales
        .where(
          (sale) =>
              sale.createdAt.day == now.day &&
              sale.createdAt.month == now.month &&
              sale.createdAt.year == now.year,
        )
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);

    final yesterdaySales = sales
        .where(
          (sale) =>
              sale.createdAt.day == yesterday.day &&
              sale.createdAt.month == yesterday.month &&
              sale.createdAt.year == yesterday.year,
        )
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);

    if (yesterdaySales == 0) return todaySales > 0 ? 100.0 : 0.0;

    return ((todaySales - yesterdaySales) / yesterdaySales) * 100;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
