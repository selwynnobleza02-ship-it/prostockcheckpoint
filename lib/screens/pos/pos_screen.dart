import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/utils/app_constants.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/customer.dart';
import '../../widgets/barcode_scanner_widget.dart';
import '../../widgets/sync_status_indicator.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/confirmation_dialog.dart';
import 'dart:async';

import 'components/cart_view.dart';
import 'components/product_grid_view.dart';
import 'components/product_search_view.dart';

class POSScreen extends StatefulWidget {
  final Customer? customer;
  final String? paymentMethod;

  const POSScreen({super.key, this.customer, this.paymentMethod});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final GlobalKey<CartViewState> _cartViewKey = GlobalKey<CartViewState>();
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash';
  final TextEditingController _productSearchController =
      TextEditingController();
  Timer? _productSearchDebounce;
  bool _isProcessingSale = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.customer;
    if (widget.paymentMethod != null) {
      _paymentMethod = widget.paymentMethod!;
    }
    _productSearchController.addListener(_onProductSearchChanged);

    // Load products on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  void dispose() {
    _productSearchController.removeListener(_onProductSearchChanged);
    _productSearchController.dispose();
    _productSearchDebounce?.cancel();
    super.dispose();
  }

  void _onProductSearchChanged() {
    // Cancel previous timer if active
    _productSearchDebounce?.cancel();

    // Create new timer
    _productSearchDebounce = Timer(UiConstants.debounceDuration, () {
      // Double-check if widget is still mounted and controller hasn't changed
      if (mounted && _productSearchController.text.trim().isNotEmpty) {
        final searchQuery = _productSearchController.text.trim();
        try {
          Provider.of<InventoryProvider>(
            context,
            listen: false,
          ).loadProducts(searchQuery: searchQuery);
        } catch (e) {
          // Handle any errors that might occur during search
          if (mounted) {
            _showErrorSnackBar('Search failed. Please try again.');
          }
        }
      } else if (mounted && _productSearchController.text.trim().isEmpty) {
        // If search is cleared, load all products
        try {
          Provider.of<InventoryProvider>(context, listen: false).loadProducts();
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('Failed to load products. Please try again.');
          }
        }
      }
    });
  }

  void _onCustomerChanged(Customer? customer) {
    setState(() {
      _selectedCustomer = customer;
      if (_selectedCustomer == null) {
        _paymentMethod = 'cash';
      }
    });
  }

  void _onPaymentMethodChanged(String? value) {
    setState(() {
      _paymentMethod = value!;
    });
  }

  Future<void> _completeSale() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    // Check if there are items in the cart
    if (salesProvider.currentSaleItems.isEmpty) {
      _showErrorSnackBar(
        'Please add items to the cart before completing the sale.',
      );
      return;
    }

    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Complete Sale',
      content: 'Are you sure you want to complete this sale?',
      confirmText: 'Complete',
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessingSale = true;
    });

    try {
      if (!mounted) return;

      DateTime? dueDate;
      if (_paymentMethod == 'credit') {
        dueDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );

        if (dueDate == null) {
          setState(() {
            _isProcessingSale = false;
          });
          return;
        }
      }

      if (!mounted) return;

      final receipt = await salesProvider.completeSale(
        customerId: _selectedCustomer?.id,
        paymentMethod: _paymentMethod,
        dueDate: dueDate,
      );

      if (!mounted) return;

      if (receipt != null) {
        final cashTendered = _cartViewKey.currentState?.getCashTendered();
        final change = _cartViewKey.currentState?.getChange();

        // Clear search when sale is completed
        _productSearchController.clear();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ReceiptDialog(
            receipt: receipt,
            cashTendered: double.tryParse(cashTendered ?? '0.0') ?? 0.0,
            change: change ?? 0.0,
          ),
        );
      } else {
        _showErrorSnackBar(
          salesProvider.error ?? 'Sale failed. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          'An error occurred while completing the sale. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSale = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleBarcodeResult(String barcode) async {
    try {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      // Search for product by barcode
      final product = inventoryProvider.products.firstWhere(
        (p) => p.barcode == barcode,
        orElse: () => throw Exception('Product not found'),
      );

      // Check if product is in stock
      final visualStock = inventoryProvider.getVisualStock(product.id!);
      if (visualStock <= 0) {
        _showErrorSnackBar('Product "${product.name}" is out of stock');
        return;
      }

      // Add product to cart
      salesProvider.addItemToCurrentSale(product, 1);
      _showSuccessSnackBar('Added "${product.name}" to cart');

      // Clear search to show all products
      _productSearchController.clear();
    } catch (e) {
      _showErrorSnackBar('Product with barcode "$barcode" not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Product Barcode',
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const BarcodeScannerWidget(),
                ),
              );

              if (result != null && mounted) {
                _handleBarcodeResult(result);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
            onPressed: () {
              Provider.of<InventoryProvider>(
                context,
                listen: false,
              ).loadProducts(refresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search section with result indicator
          Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              final isSearching = _productSearchController.text.isNotEmpty;
              final resultCount = provider.products.length;

              return Column(
                children: [
                  ProductSearchView(
                    controller: _productSearchController,
                    onChanged: (value) => _onProductSearchChanged(),
                  ),
                  if (isSearching)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.blue[50],
                      child: Text(
                        resultCount == 0
                            ? 'No products found for "${_productSearchController.text}"'
                            : 'Found $resultCount product${resultCount == 1 ? '' : 's'} for "${_productSearchController.text}"',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Products section
          Expanded(flex: 3, child: const ProductGridView()),
          // Cart section
          Expanded(
            flex: 2,
            child: CartView(
              key: _cartViewKey,
              selectedCustomer: _selectedCustomer,
              paymentMethod: _paymentMethod,
              isProcessingSale: _isProcessingSale,
              onCustomerChanged: _onCustomerChanged,
              onPaymentMethodChanged: _onPaymentMethodChanged,
              onCompleteSale: _completeSale,
            ),
          ),
        ],
      ),
    );
  }
}
