import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Model imports
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/sale_item.dart';

// Provider imports
import '../providers/customer_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/refactored_sales_provider.dart';

// Widget imports
import 'sales_over_time_chart.dart';
import 'loss_over_time_chart.dart';

class AnalyticsReportWidget extends StatelessWidget {
  final List<SaleItem> saleItems;
  final List<Loss> losses;

  const AnalyticsReportWidget({
    super.key,
    required this.saleItems,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<
      RefactoredSalesProvider,
      InventoryProvider,
      CustomerProvider
    >(
      builder:
          (context, salesProvider, inventoryProvider, customerProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Over Time',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (salesProvider.sales.isEmpty)
                    const Center(child: Text('No sales data available.'))
                  else
                    SalesOverTimeChart(sales: salesProvider.sales),
                  const SizedBox(height: 24),
                  const Text(
                    'Losses Over Time',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (losses.isEmpty)
                    const Center(child: Text('No loss data available.'))
                  else
                    LossOverTimeChart(losses: losses),
                ],
              ),
            );
          },
    );
  }
}
