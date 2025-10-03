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
      resizeToAvoidBottomInset: true,
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
        children: [
          // Product section - gets most of the space (70%)
          Expanded(
            flex: 7, // Increased from 3 to give more space to products
            child: Column(
              children: [
                // Search bar (let it size itself to avoid overflow on loading/keyboard)
                ProductSearchView(
                  controller: _productSearchController,
                  onChanged: (value) => _onProductSearchChanged(),
                ),
                // Product grid takes remaining space in this section
                const Expanded(child: ProductGridView()),
              ],
            ),
          ),
          // Cart section - adaptive height (30% of available space, respects keyboard)
          Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final availableHeight =
                  (media.size.height - media.viewInsets.bottom).clamp(
                    0.0,
                    double.infinity,
                  );
              final targetHeight = (availableHeight * 0.3).clamp(160.0, 360.0);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: targetHeight,
                child: CartView(
                  key: _cartViewKey,
                  selectedCustomer: _selectedCustomer,
                  paymentMethod: _paymentMethod,
                  isProcessingSale: _isProcessingSale,
                  onCustomerChanged: _onCustomerChanged,
                  onPaymentMethodChanged: _onPaymentMethodChanged,
                  onCompleteSale: _completeSale,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
