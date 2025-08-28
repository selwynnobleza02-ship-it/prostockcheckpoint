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

      final inventoryProvider = context.read<InventoryProvider>();

      final newStock = widget.product.stock + quantity;
      final updatedProduct = widget.product.copyWith(
        stock: newStock,
        cost: newCost,
        updatedAt: DateTime.now(),
      );

      await inventoryProvider.updateProduct(updatedProduct);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }
}
