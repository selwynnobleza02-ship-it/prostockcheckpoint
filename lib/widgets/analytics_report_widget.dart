import 'package:flutter/material.dart';
import 'package:prostock/models/sale.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/sales_provider.dart';
import 'sales_over_time_chart.dart';
import 'top_customers_list.dart';
import 'top_selling_products_chart.dart';

class AnalyticsReportWidget extends StatelessWidget {
  final List<SaleItem> saleItems;

  const AnalyticsReportWidget({
    super.key,
    required this.saleItems,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<SalesProvider, InventoryProvider, CustomerProvider>(
      builder:
          (context, salesProvider, inventoryProvider, customerProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Over Time',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (salesProvider.sales.isEmpty)
                const Center(child: Text('No sales data available.'))
              else
                SalesOverTimeChart(sales: salesProvider.sales),
              const SizedBox(height: 24),
              const Text(
                'Top Selling Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (saleItems.isEmpty || inventoryProvider.products.isEmpty)
                const Center(child: Text('No product data available.'))
              else
                TopSellingProductsChart(
                  saleItems: saleItems,
                  products: inventoryProvider.products,
                ),
              const SizedBox(height: 24),
              const Text(
                'Top Customers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (salesProvider.sales.isEmpty ||
                  customerProvider.customers.isEmpty)
                const Center(child: Text('No customer data available.'))
              else
                TopCustomersList(
                  sales: salesProvider.sales,
                  customers: customerProvider.customers,
                ),
            ],
          ),
        );
      },
    );
  }
}