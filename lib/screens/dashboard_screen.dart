import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/customer_provider.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/sales_chart.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'customers_screen.dart';
import 'reports_screen.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../utils/currency_utils.dart';
import 'package:prostock/services/offline_manager.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardHome(onNavigateToTab: _navigateToTab),
      const InventoryScreen(),
      const POSScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
    ];

    // FIX: Schedule _loadData() to run after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  void _navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _loadData() async {
    try {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final customerProvider = Provider.of<CustomerProvider>(
        context,
        listen: false,
      );

      await Future.wait([
        inventoryProvider.loadProducts(),
        salesProvider.loadSales(),
        customerProvider.loadCustomers(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class DashboardHome extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const DashboardHome({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer<OfflineManager>(
            builder: (context, offlineManager, child) {
              return Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: offlineManager.isOnline ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    offlineManager.isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Show notifications
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );

                await authProvider.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer3<InventoryProvider, SalesProvider, CustomerProvider>(
              builder: (context, inventory, sales, customers, child) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    DashboardCard(
                      title: 'Total Products',
                      value: inventory.products.length.toString(),
                      icon: Icons.inventory,
                      color: Colors.blue,
                      isCurrency: false,
                    ),
                    DashboardCard(
                      title: 'Low Stock Items',
                      value: inventory.lowStockProducts.length.toString(),
                      icon: Icons.warning,
                      color: Colors.orange,
                      isCurrency: false,
                    ),
                    DashboardCard(
                      title: 'Today\'s Sales',
                      value: _getTodaysSales(sales.sales),
                      icon: Icons.calendar_month,
                      color: Colors.green,
                      isCurrency: true,
                    ),
                    DashboardCard(
                      title: 'Total Customers',
                      value: customers.customers.length.toString(),
                      icon: Icons.people,
                      color: Colors.purple,
                      isCurrency: false,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Quick Actions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BarcodeScannerWidget(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text(
                              'Scan Barcode',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              onNavigateToTab(
                                2,
                              ); // Navigate to POS screen (index 2)
                            },
                            icon: const Icon(Icons.point_of_sale, size: 18),
                            label: const Text(
                              'Quick Sale',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sales Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const SalesChart(),
            const SizedBox(height: 24),
            Consumer<InventoryProvider>(
              builder: (context, inventory, child) {
                if (inventory.lowStockProducts.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text(
                              'Low Stock Alert',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...inventory.lowStockProducts
                            .take(5)
                            .map(
                              (product) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(product.name),
                                subtitle: Text('Stock: ${product.stock}'),
                                trailing: Text(
                                  'Min: ${product.minStock}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTodaysSales(List sales) {
    final today = DateTime.now();
    final todaySales = sales.where((sale) {
      final saleDate = sale.createdAt;
      return saleDate.year == today.year &&
          saleDate.month == today.month &&
          saleDate.day == today.day;
    });

    final total = todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    return CurrencyUtils.formatCurrency(total);
  }
}
