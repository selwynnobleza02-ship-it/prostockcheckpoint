import 'package:flutter/material.dart';

import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/add_product_dialog.dart';
import 'package:prostock/widgets/price_history_dialog.dart';
import 'package:provider/provider.dart';

class ProductListView extends StatelessWidget {
  final String searchQuery;

  const ProductListView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredProducts = provider.products.where((product) {
          return product.name.toLowerCase().contains(searchQuery) ||
              (product.barcode?.toLowerCase().contains(searchQuery) ??
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
    );
  }
}
