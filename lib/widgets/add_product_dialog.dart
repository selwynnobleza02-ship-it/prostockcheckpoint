import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
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

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Product'),
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
                  value: _selectedCategory,
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
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Price and Cost Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Selling Price *',
                          border: OutlineInputBorder(),
                          prefixText: '₱ ', // Philippine Peso symbol
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter price';
                          }
                          final price = double.tryParse(value.trim());
                          if (price == null || price <= 0) {
                            return 'Enter valid price';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(
                            () {},
                          ); // Trigger profit margin recalculation
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
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
                          setState(
                            () {},
                          ); // Trigger profit margin recalculation
                        },
                      ),
                    ),
                  ],
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
              : const Text('Add Product'),
        ),
      ],
    );
  }

  Widget _buildProfitMarginDisplay() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final profit = price - cost;
    final margin = cost > 0 ? (profit / cost * 100) : 0;

    // Only show if both price and cost have values
    if (price == 0 && cost == 0) {
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
      // Safely parse the values using tryParse to avoid FormatException
      final price = double.tryParse(_priceController.text.trim());
      final cost = double.tryParse(_costController.text.trim());
      final stock = int.tryParse(_stockController.text.trim());
      final minStock = int.tryParse(_minStockController.text.trim()) ?? 5;

      // Double-check parsed values (should be caught by validation, but just in case)
      if (price == null || cost == null || stock == null) {
        throw const FormatException('Invalid number format');
      }

      // Handle barcode - can be null or empty
      final barcode = _barcodeController.text.trim();
      final finalBarcode = barcode.isEmpty ? null : barcode;

      final product = Product(
        name: _nameController.text.trim(),
        barcode: finalBarcode,
        price: price,
        cost: cost,
        stock: stock,
        minStock: minStock,
        category: _selectedCategory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Call addProduct - assumes it returns void and throws on error
      await Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).addProduct(product);

      // If we reach here, the product was added successfully
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "${product.name}" added successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to inventory screen
                // You can add navigation logic here
              },
            ),
          ),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid number format. Please check your inputs.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on ArgumentError catch (e) {
      // Catch ArgumentError from model validation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Input Error: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error adding product';

        // Provide more specific error messages based on common issues
        if (e.toString().contains('already exists')) {
          errorMessage = 'Product with this name or barcode already exists.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'An unexpected error occurred: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _saveProduct,
            ),
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
