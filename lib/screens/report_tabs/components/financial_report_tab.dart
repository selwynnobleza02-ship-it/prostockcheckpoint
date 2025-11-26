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
import 'package:flutter/foundation.dart';
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
                                      'How would you like to export your financial report?',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.article,
                                        color: Colors.blue,
                                      ),
                                      title: const Text('Combined PDF'),
                                      subtitle: const Text(
                                        'Auto-splits large sections into multiple PDFs',
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

                            if (exportMethod == null || !context.mounted) {
                              return;
                            }

                            // Prompt user to select date range for export
                            if (!context.mounted) return;
                            final confirmDateRange = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Select Date Range'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Current date range for export:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _startDate == null
                                                  ? 'All Time'
                                                  : '${_startDate!.toLocal().toString().split(' ')[0]} to ${_endDate!.toLocal().toString().split(' ')[0]}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Would you like to change the date range or proceed with the current selection?',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _selectDateRange(context);
                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ).then((_) => Navigator.pop(context));
                                        // Show the dialog again after date selection
                                        showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Date Range Updated',
                                            ),
                                            content: Text(
                                              'New range: ${_startDate == null ? 'All Time' : '${_startDate!.toLocal().toString().split(' ')[0]} to ${_endDate!.toLocal().toString().split(' ')[0]}'}',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Proceed'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Change Date'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Proceed'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmDateRange != true || !context.mounted) {
                              return;
                            }

                            // For Single PDF, allow section selection
                            Set<String>? selectedSectionTitles;
                            if (exportMethod == 'single') {
                              if (!context.mounted) return;
                              selectedSectionTitles = await showDialog<Set<String>>(
                                context: context,
                                builder: (context) {
                                  // Define available sections
                                  final availableSections = {
                                    '1. Income': true,
                                    '2. Cost of Goods Sold (COGS)': true,
                                  };

                                  // Define available calculations
                                  final availableCalculations = {
                                    '1. Total Revenue': true,
                                    '2. Cost of Goods Sold': true,
                                    '3. Total Losses': true,
                                    '4. Gross Profit': true,
                                    '5. Profit Margin': true,
                                    '6. Markup Percentage': true,
                                    '7. Return on Investment (ROI)': true,
                                    '8. Inventory Turnover': true,
                                  };

                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        title: const Text(
                                          'Select Sections to Include',
                                        ),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Choose which sections to include in your PDF:',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'Data Sections:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ...availableSections.keys.map(
                                                  (title) => CheckboxListTile(
                                                    dense: true,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      title,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    value:
                                                        availableSections[title],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        availableSections[title] =
                                                            value!;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'Financial Calculations:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ...availableCalculations.keys.map(
                                                  (title) => CheckboxListTile(
                                                    dense: true,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      title,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    value:
                                                        availableCalculations[title],
                                                    onChanged: (value) {
                                                      setState(() {
                                                        availableCalculations[title] =
                                                            value!;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        setState(() {
                                                          availableSections
                                                              .updateAll(
                                                                (key, value) =>
                                                                    true,
                                                              );
                                                          availableCalculations
                                                              .updateAll(
                                                                (key, value) =>
                                                                    true,
                                                              );
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons.select_all,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Select All',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        setState(() {
                                                          availableSections
                                                              .updateAll(
                                                                (key, value) =>
                                                                    false,
                                                              );
                                                          availableCalculations
                                                              .updateAll(
                                                                (key, value) =>
                                                                    false,
                                                              );
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons.clear,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Clear All',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              final selected = {
                                                ...availableSections.entries
                                                    .where((e) => e.value)
                                                    .map((e) => e.key),
                                                ...availableCalculations.entries
                                                    .where((e) => e.value)
                                                    .map((e) => e.key),
                                              };
                                              if (selected.isEmpty) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Please select at least one section',
                                                    ),
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              Navigator.pop(context, selected);
                                            },
                                            child: const Text('Generate PDF'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );

                              if (selectedSectionTitles == null ||
                                  !context.mounted) {
                                return;
                              }
                            }

                            final scaffold = ScaffoldMessenger.of(context);

                            // Use current date filters if set
                            List<Sale> exportFilteredSales = filteredSales;
                            List<SaleItem> exportFilteredSaleItems =
                                filteredSaleItems;
                            List<Loss> exportFilteredLosses = filteredLosses;

                            // Validate we have data to export
                            if (exportFilteredSales.isEmpty) {
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

                            if (exportFilteredSaleItems.isEmpty) {
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

                            // Recalculate totals based on export-filtered data
                            final exportTotalRevenue = reportService
                                .calculateTotalSales(exportFilteredSales);
                            final exportTotalCost = reportService
                                .calculateTotalCost(
                                  exportFilteredSaleItems,
                                  inventory.products,
                                );
                            final exportTotalLoss = reportService
                                .calculateTotalLoss(exportFilteredLosses);
                            final exportTotalProfit = reportService
                                .calculateGrossProfit(
                                  exportTotalRevenue,
                                  exportTotalCost,
                                  exportTotalLoss,
                                );
                            final exportProfitMargin = reportService
                                .calculateProfitMargin(
                                  exportTotalProfit,
                                  exportTotalRevenue,
                                );
                            final exportRoi = reportService.calculateRoi(
                              exportTotalProfit,
                              exportTotalCost,
                            );
                            final exportMarkupPercentage = reportService
                                .calculateMarkupPercentage(
                                  exportTotalRevenue,
                                  exportTotalCost,
                                );
                            final exportAverageOrderValue = reportService
                                .calculateAverageOrderValue(
                                  exportFilteredSales,
                                );
                            final exportInventoryTurnover = reportService
                                .calculateInventoryTurnover(
                                  exportTotalCost,
                                  averageInventoryValue,
                                );

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
                            for (final item in exportFilteredSaleItems) {
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
                            final saleDate = exportFilteredSales.isNotEmpty
                                ? exportFilteredSales.first.createdAt
                                : DateTime.now();

                            // BATCH QUERY: Get all historical costs at once
                            final itemCosts = await historicalCostService
                                .getHistoricalCostsForSaleItems(
                                  exportFilteredSaleItems,
                                  saleDate,
                                );

                            // Group by product and cost using the batch results
                            for (final item in exportFilteredSaleItems) {
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
                              CurrencyUtils.formatCurrency(exportTotalRevenue),
                            ]);
                            cogsRows.add([
                              'Total COGS',
                              totalCogsQty.toStringAsFixed(0),
                              '-',
                              CurrencyUtils.formatCurrency(exportTotalCost),
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
                                    'Sum of ${exportFilteredSaleItems.length} sale items = ${exportTotalRevenue.toStringAsFixed(2)}',
                                result: CurrencyUtils.formatCurrency(
                                  exportTotalRevenue,
                                ),
                              ),

                              // 2. Cost of Goods Sold
                              PdfCalculationSection(
                                title: '2. Cost of Goods Sold',
                                formula:
                                    'Sum of product costs × quantities sold',
                                calculation:
                                    'Sum of (product cost × quantity sold) for each item = ${exportTotalCost.toStringAsFixed(2)}',
                                result: CurrencyUtils.formatCurrency(
                                  exportTotalCost,
                                ),
                              ),

                              // 3. Total Losses
                              PdfCalculationSection(
                                title: '3. Total Losses',
                                formula: 'Sum of damaged/expired items',
                                calculation:
                                    'Sum of ${exportFilteredLosses.length} loss items = ${exportTotalLoss.toStringAsFixed(2)}',
                                result: CurrencyUtils.formatCurrency(
                                  exportTotalLoss,
                                ),
                              ),

                              // 4. Gross Profit
                              PdfCalculationSection(
                                title: '4. Gross Profit',
                                formula:
                                    'Total Revenue - Cost of Goods Sold - Total Losses',
                                calculation:
                                    '${exportTotalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ${exportTotalCost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ${exportTotalLoss.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} = ${exportTotalProfit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                result: CurrencyUtils.formatCurrency(
                                  exportTotalProfit,
                                ),
                              ),

                              // 5. Profit Margin
                              PdfCalculationSection(
                                title: '5. Profit Margin',
                                formula: '(Gross Profit ÷ Total Revenue) × 100',
                                calculation:
                                    '(${exportTotalProfit.toStringAsFixed(2)} ÷ ${exportTotalRevenue.toStringAsFixed(2)}) × 100 = ${exportProfitMargin.toStringAsFixed(1)}%',
                                result:
                                    '${exportProfitMargin.toStringAsFixed(1)}%',
                              ),

                              // 6. Markup Percentage
                              PdfCalculationSection(
                                title: '6. Markup Percentage',
                                formula: '((Revenue - Cost) ÷ Cost) × 100',
                                calculation:
                                    '((${exportTotalRevenue.toStringAsFixed(2)} - ${exportTotalCost.toStringAsFixed(2)}) ÷ ${exportTotalCost.toStringAsFixed(2)}) × 100 = ${exportMarkupPercentage.toStringAsFixed(1)}%',
                                result:
                                    '${exportMarkupPercentage.toStringAsFixed(1)}%',
                              ),

                              // 7. Return on Investment (ROI)
                              PdfCalculationSection(
                                title: '7. Return on Investment (ROI)',
                                formula: '(Total Profit ÷ Total Cost) × 100',
                                calculation:
                                    '(${exportTotalProfit.toStringAsFixed(2)} ÷ ${exportTotalCost.toStringAsFixed(2)}) × 100 = ${exportRoi.toStringAsFixed(1)}%',
                                result: '${exportRoi.toStringAsFixed(1)}%',
                              ),

                              // 8. Inventory Turnover
                              PdfCalculationSection(
                                title: '8. Inventory Turnover',
                                formula: 'COGS ÷ Average Inventory Value',
                                calculation:
                                    '${exportTotalCost.toStringAsFixed(2)} ÷ ${averageInventoryValue.toStringAsFixed(2)} = ${exportInventoryTurnover.toStringAsFixed(1)}x',
                                result:
                                    '${exportInventoryTurnover.toStringAsFixed(1)}x',
                              ),
                            ];

                            final summaries = <PdfSummarySection>[];

                            // Note: For Separate PDFs mode, we use original sections without limits
                            // The system will automatically split large sections into multiple PDFs
                            List<PdfReportSection> filteredSections = sections;

                            // Validate that we have sections to export
                            if (filteredSections.isEmpty) {
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No data available to export after applying filters. Try increasing the item limit or disabling "Summary Only" mode.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                              return;
                            }

                            try {
                              // Show progress dialog
                              if (!context.mounted) return;
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
                                            ? 'Generating ${filteredSections.length + 1} PDF files...\nPlease wait.'
                                            : 'Generating PDF(s)...\nPlease wait.',
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              ErrorLogger.logInfo(
                                'Starting financial report PDF generation',
                                context: 'FinancialReportTab',
                                metadata: {
                                  'exportMethod': exportMethod,
                                  'filteredSections': filteredSections.length,
                                  'calculations': calculations.length,
                                  'summaries': summaries.length,
                                },
                              );

                              // Generate PDFs based on chosen method
                              final List<File> files;

                              if (exportMethod == 'separate') {
                                // Generate one PDF per section with ALL data
                                files = await pdf.generatePdfPerSection(
                                  reportTitle:
                                      'Financial Report - Sari-Sari Store',
                                  startDate: _startDate,
                                  endDate: _endDate,
                                  sections:
                                      sections, // Use original sections without limits
                                  calculations: calculations,
                                  summaries: summaries,
                                );
                              } else {
                                // For Single PDF, filter sections and calculations based on user selection
                                List<PdfReportSection> sectionsToInclude =
                                    filteredSections;
                                List<PdfCalculationSection>?
                                calculationsToInclude = calculations;

                                if (selectedSectionTitles != null) {
                                  // Filter sections
                                  sectionsToInclude = filteredSections
                                      .where(
                                        (section) => selectedSectionTitles!
                                            .contains(section.title),
                                      )
                                      .toList();

                                  // Filter calculations
                                  calculationsToInclude = calculations
                                      .where(
                                        (calc) => selectedSectionTitles!
                                            .contains(calc.title),
                                      )
                                      .toList();

                                  // If no calculations selected, set to null
                                  if (calculationsToInclude.isEmpty) {
                                    calculationsToInclude = null;
                                  }
                                }

                                // Generate combined PDF - uses auto-splitting for large sections
                                files = await pdf.generatePdfPerSection(
                                  reportTitle:
                                      'Financial Report - Sari-Sari Store',
                                  startDate: _startDate,
                                  endDate: _endDate,
                                  sections: sectionsToInclude,
                                  calculations: calculationsToInclude,
                                  summaries: summaries,
                                );
                              } // Close progress dialog
                              if (!context.mounted) return;
                              Navigator.of(context).pop();

                              // Validate all files
                              final validFiles = <File>[];
                              for (final file in files) {
                                final fileExists = await file.exists();
                                final fileSize = fileExists
                                    ? await file.length()
                                    : 0;
                                if (fileExists && fileSize > 0) {
                                  validFiles.add(file);
                                }
                              }

                              ErrorLogger.logInfo(
                                'PDF file generation successful',
                                context: 'FinancialReportTab',
                                metadata: {
                                  'filesGenerated': files.length,
                                  'validFiles': validFiles.length,
                                  'exportMethod': exportMethod,
                                },
                              );

                              if (!context.mounted) return;

                              if (validFiles.isEmpty) {
                                scaffold.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Error: PDF files were not created properly. Please check storage permissions and try again.',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 6),
                                  ),
                                );
                                return;
                              }

                              // Check if some files failed to generate (only for 'separate' method)
                              if (exportMethod == 'separate') {
                                final expectedFileCount =
                                    filteredSections.length +
                                    1; // sections + summary
                                if (validFiles.length < expectedFileCount) {
                                  final missingCount =
                                      expectedFileCount - validFiles.length;
                                  ErrorLogger.logWarning(
                                    'Not all PDF files were generated',
                                    context: 'FinancialReportTab',
                                    metadata: {
                                      'expected': expectedFileCount,
                                      'actual': validFiles.length,
                                      'missing': missingCount,
                                    },
                                  );

                                  // Show warning to user
                                  scaffold.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Warning: Only ${validFiles.length} of $expectedFileCount PDF files were created. Some sections may have failed. Check the console/logs for details.',
                                      ),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 8),
                                      action: SnackBarAction(
                                        label: 'OK',
                                        textColor: Colors.white,
                                        onPressed: () {},
                                      ),
                                    ),
                                  );
                                }
                              }

                              // Single file - show simple SnackBar
                              if (validFiles.length == 1) {
                                final file = validFiles.first;
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
                                // Multiple files - show detailed dialog
                                String locationText = 'Downloads folder';
                                if (validFiles.isNotEmpty) {
                                  final firstPath = validFiles.first.path;
                                  if (firstPath.contains('/Download')) {
                                    locationText = 'Downloads folder';
                                  } else {
                                    final pathParts = firstPath.split('/');
                                    if (pathParts.length >= 2) {
                                      locationText =
                                          pathParts[pathParts.length - 2];
                                    }
                                  }
                                }

                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          validFiles.length > 1
                                              ? 'PDF Files Created'
                                              : 'PDF File Created',
                                        ),
                                      ],
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            validFiles.length > 1
                                                ? 'Generated ${validFiles.length} PDF file(s):'
                                                : 'PDF file generated successfully',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (exportMethod == 'separate' &&
                                              validFiles.length > 1) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              '✓ Income report\n'
                                              '✓ Cost of Goods Sold report\n'
                                              '✓ Financial Summary with calculations',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    size: 20,
                                                    color: Colors.blue[700],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Each file contains ALL entries without truncation',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.blue[900],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else if (validFiles.length > 1) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    size: 20,
                                                    color: Colors.blue[700],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Large sections were automatically split to handle the data size',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.blue[900],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.green[200]!,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.folder,
                                                  color: Colors.green[700],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Location: $locationText',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.green[900],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...validFiles.asMap().entries.map((
                                            entry,
                                          ) {
                                            final index = entry.key + 1;
                                            final file = entry.value;

                                            // Extract file name
                                            String fileName = file.path
                                                .split('/')
                                                .last;

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8.0,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$index. ',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      fileName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          const SizedBox(height: 12),
                                          const Text(
                                            '💡 All files are in your Downloads folder.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
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
                                      startDate: _startDate,
                                      endDate: _endDate,
                                      sections: filteredSections,
                                      calculations: calculations,
                                      summaries: summaries,
                                      sectionsPerPdf:
                                          2, // Safer: 2 sections per PDF
                                      maxRowsPerSection:
                                          25, // Safer: 25 rows per section
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
