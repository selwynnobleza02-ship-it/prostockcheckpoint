import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_batch.dart';
import '../utils/currency_utils.dart';

class BatchSelectionDialog extends StatefulWidget {
  final List<InventoryBatch> batches;
  final String productName;
  final int
  maxQuantity; // Maximum quantity that can be removed across all batches

  const BatchSelectionDialog({
    super.key,
    required this.batches,
    required this.productName,
    required this.maxQuantity,
  });

  @override
  State<BatchSelectionDialog> createState() => _BatchSelectionDialogState();
}

class _BatchSelectionDialogState extends State<BatchSelectionDialog> {
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, int> _selectedQuantities = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each batch
    for (final batch in widget.batches) {
      _quantityControllers[batch.id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalSelected {
    return _selectedQuantities.values.fold(0, (sum, qty) => sum + qty);
  }

  void _updateQuantity(String batchId, String value) {
    setState(() {
      final qty = int.tryParse(value) ?? 0;
      if (qty > 0) {
        _selectedQuantities[batchId] = qty;
      } else {
        _selectedQuantities.remove(batchId);
      }
      _errorMessage = null;
    });
  }

  bool _validateSelection() {
    if (_selectedQuantities.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one batch';
      });
      return false;
    }

    // Check if any batch exceeds its available quantity
    for (final entry in _selectedQuantities.entries) {
      final batch = widget.batches.firstWhere((b) => b.id == entry.key);
      if (entry.value > batch.quantityRemaining) {
        setState(() {
          _errorMessage =
              'Batch ${batch.batchNumber}: Cannot remove ${entry.value} units. Only ${batch.quantityRemaining} available.';
        });
        return false;
      }
    }

    // Check if total doesn't exceed max
    if (_totalSelected > widget.maxQuantity) {
      setState(() {
        _errorMessage =
            'Total quantity ($_totalSelected) exceeds available stock (${widget.maxQuantity})';
      });
      return false;
    }

    return true;
  }

  void _confirm() {
    if (_validateSelection()) {
      Navigator.of(context).pop(_selectedQuantities);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Sort batches by date (FIFO - oldest first)
    final sortedBatches = List<InventoryBatch>.from(widget.batches)
      ..sort((a, b) => a.dateReceived.compareTo(b.dateReceived));

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select Batches to Remove',
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.productName,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Selected: ', style: textTheme.bodySmall),
                        Text(
                          '$_totalSelected / ${widget.maxQuantity}',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _totalSelected > widget.maxQuantity
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Batch List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedBatches.length,
                itemBuilder: (context, index) {
                  final batch = sortedBatches[index];
                  final isActive = batch.hasStock;
                  final controller = _quantityControllers[batch.id]!;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isActive ? 2 : 1,
                    color: isActive
                        ? null
                        : colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Batch Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? colorScheme.primaryContainer
                                      : colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Batch ${index + 1}',
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'DEPLETED',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Batch Info
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow(
                                      'Received',
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(batch.dateReceived),
                                      textTheme,
                                    ),
                                    const SizedBox(height: 4),
                                    _buildInfoRow(
                                      'Cost',
                                      CurrencyUtils.formatCurrency(
                                        batch.unitCost,
                                      ),
                                      textTheme,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow(
                                      'Available',
                                      '${batch.quantityRemaining} units',
                                      textTheme,
                                    ),
                                    const SizedBox(height: 4),
                                    _buildInfoRow(
                                      'Value',
                                      CurrencyUtils.formatCurrency(
                                        batch.totalValue,
                                      ),
                                      textTheme,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (isActive) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Quantity Input
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Quantity to Remove',
                                      hintText: '0',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      suffixText:
                                          '/ ${batch.quantityRemaining}',
                                      labelStyle: const TextStyle(fontSize: 12),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                    onChanged: (value) =>
                                        _updateQuantity(batch.id, value),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 1,
                                  child: IconButton.filled(
                                    onPressed: () {
                                      controller.text = batch.quantityRemaining
                                          .toString();
                                      _updateQuantity(
                                        batch.id,
                                        batch.quantityRemaining.toString(),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.all_inclusive,
                                      size: 18,
                                    ),
                                    tooltip: 'Select All',
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          colorScheme.primaryContainer,
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    child: const Text('Remove Selected'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, TextTheme textTheme) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
