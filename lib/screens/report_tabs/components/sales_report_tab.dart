import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/services/pdf_report_service.dart';
import 'dart:io';

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

        // Calculate weekly sales (normalize to start of day, inclusive start)
        final nowTs = DateTime.now();
        final todayStart = DateTime(nowTs.year, nowTs.month, nowTs.day);
        final weekStartDate = todayStart.subtract(
          Duration(days: todayStart.weekday - 1), // Monday 00:00
        );
        final weekEndDateExclusive = weekStartDate.add(
          const Duration(days: 7),
        ); // next Monday 00:00
        final weeklySales = provider.sales
            .where((sale) {
              final ts = sale.createdAt;
              return (ts.isAtSameMomentAs(weekStartDate) ||
                      ts.isAfter(weekStartDate)) &&
                  ts.isBefore(weekEndDateExclusive);
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
                                  'How would you like to export your sales report?',
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
                                  onTap: () => Navigator.pop(context, 'single'),
                                ),
                                const Divider(),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.library_books,
                                    color: Colors.green,
                                  ),
                                  title: const Text('Separate PDFs (Complete)'),
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

                        if (exportMethod == null || !context.mounted) return;

                        final scaffold = ScaffoldMessenger.of(context);

                        // Validate we have data to export
                        if (provider.sales.isEmpty) {
                          scaffold.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No sales data available to export.',
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        if (provider.saleItems.isEmpty) {
                          scaffold.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No sale items available to export.',
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        // Show loading indicator
                        scaffold.showSnackBar(
                          const SnackBar(
                            content: Text('Generating PDF...'),
                            duration: Duration(seconds: 2),
                          ),
                        );

                        final pdf = PdfReportService();

                        // Build breakdowns per period with product name and quantity
                        final inventory = context.read<InventoryProvider>();
                        final productById = {
                          for (final p in inventory.products) p.id: p,
                        };

                        List<PdfReportSection> buildBreakdownSections() {
                          // Helper to group sale items by product and unit price for a set of saleIds
                          List<List<String>> buildRowsForSaleIds(
                            Set<String> saleIds,
                          ) {
                            // Group by product and unit price to track price changes
                            final Map<String, Map<double, double>>
                            qtyByProductPrice = {};
                            final Map<String, Map<double, double>>
                            revenueByProductPrice = {};

                            for (final item in provider.saleItems) {
                              if (saleIds.contains(item.saleId)) {
                                // Round unit price to 2 decimals to avoid floating noise
                                final roundedUnitPrice =
                                    (item.unitPrice * 100).round() / 100.0;

                                qtyByProductPrice[item.productId] ??= {};
                                qtyByProductPrice[item
                                        .productId]![roundedUnitPrice] =
                                    (qtyByProductPrice[item
                                            .productId]![roundedUnitPrice] ??
                                        0) +
                                    item.quantity;

                                revenueByProductPrice[item.productId] ??= {};
                                revenueByProductPrice[item
                                        .productId]![roundedUnitPrice] =
                                    (revenueByProductPrice[item
                                            .productId]![roundedUnitPrice] ??
                                        0) +
                                    item.totalPrice;
                              }
                            }

                            final rows = <List<String>>[];
                            double totalQty = 0;
                            double totalAmt = 0;

                            // Sort products by name
                            final productIds =
                                qtyByProductPrice.keys.toList(growable: false)
                                  ..sort(
                                    (a, b) => (productById[a]?.name ?? a)
                                        .compareTo(productById[b]?.name ?? b),
                                  );

                            for (final productId in productIds) {
                              final name =
                                  productById[productId]?.name ??
                                  'Unknown Product';
                              final priceMap =
                                  qtyByProductPrice[productId] ?? {};
                              final pricesSorted = priceMap.keys.toList(
                                growable: false,
                              )..sort();

                              for (final price in pricesSorted) {
                                final qty = priceMap[price] ?? 0;
                                final revenue =
                                    (revenueByProductPrice[productId] ??
                                        {})[price] ??
                                    0.0;

                                rows.add([
                                  name,
                                  qty.toStringAsFixed(0),
                                  CurrencyUtils.formatCurrency(price),
                                  CurrencyUtils.formatCurrency(revenue),
                                ]);
                                totalQty += qty;
                                totalAmt += revenue;
                              }
                            }

                            if (rows.isNotEmpty) {
                              rows.add([
                                'Total',
                                totalQty.toStringAsFixed(0),
                                '-',
                                CurrencyUtils.formatCurrency(totalAmt),
                              ]);
                            }
                            return rows;
                          }

                          // Helper to get saleIds for a period
                          Set<String> saleIdsWhere(
                            bool Function(DateTime ts) predicate,
                          ) {
                            return provider.sales
                                .where((s) => predicate(s.createdAt))
                                .map((s) => s.id)
                                .whereType<String>()
                                .toSet();
                          }

                          final now = DateTime.now();
                          final todayStart = DateTime(
                            now.year,
                            now.month,
                            now.day,
                          );

                          final weekStart = todayStart.subtract(
                            Duration(days: todayStart.weekday - 1),
                          );
                          final nextWeekStart = weekStart.add(
                            const Duration(days: 7),
                          );

                          final monthStart = DateTime(now.year, now.month, 1);
                          final nextMonthStart = DateTime(
                            now.year,
                            now.month + 1,
                            1,
                          );

                          // Removed todaySaleIds as we're only showing Weekly, Monthly, and Total breakdowns
                          final weekSaleIds = saleIdsWhere(
                            (ts) =>
                                (ts.isAtSameMomentAs(weekStart) ||
                                    ts.isAfter(weekStart)) &&
                                ts.isBefore(nextWeekStart),
                          );
                          final monthSaleIds = saleIdsWhere(
                            (ts) =>
                                (ts.isAtSameMomentAs(monthStart) ||
                                    ts.isAfter(monthStart)) &&
                                ts.isBefore(nextMonthStart),
                          );
                          final totalSaleIds = provider.sales
                              .map((s) => s.id)
                              .whereType<String>()
                              .toSet();

                          final sections = <PdfReportSection>[
                            PdfReportSection(
                              title: 'Sales Summary',
                              rows: [
                                [
                                  "Today's Sales",
                                  CurrencyUtils.formatCurrency(todaySales),
                                ],
                                [
                                  'Weekly Sales',
                                  CurrencyUtils.formatCurrency(weeklySales),
                                ],
                                [
                                  'Monthly Sales',
                                  CurrencyUtils.formatCurrency(monthlySales),
                                ],
                                [
                                  'Total Sales',
                                  CurrencyUtils.formatCurrency(totalSales),
                                ],
                                [
                                  'Total Transactions',
                                  totalTransactions.toString(),
                                ],
                                [
                                  'Average Order Value',
                                  CurrencyUtils.formatCurrency(
                                    averageOrderValue,
                                  ),
                                ],
                              ],
                            ),
                          ];

                          // Only include Weekly, Monthly, and Total Sales breakdowns
                          // Removed Today's Sales breakdown as per requirement

                          final weekRows = buildRowsForSaleIds(weekSaleIds);
                          if (weekRows.isNotEmpty) {
                            sections.add(
                              PdfReportSection(
                                title: 'Weekly Sales Breakdown',
                                rows: weekRows,
                              ),
                            );
                          }

                          final monthRows = buildRowsForSaleIds(monthSaleIds);
                          if (monthRows.isNotEmpty) {
                            sections.add(
                              PdfReportSection(
                                title: 'Monthly Sales Breakdown',
                                rows: monthRows,
                              ),
                            );
                          }

                          final totalRows = buildRowsForSaleIds(totalSaleIds);
                          if (totalRows.isNotEmpty) {
                            sections.add(
                              PdfReportSection(
                                title: 'Total Sales Breakdown',
                                rows: totalRows,
                              ),
                            );
                          }

                          return sections;
                        }

                        final sections = buildBreakdownSections();

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
                              reportTitle: 'Sales Report - Sari-Sari Store',
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
                            reportTitle: 'Sales Report - Sari-Sari Store',
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
                          if (e.toString().contains('TooManyPagesException')) {
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
                                  reportTitle: 'Sales Report - Sari-Sari Store',
                                  startDate: null,
                                  endDate: null,
                                  sections: filteredSections,
                                  sectionsPerPdf: 3, // Fewer sections per PDF
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
              const SizedBox(height: 24),

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
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sales recorded yet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start making sales to see them here',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    final colorScheme = Theme.of(context).colorScheme;
                    final textTheme = Theme.of(context).textTheme;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => showHistoricalReceipt(context, sale),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  Icons.receipt,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sale #${sale.id}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(sale.createdAt),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      'Payment: ${sale.paymentMethod}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Amount and time
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyUtils.formatCurrency(
                                      sale.totalAmount,
                                    ),
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getTimeAgo(sale.createdAt),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
