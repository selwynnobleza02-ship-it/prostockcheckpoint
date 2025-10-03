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
                backgroundColor: Colors.red,
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
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or add new products',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
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
            final visualStock = provider.getVisualStock(product.id!);
            final isOutOfStock = visualStock <= 0;
            final isQueued = !provider.isOnline;
            return Card(
              child: InkWell(
                onTap: () async {
                  if (!isOutOfStock) {
                    await Provider.of<SalesProvider>(
                      context,
                      listen: false,
                    ).addItemToCurrentSale(product, 1);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(UiConstants.spacingSmall),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  UiConstants.borderRadiusStandard,
                                ),
                              ),
                              child: Icon(
                                Icons.inventory,
                                size: UiConstants.iconSizeMedium,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: UiConstants.spacingSmall),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: UiConstants.fontSizeSmall,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FutureBuilder<double>(
                            future: TaxService.calculateSellingPriceWithRule(
                              product.cost,
                              productId: product.id,
                              categoryName: product.category,
                            ),
                            builder: (context, snapshot) {
                              final price = snapshot.data;
                              return Text(
                                price != null
                                    ? CurrencyUtils.formatCurrency(price)
                                    : 'Calculating...',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: UiConstants.fontSizeSmall,
                                ),
                              );
                            },
                          ),
                          Text(
                            'Stock: $visualStock',
                            style: TextStyle(
                              color: visualStock > 0
                                  ? Colors.grey[600]
                                  : Colors.red,
                              fontSize: UiConstants.fontSizeExtraSmall,
                            ),
                          ),
                        ],
                      ),
                      if (isOutOfStock)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Out of stock',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onError,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      if (isQueued)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[700],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Queued',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
