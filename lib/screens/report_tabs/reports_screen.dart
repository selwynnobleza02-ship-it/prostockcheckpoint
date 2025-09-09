import 'package:flutter/material.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/stock_movement_provider.dart';
import 'package:prostock/screens/report_tabs/components/customers_report_tab.dart';
import 'package:prostock/screens/report_tabs/components/financial_report_tab.dart';
import 'package:prostock/screens/report_tabs/components/inventory_report_tab.dart';
import 'package:prostock/screens/report_tabs/components/report_tabs.dart';
import 'package:prostock/screens/report_tabs/components/sales_report_tab.dart';
import 'package:prostock/services/firestore/inventory_service.dart';
import 'package:prostock/services/firestore/sale_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/widgets/analytics_report_widget.dart';
import 'package:prostock/widgets/stock_movement_report_widget.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Loss> _losses = [];
  List<SaleItem> _saleItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ReportTabs.tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData({bool refresh = false}) async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    await salesProvider.loadSales(refresh: refresh);
    if (!mounted) return;
    await Provider.of<CustomerProvider>(
      context,
      listen: false,
    ).loadCustomers(refresh: refresh);
    if (!mounted) return;
    await Provider.of<InventoryProvider>(
      context,
      listen: false,
    ).loadProducts(refresh: refresh);
    if (!mounted) return;
    await Provider.of<StockMovementProvider>(
      context,
      listen: false,
    ).loadMovements(refresh: refresh);
    final inventoryService = InventoryService(FirebaseFirestore.instance);
    final saleService = SaleService(FirebaseFirestore.instance);
    final losses = await inventoryService.getLosses();

    final List<SaleItem> allSaleItems = [];
    for (final sale in salesProvider.sales) {
      if (sale.id != null) {
        if (sale.isSynced == 1) {
          final items = await saleService.getSaleItemsBySaleId(sale.id!);
          allSaleItems.addAll(items);
        } else {
          final localItems = await LocalDatabaseService.instance.getSaleItems(
            sale.id!,
          );
          allSaleItems.addAll(
            localItems.map((item) => SaleItem.fromMap(item)).toList(),
          );
        }
      }
    }

    setState(() {
      _losses = losses;
      _saleItems = allSaleItems;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(refresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: ReportTabs.tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const SalesReportTab(),
          const InventoryReportTab(),
          const CustomersReportTab(),
          FinancialReportTab(losses: _losses),
          AnalyticsReportWidget(saleItems: _saleItems, losses: _losses),
          const StockMovementReportWidget(),
        ],
      ),
    );
  }
}
