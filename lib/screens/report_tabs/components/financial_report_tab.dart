import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';

class FinancialReportTab extends StatelessWidget {
  final List<Loss> losses;
  const FinancialReportTab({super.key, required this.losses});

  @override
  Widget build(BuildContext context) {
    return Consumer3<SalesProvider, InventoryProvider, CustomerProvider>(
      builder: (context, sales, inventory, customers, child) {
        final totalRevenue = sales.sales.fold(
          0.0,
          (sum, sale) => sum + sale.totalAmount,
        );
        final totalCost = inventory.products.fold(
          0.0,
          (sum, product) => sum + (product.cost * product.stock),
        );
        final totalLoss = losses.fold(
          0.0,
          (sum, loss) => sum + loss.totalCost,
        );
        final totalProfit = totalRevenue - totalCost - totalLoss;
        final outstandingUtang = customers.customers.fold(
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
                childAspectRatio: 2.0,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  buildSummaryCard(
                    context,
                    'Total Revenue',
                    CurrencyUtils.formatCurrency(totalRevenue),
                    Icons.trending_up,
                    Colors.green,
                  ),
                  buildSummaryCard(
                    context,
                    'Total Cost',
                    CurrencyUtils.formatCurrency(totalCost),
                    Icons.trending_down,
                    Colors.red,
                  ),
                  buildSummaryCard(
                    context,
                    'Total Loss',
                    CurrencyUtils.formatCurrency(totalLoss),
                    Icons.remove_shopping_cart,
                    Colors.orange,
                  ),
                  buildSummaryCard(
                    context,
                    'Gross Profit',
                    CurrencyUtils.formatCurrency(totalProfit),
                    Icons.signal_cellular_alt,
                    totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSummaryCard(
                context,
                'Outstanding Utang',
                CurrencyUtils.formatCurrency(outstandingUtang),
                Icons.credit_card,
                Colors.red,
              ),
              const SizedBox(height: 24),
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
                      'Profit Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Profit Margin:',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            totalRevenue > 0
                                ? '${(totalProfit / totalRevenue * 100).toStringAsFixed(1)}%'
                                : '0.0%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalProfit >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Return on Investment:',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            totalCost > 0
                                ? '${(totalProfit / totalCost * 100).toStringAsFixed(1)}%'
                                : '0.0%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalProfit >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
