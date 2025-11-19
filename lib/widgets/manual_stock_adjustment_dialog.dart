import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/loss_reason.dart';
import '../models/inventory_batch.dart';
import '../providers/inventory_provider.dart';
import '../utils/currency_utils.dart';
import '../services/tax_service.dart';
import 'batch_selection_dialog.dart';

enum StockAdjustmentType { receive, remove }

class ManualStockAdjustmentDialog extends StatefulWidget {
  final StockAdjustmentType type;

  const ManualStockAdjustmentDialog({super.key, required this.type});

  @override
  State<ManualStockAdjustmentDialog> createState() =>
      _ManualStockAdjustmentDialogState();
}

class _ManualStockAdjustmentDialogState
    extends State<ManualStockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _searchController = TextEditingController();

  Product? _selectedProduct;
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String? _selectedReason = 'Damage'; // Default to match barcode scanner

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _filterProducts(); // Initial load

    // Set initial cost price if product is provided (for receive stock)
    if (widget.type == StockAdjustmentType.receive) {
      _costController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final inventoryProvider = context.read<InventoryProvider>();
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredProducts = inventoryProvider.products
          .where(
            (product) =>
                product.name.toLowerCase().contains(query) ||
                product.barcode?.toLowerCase().contains(query) == true,
          )
          .toList();
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
    });
    _searchController.text = product.name;

    // Set cost price for receive stock
    if (widget.type == StockAdjustmentType.receive) {
      _costController.text = product.cost.toString();
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProduct = null;
    });
    _searchController.clear();
  }

  void _showErrorSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      _showErrorSnackBar('Please select a product');
      return;
    }

    final quantity = int.parse(_quantityController.text);
    final costPrice = widget.type == StockAdjustmentType.receive
        ? double.parse(_costController.text)
        : null;
    final reason = widget.type == StockAdjustmentType.remove
        ? _selectedReason ?? 'Manual removal'
        : 'Restocking';

    if (quantity <= 0) {
      _showErrorSnackBar('Quantity must be greater than zero');
      return;
    }

    // For remove operations, check if enough stock is available
    if (widget.type == StockAdjustmentType.remove) {
      if (_selectedProduct!.stock < quantity) {
        _showErrorSnackBar(
          'Insufficient stock. Available: ${_selectedProduct!.stock}',
        );
        return;
      }
    }

    // For Damage/Expired, show batch selection FIRST before confirmation
    Map<String, int>? selectedBatches;
    if (widget.type == StockAdjustmentType.remove &&
        (_selectedReason == 'Damage' || _selectedReason == 'Expired')) {
      final inventoryProvider = context.read<InventoryProvider>();
      final batches = await inventoryProvider.getBatchesForProduct(
        _selectedProduct!.id!,
      );

      if (batches.isEmpty) {
        if (!mounted) return;
        _showErrorSnackBar('No batches found for this product');
        return;
      }

      // Show batch selection dialog FIRST
      if (!mounted) return;
      selectedBatches = await showDialog<Map<String, int>>(
        context: context,
        builder: (context) => BatchSelectionDialog(
          batches: batches,
          productName: _selectedProduct!.name,
          maxQuantity: _selectedProduct!.stock,
        ),
      );

      // User cancelled batch selection
      if (selectedBatches == null || selectedBatches.isEmpty) {
        return;
      }
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.type == StockAdjustmentType.receive
              ? 'Confirm Stock Receipt'
              : 'Confirm Stock Removal',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${_selectedProduct!.name}'),
            const SizedBox(height: 8),
            if (selectedBatches != null) ...[
              const Text(
                'Selected batches:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...selectedBatches.entries.map((entry) {
                final batch = context
                    .read<InventoryProvider>()
                    .getBatchesForProduct(_selectedProduct!.id!)
                    .then(
                      (batches) => batches.firstWhere((b) => b.id == entry.key),
                    );
                return FutureBuilder(
                  future: batch,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        '  • ${snapshot.data!.batchNumber}: ${entry.value} units',
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Total to remove: ${selectedBatches.values.fold<int>(0, (sum, qty) => sum + qty)} units',
              ),
            ] else
              Text(
                widget.type == StockAdjustmentType.receive
                    ? 'Quantity to receive: $quantity'
                    : 'Quantity to remove: $quantity',
              ),
            const SizedBox(height: 8),
            if (widget.type == StockAdjustmentType.receive &&
                costPrice != null) ...[
              Text('Cost price: ₱${costPrice.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
            ],
            Text('Current stock: ${_selectedProduct!.stock}'),
            const SizedBox(height: 8),
            Text(
              widget.type == StockAdjustmentType.receive
                  ? 'Resulting stock: ${_selectedProduct!.stock + quantity}'
                  : 'Resulting stock: ${_selectedProduct!.stock - (selectedBatches?.values.fold<int>(0, (sum, qty) => sum + qty) ?? quantity)}',
            ),
            if (widget.type == StockAdjustmentType.remove) ...[
              const SizedBox(height: 8),
              Text('Reason: $reason'),
            ],
            const SizedBox(height: 16),
            Text(
              widget.type == StockAdjustmentType.receive
                  ? 'Are you sure you want to receive this stock?'
                  : 'Are you sure you want to remove this stock?',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.type == StockAdjustmentType.receive
                  ? Colors.green
                  : Colors.red,
            ),
            child: Text(
              widget.type == StockAdjustmentType.receive
                  ? 'Confirm Receive'
                  : 'Confirm Remove',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final inventoryProvider = context.read<InventoryProvider>();
      bool success;

      if (widget.type == StockAdjustmentType.receive) {
        // Use receiveStockWithCost to properly create batches with specific costs
        final effectiveCost = costPrice ?? _selectedProduct!.cost;
        success = await inventoryProvider.receiveStockWithCost(
          _selectedProduct!.id!,
          quantity,
          effectiveCost,
          notes: 'Manual stock receipt',
        );
      } else {
        // Handle different removal reasons
        if (selectedBatches != null) {
          // Use the already-selected batches from earlier dialog
          final lossReason = _selectedReason == 'Damage'
              ? LossReason.damaged
              : LossReason.expired;

          success = await inventoryProvider.addLossFromBatches(
            productId: _selectedProduct!.id!,
            batchQuantities: selectedBatches,
            reason: lossReason,
          );
        } else {
          // For "Miss stock" and other reasons, just reduce stock using FIFO
          success = await inventoryProvider.reduceStock(
            _selectedProduct!.id!,
            quantity,
            reason: reason,
          );
        }
      }

      if (!mounted) return;

      if (success) {
        if (mounted) {
          _showSuccessSnackBar(
            widget.type == StockAdjustmentType.receive
                ? 'Stock received successfully'
                : 'Stock removed successfully',
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(
            inventoryProvider.error ?? 'Failed to update stock',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.type == StockAdjustmentType.receive
            ? 'Manual Stock Receipt'
            : 'Manual Stock Removal',
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Search
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Product',
                    hintText: 'Type product name or barcode',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _selectedProduct != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSelection,
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_selectedProduct == null) {
                      return 'Please select a product';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Product Selection Dropdown
                if (_searchController.text.isNotEmpty &&
                    _filteredProducts.isNotEmpty)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ListTile(
                          title: Text(
                            product.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: FutureBuilder<double>(
                            future: TaxService.calculateSellingPriceWithRule(
                              product.cost,
                              productId: product.id,
                              categoryName: product.category,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Text(
                                  'Stock: ${product.stock} | Price: ${CurrencyUtils.formatCurrency(snapshot.data!)}',
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              return Text(
                                'Stock: ${product.stock} | Price: Calculating...',
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          trailing: Text(
                            product.barcode ?? 'No barcode',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectProduct(product),
                        );
                      },
                    ),
                  ),

                // Selected Product Display
                if (_selectedProduct != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Selected Product',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Name: ${_selectedProduct!.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Current Stock: ${_selectedProduct!.stock}'),
                        FutureBuilder<double>(
                          future: TaxService.calculateSellingPriceWithRule(
                            _selectedProduct!.cost,
                            productId: _selectedProduct!.id,
                            categoryName: _selectedProduct!.category,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                'Price: ${CurrencyUtils.formatCurrency(snapshot.data!)}',
                              );
                            }
                            return const Text('Price: Calculating...');
                          },
                        ),
                        if (_selectedProduct!.barcode != null)
                          Text(
                            'Barcode: ${_selectedProduct!.barcode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Quantity Input
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: const OutlineInputBorder(),
                    suffixText: 'units',
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

                // Cost Price Input (for receive stock only)
                if (widget.type == StockAdjustmentType.receive) ...[
                  TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'New Cost Price',
                      border: OutlineInputBorder(),
                      prefixText: '₱ ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a cost price';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) < 0) {
                        return 'Please enter a valid cost price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Reason Dropdown (for remove stock only)
                if (widget.type == StockAdjustmentType.remove) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedReason,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Damage', child: Text('Damage')),
                      DropdownMenuItem(
                        value: 'Expired',
                        child: Text('Expired'),
                      ),
                      DropdownMenuItem(
                        value: 'Miss stock',
                        child: Text('Miss stock'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedReason = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a reason';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.type == StockAdjustmentType.receive
                ? Colors.green
                : Colors.red,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.type == StockAdjustmentType.receive
                      ? 'Receive Stock'
                      : 'Remove Stock',
                ),
        ),
      ],
    );
  }
}
