import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/inventory_chart.dart';
import 'package:prostock/widgets/report_helpers.dart';

class InventoryReportTab extends StatelessWidget {
  const InventoryReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final totalProducts = provider.products.length;
        final lowStockCount = provider.lowStockProducts.length;
        final totalValue = provider.products.fold(
          0.0,
          (sum, product) => sum + (product.price * product.stock),
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
                    'Total Products',
                    totalProducts.toString(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                  buildSummaryCard(
                    context,
                    'Low Stock Items',
                    lowStockCount.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildSummaryCard(
                context,
                'Total Inventory Value',
                CurrencyUtils.formatCurrency(totalValue),
                Icons.inventory,
                Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Inventory Distribution',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const InventoryChart(),
              const SizedBox(height: 24),
              if (provider.lowStockProducts.isNotEmpty) ...[
                const Text(
                  'Low Stock Alert',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.lowStockProducts.length,
                  itemBuilder: (context, index) {
                    final product = provider.lowStockProducts[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.warning, color: Colors.white),
                        ),
                        title: Text(product.name),
                        subtitle: Text('Current Stock: ${product.stock}'),
                        trailing: Text(
                          'Min: ${product.minStock}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
