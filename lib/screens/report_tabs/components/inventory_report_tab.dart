import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/inventory_chart.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/services/pdf_report_service.dart';
import 'package:prostock/models/product.dart';
import 'dart:io';

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
        return FutureBuilder<Map<String, double>>(
          future: _calculateAllMetrics(provider.products),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final metrics = snapshot.data!;
            final totalRetailValue = metrics['totalRetailValue']!;
            final potentialProfit = metrics['potentialProfit']!;

            // Calculate additional metrics
            final outOfStockCount = provider.products
                .where((p) => p.stock == 0)
                .length;
            final averageStockValue = totalProducts > 0
                ? totalValue / totalProducts
                : 0.0;

            // Calculate total stock quantity
            final totalStockQuantity = provider.products.fold(
              0,
              (sum, product) => sum + product.stock,
            );

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
                          try {
                            // First, ask user which export method they prefer
                            if (!context.mounted) return;
                            final exportMethod = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Choose Export Method'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'How would you like to export your inventory report?',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.article,
                                        color: Colors.blue,
                                      ),
                                      title: const Text('Single PDF (Limited)'),
                                      subtitle: const Text(
                                        'One PDF with limited entries per section',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onTap: () =>
                                          Navigator.pop(context, 'single'),
                                    ),
                                    const Divider(),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.library_books,
                                        color: Colors.green,
                                      ),
                                      title: const Text(
                                        'Separate PDFs (Complete)',
                                      ),
                                      subtitle: const Text(
                                        'One PDF per section with ALL entries',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onTap: () =>
                                          Navigator.pop(context, 'separate'),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            );

                            if (exportMethod == null || !context.mounted)
                              return;

                            // Capture context-dependent values before async gap
                            final scaffold = ScaffoldMessenger.of(context);

                            // Validate we have data to export
                            if (provider.products.isEmpty) {
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No inventory data available to export.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }

                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text('Generating PDF...'),
                                duration: Duration(seconds: 2),
                              ),
                            );

                            final pdf = PdfReportService();
                            final sections = <PdfReportSection>[
                              PdfReportSection(
                                title: 'Inventory Summary',
                                rows: [
                                  ['Total Products', totalProducts.toString()],
                                  ['Low Stock Items', lowStockCount.toString()],
                                  ['Out of Stock', outOfStockCount.toString()],
                                  [
                                    'Total Stock',
                                    totalStockQuantity.toString(),
                                  ],
                                  [
                                    'Cost Value',
                                    CurrencyUtils.formatCurrency(totalValue),
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
                                  title: 'Inventory Distribution by Category',
                                  rows: distributionRows,
                                ),
                              );
                            }

                            // Low Stock Products (Product, Qty, Cost Value)
                            final lowRows = <List<String>>[];
                            int lowTotalQty = 0;
                            double lowTotalCost = 0.0;
                            final lowProducts = [...provider.lowStockProducts]
                              ..sort((a, b) => a.name.compareTo(b.name));
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
                            double outTotalCost = 0.0; // zero as qty is zero
                            final outProducts =
                                provider.products
                                    .where((p) => p.stock == 0)
                                    .toList()
                                  ..sort((a, b) => a.name.compareTo(b.name));
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

                            // For Separate PDFs, use original sections - system auto-splits large sections
                            List<PdfReportSection> filteredSections = sections;

                            try {
                              // Show progress dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text(
                                        exportMethod == 'separate'
                                            ? 'Generating ${sections.length} PDF files...\nPlease wait.'
                                            : 'Generating PDF...\nPlease wait.',
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              // Generate PDFs based on chosen method
                              if (exportMethod == 'separate') {
                                // Generate one PDF per section with ALL data
                                final files = await pdf.generatePdfPerSection(
                                  reportTitle:
                                      'Inventory Report - Sari-Sari Store',
                                  startDate: null,
                                  endDate: null,
                                  sections:
                                      sections, // Use original sections without limits
                                );

                                // Close progress dialog
                                if (!context.mounted) return;
                                Navigator.of(context).pop();

                                if (!context.mounted) return;
                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${files.length} PDF files saved to Downloads folder',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                return;
                              }

                              // Generate single PDF with limited data
                              final file = await pdf.generatePdfInBackground(
                                reportTitle:
                                    'Inventory Report - Sari-Sari Store',
                                startDate: null,
                                endDate: null,
                                sections: filteredSections,
                              );

                              // Close progress dialog
                              if (!context.mounted) return;
                              Navigator.of(context).pop();

                              if (!context.mounted) return;
                              scaffold.showSnackBar(
                                SnackBar(
                                  content: Text('PDF saved: ${file.path}'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } catch (e) {
                              // Close progress dialog if still showing
                              if (!context.mounted) return;
                              if (Navigator.canPop(context)) {
                                Navigator.of(context).pop();
                              }

                              // If we get TooManyPagesException, try paginated approach
                              if (e.toString().contains(
                                'TooManyPagesException',
                              )) {
                                scaffold.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Document too large, splitting into multiple PDFs...',
                                    ),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 3),
                                  ),
                                );

                                // Show progress dialog for paginated generation
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const AlertDialog(
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text(
                                          'Creating multiple PDF files...\nPlease wait.',
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                // Generate paginated PDFs in background
                                final files = await pdf
                                    .generatePaginatedPDFsInBackground(
                                      reportTitle:
                                          'Inventory Report - Sari-Sari Store',
                                      startDate: null,
                                      endDate: null,
                                      sections: filteredSections,
                                      sectionsPerPdf:
                                          3, // Fewer sections per PDF
                                    );

                                // Close progress dialog
                                if (!context.mounted) return;
                                Navigator.of(context).pop();

                                if (!context.mounted) return;

                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Generated ${files.length} PDF files in ${Directory(files.first.parent.path).path}',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } else {
                                rethrow; // Re-throw to be caught by outer catch
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error generating PDF: ${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e.toString()}',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
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
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
                        'Total Stock',
                        totalStockQuantity.toString(),
                        Icons.warehouse,
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
                  const Text(
                    'Inventory Distribution',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const InventoryChart(),

                  const SizedBox(height: 24),

                  if (provider.lowStockProducts.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Theme.of(context).colorScheme.tertiary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Low Stock Alert',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, double>>(
                      future: reportService.calculateBatchSellingPrices(
                        provider.lowStockProducts,
                      ),
                      builder: (context, priceSnapshot) {
                        if (!priceSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final lowStockPrices = priceSnapshot.data!;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.lowStockProducts.length,
                          itemBuilder: (context, index) {
                            final product = provider.lowStockProducts[index];
                            final isOutOfStock = product.stock == 0;
                            final colorScheme = Theme.of(context).colorScheme;
                            final textTheme = Theme.of(context).textTheme;

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Icon
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? colorScheme.errorContainer
                                            : colorScheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(
                                        isOutOfStock
                                            ? Icons.remove_shopping_cart
                                            : Icons.warning_amber,
                                        color: isOutOfStock
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onTertiaryContainer,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Current Stock: ${product.stock}',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: isOutOfStock
                                                      ? colorScheme.error
                                                      : colorScheme.tertiary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          Text(
                                            'Min Required: ${product.minStock}',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Badge and price
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock
                                                ? colorScheme.errorContainer
                                                : colorScheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: isOutOfStock
                                                  ? colorScheme.error
                                                  : colorScheme.tertiary,
                                            ),
                                          ),
                                          child: Text(
                                            isOutOfStock ? 'OUT' : 'LOW',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isOutOfStock
                                                      ? colorScheme
                                                            .onErrorContainer
                                                      : colorScheme
                                                            .onTertiaryContainer,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyUtils.formatCurrency(
                                            lowStockPrices[product.id] ?? 0.0,
                                          ),
                                          style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All Stock Levels Good',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No low stock alerts at this time',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
  }

  /// Calculate all metrics in a single batch operation
  Future<Map<String, double>> _calculateAllMetrics(
    List<Product> products,
  ) async {
    final reportService = ReportService();
    final prices = await reportService.calculateBatchSellingPrices(products);

    double totalRetailValue = 0.0;
    double potentialProfit = 0.0;

    for (final product in products) {
      if (product.id != null) {
        final price = prices[product.id!] ?? 0.0;
        totalRetailValue += price * product.stock;
        potentialProfit += (price - product.cost) * product.stock;
      }
    }

    return {
      'totalRetailValue': totalRetailValue,
      'potentialProfit': potentialProfit,
    };
  }
}
