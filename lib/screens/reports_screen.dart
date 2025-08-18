import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sales_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/customer_provider.dart';
import '../widgets/inventory_chart.dart';
import '../utils/currency_utils.dart';
import '../widgets/receipt_dialog.dart';
import '../models/receipt.dart';
import '../models/sale.dart';
import '../services/firestore_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Inventory'),
            Tab(text: 'Customers'),
            Tab(text: 'Financial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesReport(),
          _buildInventoryReport(),
          _buildCustomersReport(),
          _buildFinancialReport(),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    return Consumer<SalesProvider>(
      builder: (context, provider, child) {
        final totalSales = provider.sales.fold(
          0.0,
          (sum, sale) => sum + sale.totalAmount,
        );
        final todaySales = provider.sales
            .where((sale) {
              final today = DateTime.now();
              return sale.createdAt.day == today.day &&
                  sale.createdAt.month == today.month &&
                  sale.createdAt.year == today.year;
            })
            .fold(0.0, (sum, sale) => sum + sale.totalAmount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sales Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Today\'s Sales',
                      CurrencyUtils.formatCurrency(todaySales),
                      Icons.today,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Sales',
                      CurrencyUtils.formatCurrency(totalSales),
                      Icons.attach_money,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Sales
              const Text(
                'Recent Sales',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (provider.sales.isEmpty)
                const Center(child: Text('No sales recorded yet'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.sales.take(10).length,
                  itemBuilder: (context, index) {
                    final sale = provider.sales[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            '₱',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('Sale #${sale.id}'),
                        subtitle: Text(
                          '${sale.createdAt.day}/${sale.createdAt.month}/${sale.createdAt.year} - ${sale.paymentMethod}',
                        ),
                        trailing: Text(
                          CurrencyUtils.formatCurrency(sale.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        onTap: () => _showHistoricalReceipt(context, sale),
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

  Widget _buildInventoryReport() {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final totalProducts = provider.products.length;
        final lowStockCount = provider.lowStockProducts.length;
        final totalValue = provider.products.fold(
          0.0,
          (sum, product) => sum + (product.price * product.stock),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inventory Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Products',
                      totalProducts.toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Low Stock Items',
                      lowStockCount.toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildSummaryCard(
                'Total Inventory Value',
                CurrencyUtils.formatCurrency(totalValue),
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(height: 24),

              // Inventory Chart
              const Text(
                'Inventory Distribution',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const InventoryChart(),
              const SizedBox(height: 24),

              // Low Stock Alert
              if (provider.lowStockProducts.isNotEmpty) ...[
                const Text(
                  'Low Stock Alert',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.lowStockProducts.length,
                  itemBuilder: (context, index) {
                    final product = provider.lowStockProducts[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.warning, color: Colors.white),
                        ),
                        title: Text(product.name),
                        subtitle: Text('Current Stock: ${product.stock}'),
                        trailing: Text(
                          'Min: ${product.minStock}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomersReport() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        final totalCustomers = provider.customers.length;
        final overdueCustomers = provider.customers
            .where((c) => c.hasOverdueBalance)
            .length;
        final totalCredit = provider.customers.fold(
          0.0,
          (sum, c) => sum + c.currentBalance,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Customers',
                      totalCustomers.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Overdue Customers',
                      overdueCustomers.toString(),
                      Icons.warning,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildSummaryCard(
                'Total Outstanding Credit',
                CurrencyUtils.formatCurrency(totalCredit),
                Icons.credit_card,
                Colors.orange,
              ),
              const SizedBox(height: 24),

              // Overdue Customers List
              if (overdueCustomers > 0) ...[
                const Text(
                  'Overdue Customers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.customers
                      .where((c) => c.hasOverdueBalance)
                      .length,
                  itemBuilder: (context, index) {
                    final customer = provider.customers
                        .where((c) => c.hasOverdueBalance)
                        .toList()[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(customer.name),
                        subtitle: Text('Phone: ${customer.phone ?? 'N/A'}'),
                        trailing: Text(
                          CurrencyUtils.formatCurrency(
                            customer.currentBalance,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No Overdue Customers',
                        style: TextStyle(fontSize: 18, color: Colors.green),
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
  }

  Widget _buildFinancialReport() {
    return Consumer3<SalesProvider, InventoryProvider, CustomerProvider>(
      builder: (context, sales, inventory, customers, child) {
        final totalRevenue = sales.sales.fold(
          0.0,
          (sum, sale) => sum + sale.totalAmount,
        );
        final totalCost = inventory.products.fold(
          0.0,
          (sum, product) => sum + (product.cost * product.stock),
        );
        final totalProfit = totalRevenue - totalCost;
        final outstandingCredit = customers.customers.fold(
          0.0,
          (sum, c) => sum + c.currentBalance,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Financial Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Revenue',
                      CurrencyUtils.formatCurrency(totalRevenue),
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Cost',
                      CurrencyUtils.formatCurrency(totalCost),
                      Icons.trending_down,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Gross Profit',
                      CurrencyUtils.formatCurrency(totalProfit),
                      Icons.attach_money,
                      totalProfit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Outstanding Credit',
                      CurrencyUtils.formatCurrency(outstandingCredit),
                      Icons.credit_card,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Profit Margin Analysis
              Container(
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
                        const Text('Profit Margin:'),
                        Text(
                          totalRevenue > 0
                              ? '${(totalProfit / totalRevenue * 100).toStringAsFixed(1)}%'
                              : '0.0%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Return on Investment:'),
                        Text(
                          totalCost > 0
                              ? '${(totalProfit / totalCost * 100).toStringAsFixed(1)}%'
                              : '0.0%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistoricalReceipt(BuildContext context, Sale sale) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final saleItems = await FirestoreService.instance.getSaleItemsBySaleId(
        sale.id!,
      );

      // Get customer info if available
      String? customerName;
      if (sale.customerId != null) {
        final customer = await FirestoreService.instance.getCustomerById(
          sale.customerId!,
        );
        customerName = customer?.name;
      }

      // Get product names for sale items
      List<ReceiptItem> receiptItems = [];
      for (final saleItem in saleItems) {
        final product = await FirestoreService.instance.getProductById(
          saleItem.productId,
        );
        receiptItems.add(
          ReceiptItem(
            productName: product?.name ?? 'Unknown Product',
            quantity: saleItem.quantity,
            unitPrice: saleItem.unitPrice,
            totalPrice: saleItem.totalPrice,
          ),
        );
      }

      // Create receipt object
      final receipt = Receipt(
        receiptNumber: sale.id
            .toString(), // Convert int to String for receipt number
        timestamp: sale.createdAt,
        customerName: customerName,
        paymentMethod: sale.paymentMethod,
        items: receiptItems,
        subtotal: sale.totalAmount,
        tax: 0.0, // Assuming no tax for now
        total: sale.totalAmount,
        saleId: sale.id
            .toString(), // Convert int to String to match saleId parameter type
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show receipt dialog
        showDialog(
          context: context,
          builder: (context) => ReceiptDialog(receipt: receipt),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
