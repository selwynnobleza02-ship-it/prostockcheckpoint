import 'package:flutter/material.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';
import '../utils/constants.dart';

class AddProductDialog extends StatefulWidget {
  final Product? product;
  const AddProductDialog({super.key, this.product});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController(text: '5');

  String _selectedCategory = 'General';
  bool _isLoading = false;

  final List<String> _categories = [
    'General',
    'Food & Beverages',
    'Personal Care',
    'Household Items',
    'Electronics',
    'Clothing',
    'Health & Medicine',
    'Office Supplies',
  ];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final product = widget.product!;
      _nameController.text = product.name;
      _barcodeController.text = product.barcode ?? '';
      _costController.text = product.cost.toString();
      _stockController.text = product.stock.toString();
      _minStockController.text = product.minStock.toString();
      _selectedCategory = product.category!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Product' : 'Add New Product'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
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

                // Barcode (Optional)
                TextFormField(
                  controller: _barcodeController,
                  readOnly: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                    helperText: 'Leave empty if no barcode',
                  ),
                  validator: (value) {
                    // Optional validation for barcode format if needed
                    if (value != null && value.trim().isNotEmpty) {
                      // Add any barcode format validation here if needed
                      if (value.trim().length < 8) {
                        return 'Barcode must be at least 8 characters';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: _isEditing
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                ),
                const SizedBox(height: 16),

                // Cost Row
                TextFormField(
                  controller: _costController,
                  readOnly: _isEditing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cost Price *',
                    border: OutlineInputBorder(),
                    prefixText: '₱ ', // Philippine Peso symbol
                    prefixIcon: Icon(Icons.money_off),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter cost';
                    }
                    final cost = double.tryParse(value.trim());
                    if (cost == null || cost < 0) {
                      return 'Enter valid cost';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {}); // Trigger profit margin recalculation
                  },
                ),
                const SizedBox(height: 16),

                // Stock and Min Stock Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        readOnly: _isEditing,
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
                          final stock = int.tryParse(value.trim());
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
                        readOnly: _isEditing,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Stock Alert',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.warning),
                          suffixText: 'pcs',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null; // Optional field
                          }
                          final minStock = int.tryParse(value.trim());
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
                _buildProfitMarginDisplay(),
              ],
            ),
          ),
        ),
      ),
      actions: [
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
              : Text(_isEditing ? 'Save Changes' : 'Add Product'),
        ),
      ],
    );
  }

  Widget _buildProfitMarginDisplay() {
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final price = cost * (1 + AppConstants.taxRate);
    final profit = price - cost;
    final margin = cost > 0 ? (profit / cost * 100) : 0;

    // Only show if both price and cost have values
    if (cost == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: margin > 20 ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: margin > 20 ? Colors.green : Colors.orange),
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
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final cost = double.parse(_costController.text.trim());
      final stock = int.parse(_stockController.text.trim());
      final minStock = int.tryParse(_minStockController.text.trim()) ?? 5;
      final barcode = _barcodeController.text.trim();
      final finalBarcode = barcode.isEmpty ? null : barcode;

      if (_isEditing) {
        // Update existing product
        final updatedProduct = widget.product!.copyWith(
          name: _nameController.text.trim(),
          barcode: finalBarcode,
          cost: cost,
          stock: stock,
          minStock: minStock,
          category: _selectedCategory,
          updatedAt: DateTime.now(),
        );
        await inventoryProvider.updateProduct(updatedProduct);
        if (mounted) {
          Navigator.pop(context, updatedProduct);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${updatedProduct.name}" updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Add new product
        final product = Product(
          name: _nameController.text.trim(),
          barcode: finalBarcode,
          cost: cost,
          stock: stock,
          minStock: minStock,
          category: _selectedCategory,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final newProduct = await inventoryProvider.addProduct(product);
        if (mounted) {
          Navigator.pop(context, newProduct);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${product.name}" added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, s) {
      ErrorLogger.logError('Error saving product', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
