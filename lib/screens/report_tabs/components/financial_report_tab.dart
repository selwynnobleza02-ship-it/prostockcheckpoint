import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/services/report_service.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/financial_summary_chart.dart';
import 'package:prostock/widgets/loss_breakdown_list.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/widgets/top_selling_products_list.dart';

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
      Provider.of<SalesProvider>(context, listen: false).loadSales();
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

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });
      Provider.of<SalesProvider>(context, listen: false).loadSales(
        startDate: _startDate,
        endDate: _endDate,
        refresh: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();
    return Consumer3<SalesProvider, InventoryProvider, CustomerProvider>(
      builder: (context, sales, inventory, customers, child) {
        if (sales.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredSales = _filterSalesByDate(sales.sales);
        final filteredSaleItems =
            _filterSaleItemsBySales(sales.saleItems, filteredSales);
        final filteredLosses = _filterLossesByDate(widget.losses);

        if (filteredSales.isEmpty) {
          return const Center(child: Text('No data available for the selected period.'));
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

        final topProducts = reportService.getTopSellingProducts(
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
              const SizedBox(height: 16),
              FinancialSummaryChart(
                totalRevenue: totalRevenue,
                totalCost: totalCost,
                totalProfit: totalProfit,
              ),
              const SizedBox(height: 16),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TopSellingProductsList(
                topProducts: topProducts,
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
