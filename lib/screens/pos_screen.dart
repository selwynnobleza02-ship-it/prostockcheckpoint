import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/utils/app_constants.dart';
import '../providers/sales_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../models/product.dart';
import '../utils/currency_utils.dart';
import '../widgets/receipt_dialog.dart';
import 'dart:async';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash';
  final TextEditingController _productSearchController =
      TextEditingController();
  Timer? _productSearchDebounce;
  bool _isProcessingSale = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          Flexible(flex: 3, child: _buildProductSection()),
          Flexible(flex: 2, child: _buildCartSection()),
        ],
      ),
    );
  }

  Widget _buildProductSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(UiConstants.spacingMedium),
          child: TextField(
            controller: _productSearchController,
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.error != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error!),
                      backgroundColor: Colors.red,
                    ),
                  );
                  provider.clearError();
                });
              }

              final productsToDisplay = provider.products;

              if (productsToDisplay.isEmpty) {
                return const Center(child: Text('No products found'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(UiConstants.spacingMedium),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: UiConstants.spacingSmall,
                  mainAxisSpacing: UiConstants.spacingSmall,
                  childAspectRatio: 0.9,
                ),
                itemCount: productsToDisplay.length,
                itemBuilder: (context, index) {
                  final product = productsToDisplay[index];
                  return Card(
                    child: InkWell(
                      onTap: () {
                        if (product.stock > 0) {
                          Provider.of<SalesProvider>(
                            context,
                            listen: false,
                          ).addItemToCurrentSale(product, 1);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(UiConstants.spacingSmall),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(
                                    UiConstants.borderRadiusStandard,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.inventory,
                                  size: UiConstants.iconSizeMedium,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: UiConstants.spacingSmall),
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: UiConstants.fontSizeSmall,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              CurrencyUtils.formatCurrency(product.price),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: UiConstants.fontSizeSmall,
                              ),
                            ),
                            Text(
                              'Stock: ${product.stock}',
                              style: TextStyle(
                                color: product.stock > 0
                                    ? Colors.grey[600]
                                    : Colors.red,
                                fontSize: UiConstants.fontSizeExtraSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Container(
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
                      initialValue: _selectedCustomer,
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
                      onChanged: (customer) {
                        setState(() {
                          _selectedCustomer = customer;
                          if (_selectedCustomer == null) {
                            _paymentMethod = 'cash';
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: UiConstants.spacingSmall),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
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
                      enabled: _selectedCustomer != null,
                      child: Text(
                        'Credit',
                        style: TextStyle(
                          color: _selectedCustomer != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: context.watch<SalesProvider>().currentSaleItems.length,
              itemBuilder: (context, index) {
                final item = context
                    .watch<SalesProvider>()
                    .currentSaleItems[index];
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
                              context
                                  .read<SalesProvider>()
                                  .removeItemFromCurrentSale(index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
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
                            CurrencyUtils.formatCurrency(
                              provider.currentSaleTotal,
                            ),
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
                              style: TextStyle(
                                fontSize: UiConstants.fontSizeSmall,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: UiConstants.spacingSmall),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                provider.currentSaleItems.isEmpty ||
                                    _isProcessingSale
                                ? null
                                : () async {
                                    setState(() {
                                      _isProcessingSale = true;
                                    });
                                    try {
                                      final receipt = await provider
                                          .completeSale(
                                            customerId: _selectedCustomer?.id,
                                            paymentMethod: _paymentMethod,
                                          );
                                      if (context.mounted) {
                                        if (receipt != null && mounted) {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) =>
                                                ReceiptDialog(receipt: receipt),
                                          );
                                        } else if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                provider.error ?? 'Sale failed',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    } finally {
                                      setState(() {
                                        _isProcessingSale = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: UiConstants.spacingSmall,
                              ),
                            ),
                            child: _isProcessingSale
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
          ),
        ],
      ),
    );
  }
}
