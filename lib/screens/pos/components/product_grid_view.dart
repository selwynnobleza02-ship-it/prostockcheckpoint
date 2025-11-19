import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/services/tax_service.dart';

class ProductGridView extends StatelessWidget {
  const ProductGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(UiConstants.spacingMedium),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading products...'),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        if (provider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.error!),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: () {
                    provider.loadProducts(refresh: true);
                  },
                ),
              ),
            );
            provider.clearError();
          });
        }

        final productsToDisplay = provider.products;

        if (productsToDisplay.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(UiConstants.spacingMedium),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or add new products',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.loadProducts(refresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(UiConstants.spacingMedium),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: UiConstants.spacingSmall,
            mainAxisSpacing: UiConstants.spacingSmall,
            childAspectRatio: 0.8,
          ),
          itemCount: productsToDisplay.length,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final product = productsToDisplay[index];
            final isQueued = !provider.isOnline;
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            // Use FutureBuilder to get batch-based stock asynchronously
            return FutureBuilder<int>(
              future: provider.getVisualStock(product.id!),
              builder: (context, stockSnapshot) {
                final visualStock =
                    stockSnapshot.data ??
                    provider.getVisualStockSync(product.id!);
                final isOutOfStock = visualStock <= 0;
                final isLowStock = product.isLowStock && !isOutOfStock;

                // Determine stock status colors
                Color stockBadgeColor;
                Color stockBadgeTextColor;
                if (isOutOfStock) {
                  stockBadgeColor = colorScheme.errorContainer;
                  stockBadgeTextColor = colorScheme.onErrorContainer;
                } else if (isLowStock) {
                  stockBadgeColor = colorScheme.tertiaryContainer;
                  stockBadgeTextColor = colorScheme.onTertiaryContainer;
                } else {
                  stockBadgeColor = colorScheme.primaryContainer;
                  stockBadgeTextColor = colorScheme.onPrimaryContainer;
                }

                return Card(
                  elevation: isOutOfStock ? 0 : 1,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: isOutOfStock
                        ? null
                        : () async {
                            await Provider.of<SalesProvider>(
                              context,
                              listen: false,
                            ).addItemToCurrentSale(product, 1);
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Main content with opacity for out-of-stock
                        Opacity(
                          opacity: isOutOfStock ? 0.5 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon/Image area with stock badge
                                Expanded(
                                  flex: 3,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainer,
                                          borderRadius: BorderRadius.circular(
                                            UiConstants.borderRadiusStandard,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory,
                                          size: 32,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      // Stock count badge on icon
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: stockBadgeColor,
                                          child: Text(
                                            visualStock.toString(),
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: stockBadgeTextColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Product name
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    product.name,
                                    style: textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Price
                                FutureBuilder<double>(
                                  future: provider
                                      .getNextBatchCost(product.id!)
                                      .then(
                                        (cost) =>
                                            TaxService.calculateSellingPriceWithRule(
                                              cost,
                                              productId: product.id,
                                              categoryName: product.category,
                                            ),
                                      ),
                                  builder: (context, snapshot) {
                                    final price = snapshot.data;
                                    return Text(
                                      price != null
                                          ? CurrencyUtils.formatCurrency(price)
                                          : '...',
                                      style: textTheme.labelLarge?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Status badges overlay
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Batch indicator badge
                              FutureBuilder<List<dynamic>>(
                                future: provider.getBatchesForProduct(
                                  product.id!,
                                ),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  final batches = snapshot.data!;
                                  final activeBatchCount = batches
                                      .where((b) => b.quantityRemaining > 0)
                                      .length;

                                  // Only show if there are multiple batches
                                  if (activeBatchCount <= 1) {
                                    return const SizedBox.shrink();
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.layers,
                                          size: 10,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$activeBatchCount',
                                          style: textTheme.labelSmall?.copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (isQueued)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.outline.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Queued',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              if (isOutOfStock)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.error.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.remove_circle_outline,
                                        size: 10,
                                        color: colorScheme.onErrorContainer,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Out',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onErrorContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isLowStock)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.tertiary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 10,
                                        color: colorScheme.onTertiaryContainer,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Low',
                                        style: textTheme.labelSmall?.copyWith(
                                          color:
                                              colorScheme.onTertiaryContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
