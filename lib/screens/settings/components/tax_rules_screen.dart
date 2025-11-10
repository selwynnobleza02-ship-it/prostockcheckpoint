import 'package:flutter/material.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/models/tax_rule.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/utils/constants.dart';
import 'package:provider/provider.dart';

class TaxRulesScreen extends StatefulWidget {
  const TaxRulesScreen({super.key});

  @override
  State<TaxRulesScreen> createState() => _TaxRulesScreenState();
}

class _TaxRulesScreenState extends State<TaxRulesScreen> {
  List<TaxRule> _rules = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when dependencies change to ensure we have latest product data
    _loadRules();
  }

  // Map to cache product names by ID
  final Map<String, String> _productNames = {};

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final rules = await TaxService.getAllTaxRules();

      // Load product names for product-specific rules
      final productIds = rules
          .where((rule) => rule.isProduct && rule.productId != null)
          .map((rule) => rule.productId!)
          .toSet()
          .toList();

      if (productIds.isNotEmpty && mounted) {
        final inventoryProvider = context.read<InventoryProvider>();
        for (final productId in productIds) {
          final product = inventoryProvider.getProductById(productId);
          if (product != null) {
            _productNames[productId] = product.name;
          }
        }
      }

      if (mounted) {
        setState(() {
          _rules = rules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tax rules: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addRule() async {
    final result = await showDialog<TaxRule>(
      context: context,
      builder: (context) => const AddTaxRuleDialog(),
    );

    if (result != null) {
      // Check for conflicts using the service method
      final conflictRule = await TaxService.checkForConflicts(result);

      if (conflictRule != null) {
        // Determine the scope for the confirmation dialog
        String scope = 'Rule';
        if (result.isGlobal) {
          scope = 'Global';
        } else if (result.isCategory) {
          scope = 'Category (${result.categoryName})';
        } else if (result.isProduct) {
          scope = 'Product';
        }

        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Replace $scope Rule'),
            content: Text(
              'A $scope markup rule already exists with tubo amount ₱${conflictRule.tubo.toStringAsFixed(2)}.\n\n'
              'Do you want to replace it with the new rule (₱${result.tubo.toStringAsFixed(2)})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          return; // User cancelled
        }
      }

      final success = await TaxService.addTaxRule(result);
      if (success) {
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.isGlobal
                    ? 'Global rule replaced successfully!'
                    : result.isCategory
                    ? 'Category rule replaced successfully!'
                    : result.isProduct
                    ? 'Product rule replaced successfully!'
                    : 'Tax rule added successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add tax rule'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editRule(TaxRule rule) async {
    final result = await showDialog<TaxRule>(
      context: context,
      builder: (context) => AddTaxRuleDialog(rule: rule),
    );

    if (result != null) {
      // Show confirmation dialog for updating rule
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Markup Rule'),
          content: Text(
            'Are you sure you want to update this markup rule?\n\n'
            'Current: ${rule.description} (₱${rule.tubo.toStringAsFixed(2)})\n'
            'New: ${result.description} (₱${result.tubo.toStringAsFixed(2)})\n\n'
            'This will affect pricing for all products using this rule.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Update'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final success = await TaxService.updateTaxRule(result);
        if (success) {
          _loadRules();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tax rule updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update tax rule'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _deleteRule(TaxRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Markup Rule'),
        content: Text(
          'Are you sure you want to delete this markup rule?\n\n'
          'Rule: ${rule.description}\n'
          'Tubo Amount: ₱${rule.tubo.toStringAsFixed(2)}\n\n'
          'This will affect pricing for all products using this rule. '
          'Products will fall back to the next applicable rule or global settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await TaxService.deleteTaxRule(rule.id);
      if (success) {
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tax rule deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete tax rule'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markup Rules'),
        actions: [
          IconButton(
            onPressed: _loadRules,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 16, color: Colors.red[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRules,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _rules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rule, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tax rules configured',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add rules for different categories or products',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final rule = _rules[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRuleColor(rule),
                      child: Icon(
                        _getRuleIcon(rule),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _getRuleDisplayName(rule),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tubo: ₱${rule.tubo.toStringAsFixed(2)}'),
                        // Method removed; sari-sari pricing always adds tubo on top
                        Text('Priority: ${rule.priority}'),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editRule(rule);
                        } else if (value == 'delete') {
                          _deleteRule(rule);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getRuleColor(TaxRule rule) {
    if (rule.isProduct) {
      return Colors.purple;
    } else if (rule.isCategory) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  // Get a user-friendly display name for the rule
  String _getRuleDisplayName(TaxRule rule) {
    if (rule.isProduct && rule.productId != null) {
      // Return product name if available, fallback to generic description with ID
      return _productNames.containsKey(rule.productId)
          ? 'Product: ${_productNames[rule.productId]}'
          : 'Product: (Unknown - ID: ${rule.productId})';
    } else if (rule.isCategory && rule.categoryName != null) {
      return 'Category: ${rule.categoryName}';
    } else {
      return 'Global rule';
    }
  }

  IconData _getRuleIcon(TaxRule rule) {
    if (rule.isProduct) {
      return Icons.inventory;
    } else if (rule.isCategory) {
      return Icons.category;
    } else {
      return Icons.settings;
    }
  }
}

class _ProductSearchDialog extends StatefulWidget {
  final List<Product> products;

  const _ProductSearchDialog({required this.products});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    _searchController.addListener(_filterProducts);
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = widget.products
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Select Product',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ListTile(
                          leading: const Icon(Icons.inventory),
                          title: Text(product.name),
                          subtitle: Text('Category: ${product.category}'),
                          onTap: () {
                            Navigator.of(context).pop(product);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddTaxRuleDialog extends StatefulWidget {
  final TaxRule? rule;

  const AddTaxRuleDialog({super.key, this.rule});

  @override
  State<AddTaxRuleDialog> createState() => _AddTaxRuleDialogState();
}

class _AddTaxRuleDialogState extends State<AddTaxRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tuboController = TextEditingController();
  final _categoryController = TextEditingController();
  final _productController = TextEditingController();

  String _ruleType = 'global'; // 'global', 'category', 'product'
  // Inclusive removed; always add on top.
  bool _isLoading = false;

  // For category dropdown
  String? _selectedCategory;
  List<String> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _setupProductSearch();

    if (widget.rule != null) {
      _ruleType = widget.rule!.isProduct
          ? 'product'
          : widget.rule!.isCategory
          ? 'category'
          : 'global';
      _tuboController.text = widget.rule!.tubo.toStringAsFixed(2);
      // Ignore any stored inclusive flag; not used anymore.
      _selectedCategory = widget.rule!.categoryName;
      _categoryController.text = widget.rule!.categoryName ?? '';

      // For product rules, look up the product name from the ID
      if (widget.rule!.productId != null) {
        final inventoryProvider = context.read<InventoryProvider>();
        final product = inventoryProvider.getProductById(
          widget.rule!.productId!,
        );
        _productController.text = product?.name ?? 'Unknown Product';
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      // Only use predefined categories from AppConstants
      final predefinedCategories = AppConstants.productCategories;

      // Sort categories alphabetically
      final sortedCategories = List<String>.from(predefinedCategories)..sort();

      if (mounted) {
        setState(() {
          _availableCategories = sortedCategories;
        });
      }
    } catch (e) {
      // Fallback to empty list if there's an error
      if (mounted) {
        setState(() {
          _availableCategories = [];
        });
      }
    }
  }

  void _setupProductSearch() {
    // No longer needed since we use a separate dialog
  }

  void _showProductSearchDialog() async {
    final inventoryProvider = context.read<InventoryProvider>();

    // Ensure products are loaded
    if (inventoryProvider.products.isEmpty) {
      await inventoryProvider.loadProducts();
    }

    if (!mounted) return;

    final products = inventoryProvider.products;

    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductSearchDialog(products: products),
    );

    if (selectedProduct != null) {
      setState(() {
        _productController.text = selectedProduct.name;
      });
    }
  }

  @override
  void dispose() {
    _tuboController.dispose();
    _categoryController.dispose();
    _productController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tubo = double.parse(_tuboController.text);
      final now = DateTime.now();

      // For product rules, we need to find the product ID from the name
      String? productId;
      if (_ruleType == 'product') {
        try {
          final inventoryProvider = context.read<InventoryProvider>();
          final products = inventoryProvider.products;
          final product = products.firstWhere(
            (p) => p.name == _productController.text.trim(),
            orElse: () => throw StateError('Product not found'),
          );
          productId = product.id;
        } catch (e) {
          // Handle error
        }
      }

      final rule = TaxRule(
        id: widget.rule?.id ?? now.millisecondsSinceEpoch.toString(),
        categoryName: _ruleType == 'category' ? _selectedCategory : null,
        productId: productId,
        tubo: tubo,
        isInclusive: false,
        priority: _getPriority(),
        createdAt: widget.rule?.createdAt ?? now,
        updatedAt: now,
      );

      Navigator.of(context).pop(rule);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _getPriority() {
    switch (_ruleType) {
      case 'product':
        return 100;
      case 'category':
        return 50;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.rule == null
                        ? 'Add Markup Rule'
                        : 'Edit Markup Rule',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rule Type
                  const Text(
                    'Rule Type',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: _ruleType,
                    onChanged: (value) {
                      setState(() {
                        _ruleType = value ?? 'global';
                      });
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Global'),
                          subtitle: const Text('Applies to all products'),
                          value: 'global',
                        ),
                        RadioListTile<String>(
                          title: const Text('Category'),
                          subtitle: const Text('Applies to specific category'),
                          value: 'category',
                        ),
                        RadioListTile<String>(
                          title: const Text('Product'),
                          subtitle: const Text('Applies to specific product'),
                          value: 'product',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Category/Product fields
                  if (_ruleType == 'category') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Select Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _availableCategories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _categoryController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_ruleType == 'product') ...[
                    TextFormField(
                      controller: _productController,
                      decoration: const InputDecoration(
                        labelText: 'Search Product',
                        hintText: 'Type product name...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        suffixIcon: Icon(Icons.inventory),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select a product';
                        }
                        return null;
                      },
                      onTap: () {
                        _showProductSearchDialog();
                      },
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tubo Amount
                  TextFormField(
                    controller: _tuboController,
                    decoration: const InputDecoration(
                      labelText: 'Tubo Amount (₱)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: '₱',
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    expands: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Tubo amount is required';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount < 0) {
                        return 'Tubo amount must be 0 or greater';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Sari-sari pricing always adds tubo on top; method selector removed
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveRule,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(widget.rule == null ? 'Add' : 'Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
