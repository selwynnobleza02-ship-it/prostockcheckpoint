import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sales_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../models/product.dart';
import '../utils/currency_utils.dart';
import '../widgets/receipt_dialog.dart'; // Added import for receipt dialog

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            // Mobile layout - stack vertically
            return Column(
              children: [
                // Product selection on top
                Expanded(flex: 2, child: _buildProductSection()),
                // Cart on bottom
                SizedBox(height: 300, child: _buildCartSection()),
              ],
            );
          } else {
            // Desktop/tablet layout - side by side
            return Row(
              children: [
                // Product selection side
                Expanded(flex: 2, child: _buildProductSection()),
                // Cart side with minimum width constraint
                SizedBox(
                  width: constraints.maxWidth > 800 ? 350 : 280,
                  child: _buildCartSection(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProductSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true, // Added dense to reduce height
            ),
            onChanged: (value) {
              // Implement product search
            },
          ),
        ),
        Expanded(
          child: Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600
                      ? 2
                      : 1, // Responsive grid
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: MediaQuery.of(context).size.width > 600
                      ? 0.8
                      : 1.2, // Responsive aspect ratio
                ),
                itemCount: provider.products.length,
                itemBuilder: (context, index) {
                  final product = provider.products[index];
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
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.inventory,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12, // Reduced font size
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              CurrencyUtils.formatCurrency(product.price),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12, // Reduced font size
                              ),
                            ),
                            Text(
                              'Stock: ${product.stock}',
                              style: TextStyle(
                                color: product.stock > 0
                                    ? Colors.grey[600]
                                    : Colors.red,
                                fontSize: 10, // Reduced font size
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
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12), // Reduced padding from 16 to 12
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Customer selection
                Consumer<CustomerProvider>(
                  builder: (context, provider, child) {
                    return DropdownButtonFormField<Customer>(
                      value: _selectedCustomer,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<Customer>(
                          value: null,
                          child: Text(
                            'Walk-in Customer',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 8), // Reduced from 12 to 8
                // Payment method
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit')),
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
          // Cart items
          Expanded(
            child: Consumer<SalesProvider>(
              builder: (context, provider, child) {
                if (provider.currentSaleItems.isEmpty) {
                  return const Center(child: Text('No items in cart'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: provider.currentSaleItems.length,
                  itemBuilder: (context, index) {
                    final item = provider.currentSaleItems[index];
                    // Get the actual product to display its name
                    final product =
                        Provider.of<InventoryProvider>(
                          context,
                          listen: false,
                        ).products.firstWhere(
                          (p) => p.id == item.productId,
                          orElse: () => Product(
                            name: 'Unknown Product',
                            price: 0,
                            cost: 0,
                            stock: 0,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      title: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 12,
                        ), // Reduced font size
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Qty: ${item.quantity}',
                        style: const TextStyle(
                          fontSize: 10,
                        ), // Reduced font size
                      ),
                      trailing: SizedBox(
                        width: 80, // Fixed width for trailing section
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                CurrencyUtils.formatCurrency(
                                  item.totalPrice,
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                ), // Reduced font size
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 24, // Fixed width for icon button
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () {
                                  provider.removeItemFromCurrentSale(index);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Total and checkout
          Container(
            padding: const EdgeInsets.all(12), // Reduced padding from 16 to 12
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Consumer<SalesProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 16, // Reduced from 18 to 16
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            CurrencyUtils.formatCurrency(
                              provider.currentSaleTotal,
                            ),
                            style: const TextStyle(
                              fontSize: 16, // Reduced from 18 to 16
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // Reduced from 16 to 12
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
                            onPressed: provider.currentSaleItems.isEmpty
                                ? null
                                : () async {
                                    final receipt = await provider.completeSale(
                                      customerId: _selectedCustomer?.id,
                                      paymentMethod: _paymentMethod,
                                    );

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
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
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
          ),
        ],
      ),
    );
  }
}
