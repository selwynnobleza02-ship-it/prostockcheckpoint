import 'package:flutter/material.dart';

import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/add_product_dialog.dart';
import 'package:prostock/widgets/price_history_dialog.dart';
import 'package:prostock/services/tax_service.dart';
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
              (product.barcode?.toLowerCase().contains(searchQuery) ?? false);
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
              final visualStock = provider.getVisualStock(product.id!);
              final isQueued = !provider.isOnline;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: product.isLowStock
                            ? Colors.red
                            : Colors.green,
                        child: Text(
                          visualStock.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (visualStock <= 0)
                        const Positioned(
                          bottom: -2,
                          child: Icon(
                            Icons.block,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(product.name)),
                      if (isQueued)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Queued',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<double>(
                        future: TaxService.calculateSellingPriceWithRule(
                          product.cost,
                          productId: product.id,
                          categoryName: product.category,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              'Price: ${CurrencyUtils.formatCurrency(snapshot.data!)}',
                            );
                          }
                          return const Text('Price: Calculating...');
                        },
                      ),
                      Text(
                        'Stock: $visualStock',
                        style: TextStyle(
                          color: visualStock > 0 ? Colors.black54 : Colors.red,
                        ),
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
                            builder: (context) =>
                                PriceHistoryDialog(productId: product.id!),
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
