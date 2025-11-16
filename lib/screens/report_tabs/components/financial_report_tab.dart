import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/credit_transaction.dart';
// import 'package:prostock/models/product.dart';
import 'package:prostock/providers/stock_movement_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
// import 'package:prostock/utils/constants.dart';

import 'package:prostock/widgets/loss_breakdown_list.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:prostock/widgets/top_selling_products_list.dart';
import 'package:prostock/services/pdf_report_service.dart';
import 'package:prostock/services/historical_cost_service.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:prostock/widgets/export_filter_dialog.dart';
import 'dart:io';
import 'package:prostock/services/cost_history_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialReportTab extends StatefulWidget {
  final List<Loss> losses;
  final List<CreditTransaction> creditTransactions;
  const FinancialReportTab({
    super.key,
    required this.losses,
    this.creditTransactions = const [],
  });

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

  // Category lookup removed for product-level export

  // Category helpers removed for product-level PDF export

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

        final cashSalesRevenue = reportService.calculateTotalSales(
          filteredSales,
        );
        final creditPaymentsRevenue = reportService
            .calculateTotalCreditPayments(widget.creditTransactions);
        final totalRevenue = cashSalesRevenue + creditPaymentsRevenue;
        final totalCostSales = reportService.calculateTotalCost(
          filteredSaleItems,
          inventory.products,
        );
        final totalCostCredit = reportService
            .calculateTotalCostFromCreditTransactions(
              widget.creditTransactions,
              inventory.products,
            );
        final totalCost = totalCostSales + totalCostCredit;
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
        // Calculate potential profit asynchronously
        final potentialProfitFuture = reportService
            .calculatePotentialInventoryProfit(inventory.products);

        return FutureBuilder<double>(
          future: potentialProfitFuture,
          builder: (context, snapshot) {
            final potentialProfit = snapshot.hasData ? snapshot.data! : 0.0;

            final topProducts = reportService.getTopSellingProductsByRevenue(
              filteredSaleItems,
              inventory.products,
            );

            final lossBreakdown = reportService.getLossBreakdown(
              filteredLosses,
              inventory.products,
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
                            // Show filter options
                            final exportOptions = ExportFilterOptions(
                              useDataRangeFilter:
                                  _startDate != null && _endDate != null,
                              startDate: _startDate,
                              endDate: _endDate,
                            );

                            // Show the filter dialog
                            if (!context.mounted) return;
                            final result =
                                await showDialog<ExportFilterOptions>(
                                  context: context,
                                  builder: (context) => ExportFilterDialog(
                                    initialOptions: exportOptions,
                                    onApply: (options) async {
                                      Navigator.of(context).pop(options);
                                    },
                                  ),
                                );

                            // If user cancelled the dialog
                            if (result == null || !context.mounted) return;

                            final options = result;
                            final scaffold = ScaffoldMessenger.of(context);

                            // Validate we have data to export
                            if (filteredSales.isEmpty) {
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No sales data available for the selected period.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }

                            if (filteredSaleItems.isEmpty) {
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No sale items available for the selected period.',
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

                            // Category breakdown no longer needed for product-level export

                            // Build income section by product with quantity and price
                            // incomeRows: [product, quantity, unit price, amount]
                            final incomeRows = <List<String>>[];
                            // cogsRows: [product, quantity, cost]
                            final cogsRows = <List<String>>[];

                            // Group sale items by product and unit price
                            final Map<String, Map<double, double>>
                            qtyByProductPrice = {};
                            final Map<String, Map<double, double>>
                            revenueByProductPrice = {};
                            // Also track total quantity per product for COGS computation
                            final Map<String, double> qtyByProduct = {};
                            for (final item in filteredSaleItems) {
                              // Round unit price to 2 decimals to avoid floating noise
                              final roundedUnitPrice =
                                  (item.unitPrice * 100).round() / 100.0;

                              qtyByProduct[item.productId] =
                                  (qtyByProduct[item.productId] ?? 0) +
                                  item.quantity;

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

                            // Build lookup for product names and costs
                            final productById = {
                              for (final p in inventory.products) p.id: p,
                            };

                            double totalSalesQty = 0;
                            double totalCogsQty = 0;
                            // Build income rows per product per unit price
                            final productIdsSorted =
                                qtyByProductPrice.keys.toList(growable: false)
                                  ..sort(
                                    (a, b) => (productById[a]?.name ?? a)
                                        .compareTo(productById[b]?.name ?? b),
                                  );

                            for (final productId in productIdsSorted) {
                              final product = productById[productId];
                              final name =
                                  product?.name ??
                                  'Unknown Product ($productId)';
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
                                totalSalesQty += qty;
                                incomeRows.add([
                                  name,
                                  qty.toStringAsFixed(0),
                                  CurrencyUtils.formatCurrency(price),
                                  CurrencyUtils.formatCurrency(revenue),
                                ]);
                              }
                            }

                            // COGS rows based on historical cost * qty, grouped by product and cost
                            final Map<String, Map<double, double>>
                            qtyByProductCost = {};
                            final Map<String, Map<double, double>>
                            costByProductCost = {};

                            // Initialize historical cost service
                            final costHistoryService = CostHistoryService(
                              FirebaseFirestore.instance,
                            );
                            final localDatabaseService =
                                LocalDatabaseService.instance;
                            final historicalCostService = HistoricalCostService(
                              costHistoryService,
                              localDatabaseService,
                            );

                            // Get the earliest sale date for batch query
                            final saleDate = filteredSales.isNotEmpty
                                ? filteredSales.first.createdAt
                                : DateTime.now();

                            // BATCH QUERY: Get all historical costs at once
                            final itemCosts = await historicalCostService
                                .getHistoricalCostsForSaleItems(
                                  filteredSaleItems,
                                  saleDate,
                                );

                            // Group by product and cost using the batch results
                            for (final item in filteredSaleItems) {
                              final productId = item.productId;
                              final historicalCost = itemCosts[item.id] ?? 0.0;

                              // Round cost to 2 decimals to avoid floating noise
                              final roundedCost =
                                  (historicalCost * 100).round() / 100.0;

                              qtyByProductCost[productId] ??= {};
                              qtyByProductCost[productId]![roundedCost] =
                                  (qtyByProductCost[productId]![roundedCost] ??
                                      0) +
                                  item.quantity;

                              costByProductCost[productId] ??= {};
                              costByProductCost[productId]![roundedCost] =
                                  (costByProductCost[productId]![roundedCost] ??
                                      0) +
                                  (roundedCost * item.quantity);
                            }

                            // Build COGS rows per product per cost
                            final cogsProductIdsSorted =
                                qtyByProductCost.keys.toList(growable: false)
                                  ..sort(
                                    (a, b) => (productById[a]?.name ?? a)
                                        .compareTo(productById[b]?.name ?? b),
                                  );

                            for (final productId in cogsProductIdsSorted) {
                              final product = productById[productId];
                              final name =
                                  product?.name ??
                                  'Unknown Product ($productId)';
                              final costMap = qtyByProductCost[productId] ?? {};
                              final costsSorted = costMap.keys.toList(
                                growable: false,
                              )..sort();

                              for (final cost in costsSorted) {
                                final qty = costMap[cost] ?? 0;
                                final totalCost =
                                    (costByProductCost[productId] ??
                                        {})[cost] ??
                                    0.0;
                                totalCogsQty += qty;
                                cogsRows.add([
                                  name,
                                  qty.toStringAsFixed(0),
                                  CurrencyUtils.formatCurrency(cost),
                                  CurrencyUtils.formatCurrency(totalCost),
                                ]);
                              }
                            }

                            // Totals
                            incomeRows.add([
                              'Total Sales',
                              totalSalesQty.toStringAsFixed(0),
                              '-',
                              CurrencyUtils.formatCurrency(totalRevenue),
                            ]);
                            cogsRows.add([
                              'Total COGS',
                              totalCogsQty.toStringAsFixed(0),
                              '-',
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
                                calculation:
                                    'Sum of ${filteredSaleItems.length} sale items = ${totalRevenue.toStringAsFixed(2)}',
                                result: CurrencyUtils.formatCurrency(
                                  totalRevenue,
                                ),
                              ),

                              // 2. Cost of Goods Sold
                              PdfCalculationSection(
                                title: '2. Cost of Goods Sold',
                                formula:
                                    'Sum of product costs × quantities sold',
                                calculation:
                                    'Sum of (product cost × quantity sold) for each item = ${totalCost.toStringAsFixed(2)}',
                                result: CurrencyUtils.formatCurrency(totalCost),
                              ),

                              // 3. Total Losses
                              PdfCalculationSection(
                                title: '3. Total Losses',
                                formula: 'Sum of damaged/expired items',
                                calculation:
                                    'Sum of ${filteredLosses.length} loss items = ${totalLoss.toStringAsFixed(2)}',
                                result: CurrencyUtils.formatCurrency(totalLoss),
                              ),

                              // 4. Gross Profit
                              PdfCalculationSection(
                                title: '4. Gross Profit',
                                formula:
                                    'Total Revenue - Cost of Goods Sold - Total Losses',
                                calculation:
                                    '${totalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ${totalCost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ${totalLoss.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} = ${totalProfit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                result: CurrencyUtils.formatCurrency(
                                  totalProfit,
                                ),
                              ),

                              // 5. Profit Margin
                              PdfCalculationSection(
                                title: '5. Profit Margin',
                                formula: '(Gross Profit ÷ Total Revenue) × 100',
                                calculation:
                                    '(${totalProfit.toStringAsFixed(2)} ÷ ${totalRevenue.toStringAsFixed(2)}) × 100 = ${profitMargin.toStringAsFixed(1)}%',
                                result: '${profitMargin.toStringAsFixed(1)}%',
                              ),

                              // 6. Markup Percentage
                              PdfCalculationSection(
                                title: '6. Markup Percentage',
                                formula: '((Revenue - Cost) ÷ Cost) × 100',
                                calculation:
                                    '((${totalRevenue.toStringAsFixed(2)} - ${totalCost.toStringAsFixed(2)}) ÷ ${totalCost.toStringAsFixed(2)}) × 100 = ${markupPercentage.toStringAsFixed(1)}%',
                                result:
                                    '${markupPercentage.toStringAsFixed(1)}%',
                              ),

                              // 7. Return on Investment (ROI)
                              PdfCalculationSection(
                                title: '7. Return on Investment (ROI)',
                                formula: '(Total Profit ÷ Total Cost) × 100',
                                calculation:
                                    '(${totalProfit.toStringAsFixed(2)} ÷ ${totalCost.toStringAsFixed(2)}) × 100 = ${roi.toStringAsFixed(1)}%',
                                result: '${roi.toStringAsFixed(1)}%',
                              ),

                              // 8. Inventory Turnover
                              PdfCalculationSection(
                                title: '8. Inventory Turnover',
                                formula: 'COGS ÷ Average Inventory Value',
                                calculation:
                                    '${totalCost.toStringAsFixed(2)} ÷ ${averageInventoryValue.toStringAsFixed(2)} = ${inventoryTurnover.toStringAsFixed(1)}x',
                                result:
                                    '${inventoryTurnover.toStringAsFixed(1)}x',
                              ),
                            ];

                            final summaries = <PdfSummarySection>[];

                            // Apply filter options to limit data
                            List<PdfReportSection> filteredSections = sections;
                            if (options.useDataRangeFilter) {
                              // Date filtering is already applied via _startDate and _endDate
                            }

                            // Apply item count limit and summary-only filter
                            if (options.limitItemCount || options.summaryOnly) {
                              filteredSections = pdf.applyDataLimits(
                                sections,
                                maxRowsPerSection: options.maxItemCount,
                                summaryOnly: options.summaryOnly,
                              );
                            }

                            try {
                              // Show progress dialog
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Generating PDF...\nPlease wait.'),
                                    ],
                                  ),
                                ),
                              );

                              ErrorLogger.logInfo(
                                'Starting financial report PDF generation',
                                context: 'FinancialReportTab',
                                metadata: {
                                  'filteredSections': filteredSections.length,
                                  'calculations': calculations.length,
                                  'summaries': summaries.length,
                                },
                              );

                              // Generate the PDF with filtered sections in background
                              final file = await pdf.generatePdfInBackground(
                                reportTitle:
                                    'Financial Report - Sari-Sari Store',
                                startDate: options.useDataRangeFilter
                                    ? options.startDate
                                    : _startDate,
                                endDate: options.useDataRangeFilter
                                    ? options.endDate
                                    : _endDate,
                                sections: filteredSections,
                                calculations: calculations,
                                summaries: summaries,
                              );

                              // Close progress dialog
                              if (!context.mounted) return;
                              Navigator.of(context).pop();

                              // Make sure the file exists and has content
                              final fileExists = await file.exists();
                              final fileSize = fileExists
                                  ? await file.length()
                                  : 0;

                              ErrorLogger.logInfo(
                                'PDF file generation successful',
                                context: 'FinancialReportTab',
                                metadata: {
                                  'filePath': file.path,
                                  'fileExists': fileExists,
                                  'fileSize': fileSize,
                                },
                              );

                              if (!context.mounted) return;

                              if (fileExists && fileSize > 0) {
                                // Extract user-friendly location from the path
                                String userFriendlyPath = file.path;
                                if (file.path.contains(
                                  '/My Phone/Internal Storage/Download',
                                )) {
                                  userFriendlyPath = 'Downloads folder';
                                } else if (file.path.contains(
                                  '/storage/emulated/0/Download',
                                )) {
                                  userFriendlyPath = 'Downloads folder';
                                } else if (file.path.contains(
                                  '/sdcard/Download',
                                )) {
                                  userFriendlyPath = 'Downloads folder';
                                } else {
                                  // Try to make the path more readable
                                  final pathParts = file.path.split('/');
                                  if (pathParts.length >= 3) {
                                    userFriendlyPath =
                                        '${pathParts[pathParts.length - 3]}/${pathParts[pathParts.length - 2]}/${pathParts[pathParts.length - 1]}';
                                  }
                                }

                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'PDF saved successfully in: $userFriendlyPath',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 8),
                                  ),
                                );
                              } else {
                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error: PDF file was not created properly. Please check storage permissions.',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 6),
                                  ),
                                );
                              }
                            } catch (e, stack) {
                              // Log detailed error
                              ErrorLogger.logError(
                                'PDF generation failed',
                                error: e,
                                stackTrace: stack,
                                context: 'FinancialReportTab',
                                metadata: {
                                  'filteredSections': filteredSections.length,
                                  'calculations': calculations.length,
                                  'summaries': summaries.length,
                                },
                              );

                              // Close progress dialog if still showing
                              if (!context.mounted) return;
                              if (Navigator.canPop(context)) {
                                Navigator.of(context).pop();
                              }

                              // Show technical details to help debugging
                              if (kDebugMode) {
                                final errorMsg = e.toString();
                                print('DEBUG: Full PDF generation error:');
                                print(errorMsg);
                                print('Stack trace:');
                                print(stack);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'DEBUG: Generating PDF: ${errorMsg.length > 150 ? '${errorMsg.substring(0, 150)}...' : errorMsg}',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 10),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Error generating PDF. Please try again or check your data.',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
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
                                          'Financial Report - Sari-Sari Store',
                                      startDate: options.useDataRangeFilter
                                          ? options.startDate
                                          : _startDate,
                                      endDate: options.useDataRangeFilter
                                          ? options.endDate
                                          : _endDate,
                                      sections: filteredSections,
                                      calculations: calculations,
                                      summaries: summaries,
                                      sectionsPerPdf:
                                          3, // Fewer sections per PDF
                                    );

                                // Close progress dialog
                                if (!context.mounted) return;
                                Navigator.of(context).pop();

                                if (!context.mounted) return;

                                // Extract user-friendly location from the path
                                String userFriendlyPath = Directory(
                                  files.first.parent.path,
                                ).path;
                                if (userFriendlyPath.contains(
                                  '/My Phone/Internal Storage/Download',
                                )) {
                                  userFriendlyPath = 'Downloads folder';
                                } else if (userFriendlyPath.contains(
                                  '/storage/emulated/0/Download',
                                )) {
                                  userFriendlyPath = 'Downloads folder';
                                } else if (userFriendlyPath.contains(
                                  '/sdcard/Download',
                                )) {
                                  userFriendlyPath = 'Downloads folder';
                                }

                                scaffold.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Generated ${files.length} PDF files in $userFriendlyPath',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 6),
                                  ),
                                );
                              } else {
                                rethrow; // Re-throw to be caught by outer catch
                              }
                            }
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
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
      },
    );
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
