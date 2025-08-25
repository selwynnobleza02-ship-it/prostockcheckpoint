import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../utils/currency_utils.dart';
import '../widgets/price_history_dialog.dart';

import 'dart:async'; // Import for Timer

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BarcodeScannerWidget(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController, // Assign controller
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              // onChanged is now handled by the listener on _searchController
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BarcodeScannerWidget(
                            mode: ScannerMode.receiveStock,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_box),
                    label: const Text('Receive Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BarcodeScannerWidget(
                            mode: ScannerMode.removeStock,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.remove_circle),
                    label: const Text('Remove Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredProducts = provider.products.where((product) {
                  return product.name.toLowerCase().contains(_searchQuery) ||
                      (product.barcode?.toLowerCase().contains(_searchQuery) ??
                          false);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(child: Text('No products found'));
                }

                if (provider.error != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(provider.error!),
                        backgroundColor: Colors.red,
                      ),
                    );
                    provider.clearError(); // Clear the error after showing it
                  });
                }

                return RefreshIndicator(
                  onRefresh: () => provider.refreshProducts(),
                  child: ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: product.isLowStock
                                ? Colors.red
                                : Colors.green,
                            child: Text(
                              product.stock.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Price: ${CurrencyUtils.formatCurrency(product.price)}',
                              ),
                              if (product.barcode != null)
                                Text('Barcode: ${product.barcode}'),
                              if (product.isLowStock)
                                const Text(
                                  'Low Stock!',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.history),
                                tooltip: 'Price History',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => PriceHistoryDialog(productId: product.id!),
                                  );
                                },
                              ),
                              Icon(
                                Icons.inventory_2,
                                color: product.isLowStock ? Colors.red : Colors.teal,
                                size: 24,
                              ),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AddProductDialog(product: product),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddProductDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
