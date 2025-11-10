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
              final colorScheme = Theme.of(context).colorScheme;
              final textTheme = Theme.of(context).textTheme;

              // Determine stock status colors using theme
              final bool isOutOfStock = visualStock <= 0;
              final bool isLowStock = product.isLowStock && !isOutOfStock;

              Color stockAvatarColor;
              if (isOutOfStock) {
                stockAvatarColor = colorScheme.errorContainer;
              } else if (isLowStock) {
                stockAvatarColor = colorScheme.tertiaryContainer;
              } else {
                stockAvatarColor = colorScheme.primaryContainer;
              }

              Color stockAvatarTextColor;
              if (isOutOfStock) {
                stockAvatarTextColor = colorScheme.onErrorContainer;
              } else if (isLowStock) {
                stockAvatarTextColor = colorScheme.onTertiaryContainer;
              } else {
                stockAvatarTextColor = colorScheme.onPrimaryContainer;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: isOutOfStock ? 0 : 1,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AddProductDialog(product: product),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stock Avatar
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: stockAvatarColor,
                              child: Text(
                                visualStock.toString(),
                                style: textTheme.titleMedium?.copyWith(
                                  color: stockAvatarTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isOutOfStock)
                              Positioned(
                                bottom: 0,
                                child: Icon(
                                  Icons.block,
                                  color: colorScheme.error,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Main Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Name
                              Text(
                                product.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),

                              // Price
                              FutureBuilder<double>(
                                future:
                                    TaxService.calculateSellingPriceWithRule(
                                      product.cost,
                                      productId: product.id,
                                      categoryName: product.category,
                                    ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Text(
                                      CurrencyUtils.formatCurrency(
                                        snapshot.data!,
                                      ),
                                      style: textTheme.titleSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }
                                  return Text(
                                    'Calculating...',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 8),

                              // Chips and Tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (isQueued)
                                    Chip(
                                      label: const Text('Queued'),
                                      labelStyle: textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                      backgroundColor:
                                          colorScheme.secondaryContainer,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if (isLowStock)
                                    Chip(
                                      avatar: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: colorScheme.onTertiaryContainer,
                                      ),
                                      label: const Text('Low Stock'),
                                      labelStyle: textTheme.labelSmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onTertiaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      backgroundColor:
                                          colorScheme.tertiaryContainer,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if (isOutOfStock)
                                    Chip(
                                      avatar: Icon(
                                        Icons.remove_circle_outline,
                                        size: 16,
                                        color: colorScheme.onErrorContainer,
                                      ),
                                      label: const Text('Out of Stock'),
                                      labelStyle: textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onErrorContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      backgroundColor:
                                          colorScheme.errorContainer,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if (product.category != null &&
                                      product.category!.isNotEmpty)
                                    Chip(
                                      label: Text(product.category!),
                                      labelStyle: textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),

                              // Barcode (if exists)
                              if (product.barcode != null &&
                                  product.barcode!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      product.barcode!,
                                      style: textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // History Button
                        IconButton(
                          icon: const Icon(Icons.history),
                          tooltip: 'Price History',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  PriceHistoryDialog(productId: product.id!),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
