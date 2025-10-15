import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/currency_utils.dart';
import '../services/tax_service.dart';
import '../models/product.dart';

class InventoryChart extends StatelessWidget {
  const InventoryChart({super.key});

  Future<Map<String, double>> _calculateCategoryData(
    List<Product> products,
  ) async {
    final categoryData = <String, double>{};
    for (final product in products) {
      final category = product.category ?? 'Uncategorized';
      final price = await TaxService.calculateSellingPriceWithRule(
        product.cost,
        productId: product.id,
        categoryName: product.category,
      );
      final value = price * product.stock;
      categoryData[category] = (categoryData[category] ?? 0) + value;
    }
    return categoryData;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        if (provider.products.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No inventory data available')),
            ),
          );
        }

        return FutureBuilder<Map<String, double>>(
          future: _calculateCategoryData(provider.products),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final categoryData = snapshot.data!;

            // Fixed number of distinct colors for better visual separation
            final colors = [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.purple,
              Colors.orange,
              Colors.teal,
              Colors.pink,
              Colors.indigo,
              Colors.amber,
              Colors.cyan,
              Colors.deepOrange,
              Colors.lime,
            ];

            // Assign a distinct color to each category
            final categoryColors = <String, Color>{};
            int colorIndex = 0;
            for (final category in categoryData.keys) {
              categoryColors[category] = colors[colorIndex % colors.length];
              colorIndex++;
            }

            final sections = categoryData.entries.map((entry) {
              final total = categoryData.values.fold(
                0.0,
                (sum, value) => sum + value,
              );
              final percentage = total > 0 ? (entry.value / total * 100) : 0;

              return PieChartSectionData(
                color: categoryColors[entry.key]!,
                value: entry.value,
                title: '${percentage.toStringAsFixed(1)}%',
                radius: 55, // Reduced radius to avoid overflow
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Value by Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8), // Reduced spacing
                    // Container with fixed height to prevent overflow
                    SizedBox(
                      height: 250, // Adjusted height
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sections: sections,
                                centerSpaceRadius: 35, // Reduced center space
                                sectionsSpace:
                                    1, // Smaller space between sections
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 250, // Match container height
                              child: ListView(
                                shrinkWrap: true,
                                children: categoryData.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: categoryColors[entry.key],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.key,
                                                style: const TextStyle(
                                                  fontSize:
                                                      10, // Reduced font size
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                CurrencyUtils.formatCurrency(
                                                  entry.value,
                                                ),
                                                style: const TextStyle(
                                                  fontSize:
                                                      9, // Reduced font size
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
