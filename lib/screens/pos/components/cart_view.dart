import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/currency_utils.dart';

import 'package:provider/provider.dart';

class CartView extends StatefulWidget {
  final Customer? selectedCustomer;
  final String paymentMethod;
  final bool isProcessingSale;
  final ValueChanged<Customer?> onCustomerChanged;
  final ValueChanged<String?> onPaymentMethodChanged;
  final VoidCallback onCompleteSale;

  const CartView({
    super.key,
    required this.selectedCustomer,
    required this.paymentMethod,
    required this.isProcessingSale,
    required this.onCustomerChanged,
    required this.onPaymentMethodChanged,
    required this.onCompleteSale,
  });

  @override
  State<CartView> createState() => CartViewState();
}

class CartViewState extends State<CartView> {
  final TextEditingController _cashTenderedController = TextEditingController();
  double _change = 0.0;

  String getCashTendered() {
    return _cashTenderedController.text;
  }

  double getChange() {
    return _change;
  }

  @override
  void initState() {
    super.initState();
    _cashTenderedController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _cashTenderedController.removeListener(_calculateChange);
    _cashTenderedController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final total = Provider.of<SalesProvider>(
      context,
      listen: false,
    ).currentSaleTotal;
    final cashTendered = double.tryParse(_cashTenderedController.text) ?? 0.0;
    setState(() {
      _change = cashTendered - total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        // Make entire cart scrollable
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCartHeader(context),
            _buildCartItems(context),
            _buildCartFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCartHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UiConstants.spacingSmall),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Consumer<CustomerProvider>(
            builder: (context, provider, child) {
              return DropdownButtonFormField<Customer>(
                initialValue: widget.selectedCustomer,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: UiConstants.spacingSmall,
                    vertical: UiConstants.spacingSmall,
                  ),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<Customer>(
                    value: null,
                    child: Text('Walk-in Customer'),
                  ),
                  ...provider.customers.map(
                    (customer) => DropdownMenuItem<Customer>(
                      value: customer,
                      child: Text(
                        customer.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: widget.onCustomerChanged,
              );
            },
          ),
          const SizedBox(height: UiConstants.spacingSmall),
          DropdownButtonFormField<String>(
            initialValue: widget.paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: UiConstants.spacingSmall,
                vertical: UiConstants.spacingSmall,
              ),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(
                value: 'credit',
                enabled: widget.selectedCustomer != null,
                child: Text(
                  'Credit',
                  style: TextStyle(
                    color: widget.selectedCustomer != null
                        ? Colors.black
                        : Colors.grey,
                  ),
                ),
              ),
            ],
            onChanged: widget.onPaymentMethodChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        if (salesProvider.currentSaleItems.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(UiConstants.spacingLarge),
            child: const Text(
              'No items in cart',
              style: TextStyle(
                color: Colors.grey,
                fontSize: UiConstants.fontSizeMedium,
              ),
            ),
          );
        }

        // Calculate height based on number of items (max 4 items visible)
        final itemCount = salesProvider.currentSaleItems.length;
        final maxVisibleItems = 4;
        final itemHeight = 60.0; // Approximate height per item
        final calculatedHeight = itemCount > maxVisibleItems
            ? maxVisibleItems * itemHeight
            : itemCount * itemHeight;

        return Container(
          constraints: BoxConstraints(
            maxHeight: calculatedHeight,
            minHeight: itemHeight,
          ),
          child: ListView.builder(
            shrinkWrap: true, // Important for scrollable parent
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: salesProvider.currentSaleItems.length,
            itemBuilder: (context, index) {
              final item = salesProvider.currentSaleItems[index];
              final product = context
                  .watch<InventoryProvider>()
                  .products
                  .firstWhere(
                    (p) => p.id == item.productId,
                    orElse: () => Product(
                      name: 'Unknown Product',
                      cost: 0,
                      stock: 0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: UiConstants.spacingSmall,
                  vertical: 2,
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: UiConstants.spacingSmall,
                    vertical: 2,
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontSize: UiConstants.fontSizeSmall),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Qty: ${item.quantity}',
                    style: const TextStyle(
                      fontSize: UiConstants.fontSizeExtraSmall,
                    ),
                  ),
                  trailing: SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyUtils.formatCurrency(item.totalPrice),
                            style: const TextStyle(
                              fontSize: UiConstants.fontSizeExtraSmall,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: UiConstants.spacingLarge,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: UiConstants.spacingMedium,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              salesProvider.removeItemFromCurrentSale(index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCartFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UiConstants.spacingSmall,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Consumer<SalesProvider>(
        builder: (context, provider, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CurrencyUtils.formatCurrency(provider.currentSaleTotal),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              if (widget.paymentMethod == 'cash') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cashTenderedController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cash Tendered',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '₱ ',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _change >= 0
                              ? Colors.blue[50]
                              : Colors.red[50],
                          border: Border.all(
                            color: _change >= 0 ? Colors.blue : Colors.red,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Change: ${CurrencyUtils.formatCurrency(_change)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _change >= 0 ? Colors.blue : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: provider.currentSaleItems.isEmpty
                          ? null
                          : () {
                              provider.clearCurrentSale();
                              _cashTenderedController.clear();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          provider.currentSaleItems.isEmpty ||
                              widget.isProcessingSale ||
                              (widget.paymentMethod == 'cash' &&
                                  (double.tryParse(
                                            _cashTenderedController.text,
                                          ) ??
                                          0.0) <
                                      provider.currentSaleTotal)
                          ? null
                          : widget.onCompleteSale,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: widget.isProcessingSale
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Checkout',
                              style: TextStyle(fontSize: 12),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
