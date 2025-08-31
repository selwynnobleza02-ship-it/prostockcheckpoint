import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/currency_utils.dart';

class ProductGridView extends StatelessWidget {
  const ProductGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.error!),
                backgroundColor: Colors.red,
              ),
            );
            provider.clearError();
          });
        }

        final productsToDisplay = provider.products;

        if (productsToDisplay.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(UiConstants.spacingMedium),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: UiConstants.spacingSmall,
            mainAxisSpacing: UiConstants.spacingSmall,
            childAspectRatio: 0.9,
          ),
          itemCount: productsToDisplay.length,
          itemBuilder: (context, index) {
            final product = productsToDisplay[index];
            return Card(
              child: InkWell(
                onTap: () {
                  if (product.stock > 0) {
                    Provider.of<SalesProvider>(
                      context,
                      listen: false,
                    ).addItemToCurrentSale(product, 1);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(UiConstants.spacingSmall),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(
                              UiConstants.borderRadiusStandard,
                            ),
                          ),
                          child: const Icon(
                            Icons.inventory,
                            size: UiConstants.iconSizeMedium,
                            color: Colors.grey,
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
                      Text(
                        CurrencyUtils.formatCurrency(product.price),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: UiConstants.fontSizeSmall,
                        ),
                      ),
                      Text(
                        'Stock: ${product.stock}',
                        style: TextStyle(
                          color: product.stock > 0
                              ? Colors.grey[600]
                              : Colors.red,
                          fontSize: UiConstants.fontSizeExtraSmall,
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
