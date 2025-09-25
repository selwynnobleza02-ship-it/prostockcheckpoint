import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/providers/stock_movement_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/utils/constants.dart';

import 'package:prostock/widgets/loss_breakdown_list.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:prostock/widgets/top_selling_products_list.dart';
import 'package:prostock/services/pdf_report_service.dart';

class FinancialReportTab extends StatefulWidget {
  final List<Loss> losses;
  const FinancialReportTab({super.key, required this.losses});

  @override
  State<FinancialReportTab> createState() => _FinancialReportTabState();
}

class _FinancialReportTabState extends State<FinancialReportTab> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final stockMovementProvider = Provider.of<StockMovementProvider>(
        context,
        listen: false,
      );
      salesProvider.loadSales();
      stockMovementProvider.loadAllMovements();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      end: _endDate ?? DateTime.now(),
    );
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (!mounted) return;

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });

      if (!context.mounted) return;
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final stockMovementProvider = Provider.of<StockMovementProvider>(
        context,
        listen: false,
      );

      salesProvider.loadSales(
        startDate: _startDate,
        endDate: _endDate,
        refresh: true,
      );
      stockMovementProvider.loadAllMovements(
        startDate: _startDate,
        endDate: _endDate,
      );
    }
  }

  String _getProductCategory(String productId) {
    try {
      final product = Provider.of<InventoryProvider>(context, listen: false)
          .products
          .firstWhere(
            (p) => p.id == productId,
            orElse: () => throw Exception('Product not found: $productId'),
          );

      // Use the actual category from the product, fallback to 'Others (Iba pa)' if null
      return product.category ?? 'Others (Iba pa)';
    } catch (e) {
      ErrorLogger.logError(
        'Error categorizing product',
        error: e,
        context: 'FinancialReportTab._getProductCategory',
        metadata: {'productId': productId},
      );
      return 'Others (Iba pa)'; // Default fallback
    }
  }

  Map<String, double> _calculateCategoryRevenue(List<SaleItem> saleItems) {
    final Map<String, double> categoryRevenue = {};

    for (final item in saleItems) {
      try {
        final category = _getProductCategory(item.productId);
        categoryRevenue[category] =
            (categoryRevenue[category] ?? 0) + item.totalPrice;
      } catch (e) {
        ErrorLogger.logError(
          'Error calculating category revenue for product',
          error: e,
          context: 'FinancialReportTab._calculateCategoryRevenue',
          metadata: {'productId': item.productId},
        );
        // Add to "Unknown Products" category
        categoryRevenue['Unknown Products'] =
            (categoryRevenue['Unknown Products'] ?? 0) + item.totalPrice;
      }
    }

    return categoryRevenue;
  }

  Map<String, double> _calculateCategoryCost(
    List<SaleItem> saleItems,
    List<Product> products,
  ) {
    final Map<String, double> categoryCost = {};
    final productMap = {for (var p in products) p.id: p};

    for (final item in saleItems) {
      try {
        final category = _getProductCategory(item.productId);
        final product = productMap[item.productId];

        if (product != null) {
          // Use actual product cost instead of assumed percentages
          final itemCost = product.cost * item.quantity;
          categoryCost[category] = (categoryCost[category] ?? 0) + itemCost;
        } else {
          ErrorLogger.logInfo(
            'Product not found for sale item, using estimated cost',
            context: 'FinancialReportTab._calculateCategoryCost',
            metadata: {'productId': item.productId},
          );
          // Add to "Unknown Products" category with estimated cost
          final estimatedCost = item.totalPrice * 0.6; // Assume 60% cost ratio
          categoryCost['Unknown Products'] =
              (categoryCost['Unknown Products'] ?? 0) + estimatedCost;
        }
      } catch (e) {
        ErrorLogger.logError(
          'Error calculating category cost for product',
          error: e,
          context: 'FinancialReportTab._calculateCategoryCost',
          metadata: {'productId': item.productId},
        );
        // Add to "Unknown Products" category with estimated cost
        final estimatedCost = item.totalPrice * 0.6; // Assume 60% cost ratio
        categoryCost['Unknown Products'] =
            (categoryCost['Unknown Products'] ?? 0) + estimatedCost;
      }
    }

    return categoryCost;
  }

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();
    return Consumer4<
      SalesProvider,
      InventoryProvider,
      CustomerProvider,
      StockMovementProvider
    >(
      builder: (context, sales, inventory, customers, stockMovements, child) {
        if (sales.isLoading || stockMovements.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredSales = _filterSalesByDate(sales.sales);
        final filteredSaleItems = _filterSaleItemsBySales(
          sales.saleItems,
          filteredSales,
        );
        final filteredLosses = _filterLossesByDate(widget.losses);

        if (filteredSales.isEmpty) {
          return const Center(
            child: Text('No data available for the selected period.'),
          );
        }

        final totalRevenue = reportService.calculateTotalRevenue(filteredSales);
        final totalCost = reportService.calculateTotalCost(
          filteredSaleItems,
          inventory.products,
        );
        final totalLoss = reportService.calculateTotalLoss(filteredLosses);
        final totalProfit = reportService.calculateGrossProfit(
          totalRevenue,
          totalCost,
          totalLoss,
        );
        final outstandingUtang = reportService.calculateTotalBalance(
          customers.customers,
        );

        final profitMargin = reportService.calculateProfitMargin(
          totalProfit,
          totalRevenue,
        );

        final roi = reportService.calculateRoi(totalProfit, totalCost);

        // NEW CALCULATIONS
        final averageOrderValue = reportService.calculateAverageOrderValue(
          filteredSales,
        );
        final markupPercentage = reportService.calculateMarkupPercentage(
          totalRevenue,
          totalCost,
        );

        // Corrected Inventory Turnover Calculation
        final endingInventoryValue = reportService.calculateTotalInventoryValue(
          inventory.products,
        );
        final beginningInventoryValue = reportService
            .calculateBeginningInventoryValue(
              inventory.products,
              stockMovements.allMovements,
            );
        final averageInventoryValue =
            (beginningInventoryValue + endingInventoryValue) / 2;

        final inventoryTurnover = reportService.calculateInventoryTurnover(
          totalCost,
          averageInventoryValue,
        );
        final potentialProfit = reportService.calculatePotentialInventoryProfit(
          inventory.products,
        );

        final topProducts = reportService.getTopSellingProductsByRevenue(
          filteredSaleItems,
          inventory.products,
        );

        final lossBreakdown = reportService.getLossBreakdown(filteredLosses);

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
                        final scaffold = ScaffoldMessenger.of(context);

                        // Show loading indicator
                        scaffold.showSnackBar(
                          const SnackBar(
                            content: Text('Generating PDF...'),
                            duration: Duration(seconds: 2),
                          ),
                        );

                        final pdf = PdfReportService();

                        // Calculate category revenue and cost using actual data
                        final categoryRevenue = _calculateCategoryRevenue(
                          filteredSaleItems,
                        );
                        final categoryCost = _calculateCategoryCost(
                          filteredSaleItems,
                          inventory.products,
                        );

                        // Build income section dynamically
                        final incomeRows = <List<String>>[];
                        final allCategories = [
                          ...AppConstants.productCategories,
                          'Unknown Products',
                        ];

                        for (final category in allCategories) {
                          final revenue = categoryRevenue[category] ?? 0.0;
                          if (revenue > 0) {
                            incomeRows.add([
                              'Sales - $category',
                              CurrencyUtils.formatCurrency(revenue),
                            ]);
                          }
                        }
                        incomeRows.add([
                          'Total Sales',
                          CurrencyUtils.formatCurrency(totalRevenue),
                        ]);

                        // Build COGS section dynamically
                        final cogsRows = <List<String>>[];
                        for (final category in allCategories) {
                          final cost = categoryCost[category] ?? 0.0;
                          if (cost > 0) {
                            cogsRows.add([
                              category,
                              CurrencyUtils.formatCurrency(cost),
                            ]);
                          }
                        }
                        cogsRows.add([
                          'Total COGS',
                          CurrencyUtils.formatCurrency(totalCost),
                        ]);

                        final sections = <PdfReportSection>[
                          // 1. Income
                          PdfReportSection(
                            title: '1. Income',
                            rows: incomeRows,
                          ),

                          // 2. Cost of Goods Sold
                          PdfReportSection(
                            title: '2. Cost of Goods Sold (COGS)',
                            rows: cogsRows,
                          ),
                        ];

                        final calculations = <PdfCalculationSection>[
                          // 1. Total Revenue
                          PdfCalculationSection(
                            title: '1. Total Revenue',
                            formula: 'Sum of all sales transactions',
                            result: CurrencyUtils.formatCurrency(totalRevenue),
                          ),

                          // 2. Cost of Goods Sold
                          PdfCalculationSection(
                            title: '2. Cost of Goods Sold',
                            formula: 'Sum of product costs × quantities sold',
                            result: CurrencyUtils.formatCurrency(totalCost),
                          ),

                          // 3. Total Losses
                          PdfCalculationSection(
                            title: '3. Total Losses',
                            formula: 'Sum of damaged/expired items',
                            result: CurrencyUtils.formatCurrency(totalLoss),
                          ),

                          // 4. Gross Profit
                          PdfCalculationSection(
                            title: '4. Gross Profit',
                            formula:
                                '₱${totalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ₱${totalCost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ₱${totalLoss.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} = ₱${totalProfit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            result: CurrencyUtils.formatCurrency(totalProfit),
                          ),
                        ];

                        final summaries = <PdfSummarySection>[];
                        final file = await pdf.generateFinancialReport(
                          reportTitle: 'Financial Report - Sari-Sari Store',
                          startDate: _startDate,
                          endDate: _endDate,
                          sections: sections,
                          calculations: calculations,
                          summaries: summaries,
                        );

                        if (!context.mounted) return;

                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text(
                              'PDF saved successfully: ${file.path}',
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        ErrorLogger.logError(
                          'PDF Export Error',
                          error: e,
                          context: 'FinancialReportTab.ExportPDF',
                        );
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error generating PDF: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _startDate == null
                        ? 'All Time'
                        : '${_startDate!.toLocal().toString().split(' ')[0]} - ${_endDate!.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => _selectDateRange(context),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Select Date'),
                  ),
                ],
              ),

              // UPDATED: Expanded grid with new metrics
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // Existing cards
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

                  // NEW CARDS ADDED HERE
                  buildSummaryCard(
                    context,
                    'Average Order',
                    CurrencyUtils.formatCurrency(averageOrderValue),
                    Icons.shopping_cart_checkout,
                    Colors.purple,
                  ),
                  buildSummaryCard(
                    context,
                    'Markup %',
                    '${markupPercentage.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.indigo,
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

              // NEW: Additional metrics row
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: buildSummaryCard(
                      context,
                      'Inventory Turnover',
                      '${inventoryTurnover.toStringAsFixed(1)}x',
                      Icons.sync,
                      Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: buildSummaryCard(
                      context,
                      'Potential Profit',
                      CurrencyUtils.formatCurrency(potentialProfit),
                      Icons.account_balance_wallet,
                      Colors.amber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // UPDATED: Enhanced Profit Analysis section
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
                            '${profitMargin.toStringAsFixed(1)}%',
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
                    // NEW: Markup Percentage row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Markup Percentage:',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${markupPercentage.toStringAsFixed(1)}%',
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
                            '${roi.toStringAsFixed(1)}%',
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
                    // NEW: Stock Turns Per Year
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Stock Turns/Year:',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${_calculateAnnualizedTurnover(inventoryTurnover).toStringAsFixed(1)}x',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TopSellingProductsList(
                topProducts: topProducts.map((entry) => entry.key).toList(),
                saleItems: filteredSaleItems,
              ),
              const SizedBox(height: 24),
              LossBreakdownList(lossBreakdown: lossBreakdown),
            ],
          ),
        );
      },
    );
  }

  // NEW: Helper method to calculate annualized turnover
  double _calculateAnnualizedTurnover(double inventoryTurnover) {
    if (_startDate != null && _endDate != null) {
      final daysDiff = _endDate!.difference(_startDate!).inDays;
      if (daysDiff > 0) {
        return inventoryTurnover * (365 / daysDiff);
      }
    }
    return inventoryTurnover;
  }

  List<Sale> _filterSalesByDate(List<Sale> sales) {
    if (_startDate == null || _endDate == null) {
      return sales;
    }
    return sales.where((sale) {
      final saleDate = sale.createdAt;
      return saleDate.isAfter(_startDate!) &&
          saleDate.isBefore(_endDate!.add(const Duration(days: 1)));
    }).toList();
  }

  List<SaleItem> _filterSaleItemsBySales(
    List<SaleItem> saleItems,
    List<Sale> filteredSales,
  ) {
    final filteredSaleIds = filteredSales.map((s) => s.id).toSet();
    return saleItems
        .where((item) => filteredSaleIds.contains(item.saleId))
        .toList();
  }

  List<Loss> _filterLossesByDate(List<Loss> losses) {
    if (_startDate == null || _endDate == null) {
      return losses;
    }
    return losses.where((loss) {
      final lossDate = loss.timestamp;
      return lossDate.isAfter(_startDate!) &&
          lossDate.isBefore(_endDate!.add(const Duration(days: 1)));
    }).toList();
  }
}
