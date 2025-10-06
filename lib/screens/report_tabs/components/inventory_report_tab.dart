import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/inventory_chart.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/services/pdf_report_service.dart';

class InventoryReportTab extends StatelessWidget {
  const InventoryReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final totalProducts = reportService.calculateTotalProducts(
          provider.products,
        );
        final lowStockCount = provider.lowStockProducts.length;
        final totalValue = reportService.calculateTotalInventoryValue(
          provider.products,
        );
        return FutureBuilder<double>(
          future: reportService.calculateTotalInventoryRetailValue(
            provider.products,
          ),
          builder: (context, retailSnapshot) {
            return FutureBuilder<double>(
              future: reportService.calculatePotentialInventoryProfit(
                provider.products,
              ),
              builder: (context, profitSnapshot) {
                final totalRetailValue = retailSnapshot.hasData
                    ? retailSnapshot.data!
                    : 0.0;
                final potentialProfit = profitSnapshot.hasData
                    ? profitSnapshot.data!
                    : 0.0;

                // Calculate additional metrics
                final outOfStockCount = provider.products
                    .where((p) => p.stock == 0)
                    .length;
                final averageStockValue = totalProducts > 0
                    ? totalValue / totalProducts
                    : 0.0;

                // Calculate category distribution
                final categoryCount = _getCategoryDistribution(
                  provider.products,
                );

                if (!retailSnapshot.hasData || !profitSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                            onPressed: () async {
                              final scaffold = ScaffoldMessenger.of(context);
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text('Generating PDF...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              try {
                                final pdf = PdfReportService();
                                final sections = <PdfReportSection>[
                                  PdfReportSection(
                                    title: 'Inventory Summary',
                                    rows: [
                                      [
                                        'Total Products',
                                        totalProducts.toString(),
                                      ],
                                      [
                                        'Low Stock Items',
                                        lowStockCount.toString(),
                                      ],
                                      [
                                        'Out of Stock',
                                        outOfStockCount.toString(),
                                      ],
                                      ['Categories', categoryCount.toString()],
                                      [
                                        'Cost Value',
                                        CurrencyUtils.formatCurrency(
                                          totalValue,
                                        ),
                                      ],
                                      [
                                        'Retail Value',
                                        CurrencyUtils.formatCurrency(
                                          totalRetailValue,
                                        ),
                                      ],
                                      [
                                        'Potential Profit',
                                        CurrencyUtils.formatCurrency(
                                          potentialProfit,
                                        ),
                                      ],
                                      [
                                        'Average Stock Value',
                                        CurrencyUtils.formatCurrency(
                                          averageStockValue,
                                        ),
                                      ],
                                    ],
                                  ),
                                ];

                                // Product Stock Breakdown (Product, Qty, Cost Value)
                                final productRows = <List<String>>[];
                                double productRowsTotalCost = 0.0;
                                int productRowsTotalQty = 0;
                                final sortedProducts = [...provider.products]
                                  ..sort((a, b) => a.name.compareTo(b.name));
                                for (final p in sortedProducts) {
                                  final qty = p.stock;
                                  final costValue = p.cost * qty;
                                  productRows.add([
                                    p.name,
                                    qty.toString(),
                                    CurrencyUtils.formatCurrency(costValue),
                                  ]);
                                  productRowsTotalQty += qty;
                                  productRowsTotalCost += costValue;
                                }
                                if (productRows.isNotEmpty) {
                                  productRows.add([
                                    'Total',
                                    productRowsTotalQty.toString(),
                                    CurrencyUtils.formatCurrency(
                                      productRowsTotalCost,
                                    ),
                                  ]);
                                  sections.add(
                                    PdfReportSection(
                                      title: 'Product Stock Breakdown',
                                      rows: productRows,
                                    ),
                                  );
                                }

                                // Inventory Distribution by Category (Category, Distribution %, Quantity)
                                final Map<String, int> qtyByCategory = {};
                                for (final p in provider.products) {
                                  final cat = (p.category?.isNotEmpty == true)
                                      ? p.category!
                                      : 'Uncategorized';
                                  qtyByCategory.update(
                                    cat,
                                    (v) => v + p.stock,
                                    ifAbsent: () => p.stock,
                                  );
                                }
                                final distributionRows = <List<String>>[];
                                int distTotalQty = 0;
                                final cats = qtyByCategory.keys.toList(
                                  growable: false,
                                )..sort();
                                for (final c in cats) {
                                  final q = qtyByCategory[c] ?? 0;
                                  distTotalQty += q;
                                }
                                for (final c in cats) {
                                  final q = qtyByCategory[c] ?? 0;
                                  final percentage = distTotalQty > 0
                                      ? '${(q / distTotalQty * 100).toStringAsFixed(1)}%'
                                      : '0.0%';
                                  distributionRows.add([
                                    c,
                                    percentage,
                                    q.toString(),
                                  ]);
                                }
                                if (distributionRows.isNotEmpty) {
                                  distributionRows.add([
                                    'Total',
                                    '100.0%',
                                    distTotalQty.toString(),
                                  ]);
                                  sections.add(
                                    PdfReportSection(
                                      title:
                                          'Inventory Distribution by Category',
                                      rows: distributionRows,
                                    ),
                                  );
                                }

                                // Low Stock Products (Product, Qty, Cost Value)
                                final lowRows = <List<String>>[];
                                int lowTotalQty = 0;
                                double lowTotalCost = 0.0;
                                final lowProducts = [
                                  ...provider.lowStockProducts,
                                ]..sort((a, b) => a.name.compareTo(b.name));
                                for (final p in lowProducts.where(
                                  (p) => p.stock > 0,
                                )) {
                                  final qty = p.stock;
                                  final costValue = p.cost * qty;
                                  lowRows.add([
                                    p.name,
                                    qty.toString(),
                                    CurrencyUtils.formatCurrency(costValue),
                                  ]);
                                  lowTotalQty += qty;
                                  lowTotalCost += costValue;
                                }
                                if (lowRows.isNotEmpty) {
                                  lowRows.add([
                                    'Total',
                                    lowTotalQty.toString(),
                                    CurrencyUtils.formatCurrency(lowTotalCost),
                                  ]);
                                  sections.add(
                                    PdfReportSection(
                                      title: 'Low Stock Products',
                                      rows: lowRows,
                                    ),
                                  );
                                }

                                // Out of Stock Products (Product, Qty, Cost Value)
                                final outRows = <List<String>>[];
                                int outTotalQty =
                                    0; // will be zero but keep for consistency
                                double outTotalCost =
                                    0.0; // zero as qty is zero
                                final outProducts =
                                    provider.products
                                        .where((p) => p.stock == 0)
                                        .toList()
                                      ..sort(
                                        (a, b) => a.name.compareTo(b.name),
                                      );
                                for (final p in outProducts) {
                                  outRows.add([
                                    p.name,
                                    '0',
                                    CurrencyUtils.formatCurrency(0),
                                  ]);
                                }
                                if (outRows.isNotEmpty) {
                                  outRows.add([
                                    'Total',
                                    outTotalQty.toString(),
                                    CurrencyUtils.formatCurrency(outTotalCost),
                                  ]);
                                  sections.add(
                                    PdfReportSection(
                                      title: 'Out of Stock Products',
                                      rows: outRows,
                                    ),
                                  );
                                }

                                final file = await pdf.generateFinancialReport(
                                  reportTitle:
                                      'Inventory Report - Sari-Sari Store',
                                  startDate: null,
                                  endDate: null,
                                  sections: sections,
                                );

                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text('PDF saved: ${file.path}'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error generating PDF: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Enhanced summary cards grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          buildSummaryCard(
                            context,
                            'Total Products',
                            totalProducts.toString(),
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                          buildSummaryCard(
                            context,
                            'Low Stock Items',
                            lowStockCount.toString(),
                            Icons.warning_amber,
                            Colors.orange,
                          ),
                          buildSummaryCard(
                            context,
                            'Out of Stock',
                            outOfStockCount.toString(),
                            Icons.remove_shopping_cart,
                            Colors.red,
                          ),
                          buildSummaryCard(
                            context,
                            'Categories',
                            categoryCount.toString(),
                            Icons.category,
                            Colors.purple,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Inventory value cards
                      Row(
                        children: [
                          Expanded(
                            child: buildSummaryCard(
                              context,
                              'Cost Value',
                              CurrencyUtils.formatCurrency(totalValue),
                              Icons.account_balance_wallet,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: buildSummaryCard(
                              context,
                              'Retail Value',
                              CurrencyUtils.formatCurrency(totalRetailValue),
                              Icons.storefront,
                              Colors.teal,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      buildSummaryCard(
                        context,
                        'Potential Profit',
                        CurrencyUtils.formatCurrency(potentialProfit),
                        Icons.trending_up,
                        Colors.indigo,
                      ),

                      const SizedBox(height: 24),

                      // Inventory Analysis
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inventory Analysis',
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
                                  child: Text('Average Stock Value:'),
                                ),
                                Flexible(
                                  child: Text(
                                    CurrencyUtils.formatCurrency(
                                      averageStockValue,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(child: Text('Stock Health:')),
                                Flexible(
                                  child: Text(
                                    _getStockHealth(
                                      totalProducts,
                                      lowStockCount,
                                      outOfStockCount,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getStockHealthColor(
                                        totalProducts,
                                        lowStockCount,
                                        outOfStockCount,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text('Markup Potential:'),
                                ),
                                Flexible(
                                  child: Text(
                                    '${totalValue > 0 ? ((potentialProfit / totalValue) * 100).toStringAsFixed(1) : 0.0}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
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
                        'Inventory Distribution',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const InventoryChart(),

                      const SizedBox(height: 24),

                      if (provider.lowStockProducts.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Low Stock Alert',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.lowStockProducts.length,
                          itemBuilder: (context, index) {
                            final product = provider.lowStockProducts[index];
                            final isOutOfStock = product.stock == 0;

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
                                    color: isOutOfStock
                                        ? Colors.red.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    isOutOfStock
                                        ? Icons.remove_shopping_cart
                                        : Icons.warning_amber,
                                    color: isOutOfStock
                                        ? Colors.red.shade700
                                        : Colors.orange.shade700,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  product.name,
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
                                      'Current Stock: ${product.stock}',
                                      style: TextStyle(
                                        color: isOutOfStock
                                            ? Colors.red.shade600
                                            : Colors.orange.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Min Required: ${product.minStock}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isOutOfStock
                                              ? Colors.red.shade200
                                              : Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        isOutOfStock ? 'OUT' : 'LOW',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOutOfStock
                                              ? Colors.red.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<double>(
                                      future:
                                          TaxService.calculateSellingPriceWithRule(
                                            product.cost,
                                            productId: product.id,
                                            categoryName: product.category,
                                          ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Text(
                                            CurrencyUtils.formatCurrency(
                                              snapshot.data!,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          );
                                        }
                                        return Text(
                                          'Calculating...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'All Stock Levels Good',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No low stock alerts at this time',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
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
          },
        );
      },
    );
  }

  int _getCategoryDistribution(List<dynamic> products) {
    final categories = <String>{};
    for (final product in products) {
      if (product.category?.isNotEmpty == true) {
        categories.add(product.category);
      }
    }
    return categories.length;
  }

  String _getStockHealth(int total, int lowStock, int outOfStock) {
    if (total == 0) return 'No Products';

    final healthyPercentage = ((total - lowStock - outOfStock) / total) * 100;

    if (healthyPercentage >= 80) return 'Excellent';
    if (healthyPercentage >= 60) return 'Good';
    if (healthyPercentage >= 40) return 'Fair';
    return 'Needs Attention';
  }

  Color _getStockHealthColor(int total, int lowStock, int outOfStock) {
    if (total == 0) return Colors.grey;

    final healthyPercentage = ((total - lowStock - outOfStock) / total) * 100;

    if (healthyPercentage >= 80) return Colors.green;
    if (healthyPercentage >= 60) return Colors.blue;
    if (healthyPercentage >= 40) return Colors.orange;
    return Colors.red;
  }
}
