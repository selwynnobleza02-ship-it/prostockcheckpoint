import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/utils/app_constants.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/customer.dart';
import '../../widgets/barcode_scanner_widget.dart';
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
  }

  @override
  void dispose() {
    _productSearchController.removeListener(_onProductSearchChanged);
    _productSearchController.dispose();
    _productSearchDebounce?.cancel();
    super.dispose();
  }

  void _onProductSearchChanged() {
    if (_productSearchDebounce?.isActive ?? false) {
      _productSearchDebounce!.cancel();
    }
    _productSearchDebounce = Timer(UiConstants.debounceDuration, () {
      Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).loadProducts(searchQuery: _productSearchController.text.toLowerCase());
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
      }
      if (!mounted) return;
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final receipt = await salesProvider.completeSale(
        customerId: _selectedCustomer?.id,
        paymentMethod: _paymentMethod,
        dueDate: dueDate,
      );

      final cashTendered = _cartViewKey.currentState?.getCashTendered();
      final change = _cartViewKey.currentState?.getChange();

      if (context.mounted) {
        if (receipt != null) {
          if (!mounted) return;
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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(salesProvider.error ?? 'Sale failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSale = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Changed to false to prevent keyboard overflow
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Product Barcode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BarcodeScannerWidget(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        // Changed from SingleChildScrollView to Column
        children: [
          // Product section - takes up remaining space after cart
          Expanded(
            flex: 3, // 60% of available space
            child: Column(
              children: [
                // Search bar with fixed height
                SizedBox(
                  height: 70, // Fixed height for search
                  child: ProductSearchView(
                    controller: _productSearchController,
                    onChanged: (value) => _onProductSearchChanged(),
                  ),
                ),
                // Product grid takes remaining space in this section
                const Expanded(child: ProductGridView()),
              ],
            ),
          ),
          // Cart section - fixed height that adapts to content
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
              minHeight: 200,
            ),
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
