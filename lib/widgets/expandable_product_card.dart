import 'package:flutter/material.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/inventory_batch.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/add_product_dialog.dart';
import 'package:prostock/widgets/price_history_dialog.dart';
import 'package:prostock/widgets/batch_list_widget.dart';
import 'package:prostock/services/tax_service.dart';

class ExpandableProductCard extends StatefulWidget {
  final Product product;
  final int visualStock;
  final bool isQueued;
  final InventoryProvider provider;

  const ExpandableProductCard({
    super.key,
    required this.product,
    required this.visualStock,
    required this.isQueued,
    required this.provider,
  });

  @override
  State<ExpandableProductCard> createState() => _ExpandableProductCardState();
}

class _ExpandableProductCardState extends State<ExpandableProductCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isOutOfStock = widget.visualStock <= 0;
    final bool isLowStock = widget.product.isLowStock && !isOutOfStock;

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
      child: Column(
        children: [
          // Main Product Card
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AddProductDialog(product: widget.product),
              );
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
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
                          widget.visualStock.toString(),
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
                          widget.product.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Price
                        FutureBuilder<double>(
                          future: widget.provider
                              .getNextBatchCost(widget.product.id!)
                              .then(
                                (cost) =>
                                    TaxService.calculateSellingPriceWithRule(
                                      cost,
                                      productId: widget.product.id,
                                      categoryName: widget.product.category,
                                    ),
                              ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                CurrencyUtils.formatCurrency(snapshot.data!),
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
                            if (widget.isQueued)
                              Chip(
                                label: const Text('Queued'),
                                labelStyle: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                backgroundColor: colorScheme.secondaryContainer,
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
                                labelStyle: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: colorScheme.tertiaryContainer,
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
                                labelStyle: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: colorScheme.errorContainer,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (widget.product.category != null &&
                                widget.product.category!.isNotEmpty)
                              Chip(
                                label: Text(widget.product.category!),
                                labelStyle: textTheme.labelSmall?.copyWith(
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
                        if (widget.product.barcode != null &&
                            widget.product.barcode!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.product.barcode!,
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
                            PriceHistoryDialog(productId: widget.product.id!),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Expandable Batch Section
          FutureBuilder<List<InventoryBatch>>(
            future: widget.provider.getBatchesForProduct(widget.product.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final batches = snapshot.data!;
              final batchCount = batches.length;
              final activeBatchCount = batches.where((b) => b.hasStock).length;

              return Column(
                children: [
                  // Expand/Collapse Button
                  InkWell(
                    onTap: _toggleExpanded,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: _isExpanded
                            ? null
                            : const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isExpanded
                                  ? 'Hide Batches'
                                  : 'View $activeBatchCount Batch${activeBatchCount != 1 ? 'es' : ''}',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$batchCount total',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expanded Content
                  if (_isExpanded)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Stock Batches',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(Oldest to Newest)',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BatchListWidget(batches: batches, showDepleted: true),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(
                                0.3,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Average Cost:',
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  CurrencyUtils.formatCurrency(
                                    widget.product.cost,
                                  ),
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
