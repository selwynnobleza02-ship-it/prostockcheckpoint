import 'package:flutter/material.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';
import '../utils/constants.dart';

class BarcodeProductDialog extends StatefulWidget {
  final String barcode;

  const BarcodeProductDialog({super.key, required this.barcode});

  @override
  State<BarcodeProductDialog> createState() => _BarcodeProductDialogState();
}

class _BarcodeProductDialogState extends State<BarcodeProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');

  String _selectedCategory = AppConstants.productCategories.first;
  bool _isLoading = false;
  bool _showSuccess = false;

  final List<String> _categories = AppConstants.productCategories;

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true, // Added to make the dialog content scrollable
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add New Product'),
          const SizedBox(height: 4),
          Text(
            'Barcode: ${widget.barcode}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      content: _showSuccess ? _buildSuccessContent() : _buildFormContent(),
      actions: _showSuccess ? _buildSuccessActions() : _buildFormActions(),
    );
  }

  Widget _buildSuccessContent() {
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final price = cost * (1 + AppConstants.taxRate);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Product Added Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '"${_nameController.text}" has been added to your inventory.',
                  style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Initial Stock:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text('${_stockController.text}pcs'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Selling Price:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text('₱${price.toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              isExpanded: true, // Added to allow the dropdown to expand
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    overflow: TextOverflow.ellipsis, // Handle long text
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Cost Row
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cost Price *',
                border: OutlineInputBorder(),
                prefixText: '₱ ',
                prefixIcon: Icon(Icons.local_mall),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter cost';
                }
                final cost = double.tryParse(value);
                if (cost == null || cost < 0) {
                  return 'Enter valid cost';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Stock and Min Stock Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Initial Stock *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                      suffixText: 'pcs',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter stock';
                      }
                      final stock = int.tryParse(value);
                      if (stock == null || stock < 0) {
                        return 'Enter valid stock';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Stock Alert',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning),
                      suffixText: 'pcs',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }
                      final minStock = int.tryParse(value);
                      if (minStock == null || minStock < 0) {
                        return 'Enter valid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Profit Margin Display
            Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                final cost = double.tryParse(_costController.text) ?? 0;
                final price = cost * (1 + AppConstants.taxRate);
                final profit = price - cost;
                final margin = cost > 0 ? (profit / cost * 100) : 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: margin > 20
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: margin > 20 ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selling Price',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('₱${price.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          const Text(
                            'Profit Margin',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₱${profit.toStringAsFixed(2)} (${margin.toStringAsFixed(1)}%)',
                          ),
                        ],
                      ),
                      Icon(
                        margin > 20 ? Icons.trending_up : Icons.warning,
                        color: margin > 20 ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormActions() {
    return [
      TextButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _saveProduct,
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Add Product'),
      ),
    ];
  }

  List<Widget> _buildSuccessActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('View Inventory'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('Done'),
      ),
    ];
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final product = Product(
        name: _nameController.text.trim(),
        barcode: widget.barcode,
        cost: double.parse(_costController.text),
        stock: int.parse(_stockController.text),
        minStock: int.tryParse(_minStockController.text) ?? 5,
        category: _selectedCategory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final newProduct = await Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).addProduct(product);

      if (newProduct != null && mounted) {
        setState(() {
          _isLoading = false;
          _showSuccess = true;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _showSuccess) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e, s) {
      ErrorLogger.logError(
        'Error adding product from barcode',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error Adding Product'),
              ],
            ),
            content: Text(
              'Failed to add product: $e\n\nPlease check your input and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
