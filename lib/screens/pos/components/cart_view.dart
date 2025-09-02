import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/utils/app_constants.dart';
import 'package:prostock/utils/currency_utils.dart';

import 'package:provider/provider.dart';

class CartView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          _buildCartHeader(context),
          Expanded(child: _buildCartItems(context)),
          _buildCartFooter(context),
        ],
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
                initialValue: selectedCustomer,
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
                onChanged: onCustomerChanged,
              );
            },
          ),
          const SizedBox(height: UiConstants.spacingSmall),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
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
                enabled: selectedCustomer != null,
                child: Text(
                  'Credit',
                  style: TextStyle(
                    color: selectedCustomer != null
                        ? Colors.black
                        : Colors.grey,
                  ),
                ),
              ),
            ],
            onChanged: onPaymentMethodChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: context.watch<SalesProvider>().currentSaleItems.length,
      itemBuilder: (context, index) {
        final item = context.watch<SalesProvider>().currentSaleItems[index];
        final product = context.watch<InventoryProvider>().products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            name: 'Unknown Product',
            cost: 0,
            stock: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return ListTile(
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
            style: const TextStyle(fontSize: UiConstants.fontSizeExtraSmall),
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
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: UiConstants.spacingLarge,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.remove,
                      size: UiConstants.spacingMedium,
                    ),
                    onPressed: () {
                      context.read<SalesProvider>().removeItemFromCurrentSale(
                        index,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UiConstants.spacingSmall),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
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
                    style: TextStyle(
                      fontSize: UiConstants.fontSizeMedium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      CurrencyUtils.formatCurrency(provider.currentSaleTotal),
                      style: const TextStyle(
                        fontSize: UiConstants.fontSizeMedium,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UiConstants.spacingSmall),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: provider.currentSaleItems.isEmpty
                          ? null
                          : () {
                              provider.clearCurrentSale();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                          vertical: UiConstants.spacingSmall,
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: UiConstants.fontSizeSmall),
                      ),
                    ),
                  ),
                  const SizedBox(width: UiConstants.spacingSmall),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          provider.currentSaleItems.isEmpty || isProcessingSale
                          ? null
                          : onCompleteSale,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: UiConstants.spacingSmall,
                        ),
                      ),
                      child: isProcessingSale
                          ? const SizedBox(
                              width: UiConstants.iconSizeSmall,
                              height: UiConstants.iconSizeSmall,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: UiConstants.strokeWidthSmall,
                              ),
                            )
                          : const Text(
                              'Checkout',
                              style: TextStyle(
                                fontSize: UiConstants.fontSizeSmall,
                              ),
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
