import 'package:flutter/material.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/widgets/expandable_product_card.dart';
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
                backgroundColor: Theme.of(context).colorScheme.error,
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

              return ExpandableProductCard(
                product: product,
                visualStock: visualStock,
                isQueued: isQueued,
                provider: provider,
              );
            },
          ),
        );
      },
    );
  }
}
