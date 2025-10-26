import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/inventory_provider.dart';

class ReceiveStockDialog extends StatefulWidget {
  final Product product;

  const ReceiveStockDialog({super.key, required this.product});

  @override
  ReceiveStockDialogState createState() => ReceiveStockDialogState();
}

class ReceiveStockDialogState extends State<ReceiveStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _costController.text = widget.product.cost.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Receive Stock for ${widget.product.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity Received',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a quantity';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter a valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'New Cost Price',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a cost price';
                }
                if (double.tryParse(value) == null || double.parse(value) < 0) {
                  return 'Please enter a valid cost price';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Receive')),
      ],
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final quantity = int.parse(_quantityController.text);
      final newCost = double.parse(_costController.text);

      // Get current batch information
      final inventoryProvider = context.read<InventoryProvider>();
      final batches = await inventoryProvider.getBatchesForProduct(
        widget.product.id!,
      );

      final currentStock = widget.product.stock;
      final totalQuantity = currentStock + quantity;

      // Calculate what the average cost will be
      final totalValue =
          (currentStock * widget.product.cost) + (quantity * newCost);
      final averageCost = totalQuantity > 0
          ? totalValue / totalQuantity
          : newCost;

      // Confirm action with the user before applying changes
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Stock Receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product: ${widget.product.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text('Quantity to receive: $quantity units'),
                Text('Batch cost: ₱${newCost.toStringAsFixed(2)} per unit'),
                const SizedBox(height: 16),
                if (batches.isNotEmpty) ...[
                  const Text(
                    'Current Batches (FIFO Order):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...batches
                      .take(3)
                      .map(
                        (batch) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 2),
                          child: Text(
                            '• ${batch.batchNumber}: ${batch.quantityRemaining} units @ ₱${batch.unitCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                  if (batches.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '... and ${batches.length - 3} more batch(es)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'After Receiving:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Stock:',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '$totalQuantity units',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Batches:',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${batches.length + 1}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Average Cost:',
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            '₱${averageCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This will create a new batch. Sales will use FIFO (oldest batch first).',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Receive Stock'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      if (!mounted) return;

      // Call the receiveStockWithCost method that creates a batch
      final success = await inventoryProvider.receiveStockWithCost(
        widget.product.id!,
        quantity,
        newCost,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock received: $quantity units added to new batch'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        // Show error if failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inventoryProvider.error ?? 'Failed to receive stock'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
