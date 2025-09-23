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

      // Confirm action with the user before applying changes
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Stock Receive'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${widget.product.name}'),
              const SizedBox(height: 8),
              Text('Quantity to receive: $quantity'),
              const SizedBox(height: 8),
              Text('New cost price: $newCost'),
              const SizedBox(height: 8),
              Text('Current stock: ${widget.product.stock}'),
              const SizedBox(height: 8),
              Text('Resulting stock: ${widget.product.stock + quantity}'),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to receive this stock?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm Receive'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      final inventoryProvider = context.read<InventoryProvider>();

      // Create a copy of the product with the new cost
      final productWithNewCost = widget.product.copyWith(cost: newCost);

      // First, update the product with the new cost
      await inventoryProvider.updateProduct(productWithNewCost);

      // Then, call receiveStock to handle the stock movement
      await inventoryProvider.receiveStock(widget.product.id!, quantity);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }
}
