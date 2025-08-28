import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../providers/credit_provider.dart';
import '../models/customer.dart';
import '../widgets/add_customer_dialog.dart';
import '../utils/currency_utils.dart';
import 'dart:async'; // Import for Timer

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch initial customers after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        // User has scrolled to the end, load more data
        Provider.of<CustomerProvider>(
          context,
          listen: false,
        ).loadMoreCustomers();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // Only trigger search if query has changed to avoid unnecessary calls
      if (_searchQuery != _searchController.text.toLowerCase()) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
        Provider.of<CustomerProvider>(
          context,
          listen: false,
        ).loadCustomers(searchQuery: _searchQuery);
      }
    });
  }

  Future<void> _refreshCustomers() async {
    await Provider.of<CustomerProvider>(
      context,
      listen: false,
    ).loadCustomers(refresh: true, searchQuery: _searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              // onChanged is now handled by the listener on _searchController
            ),
          ),
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.customers.isEmpty) {
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
                    provider.clearError(); // Clear the error after showing it
                  });
                }

                if (provider.customers.isEmpty && !provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No customers found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add your first customer to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshCustomers,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        provider.customers.length +
                        (provider.hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.customers.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final customer = provider.customers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: customer.hasUtang
                                ? Colors.orange
                                : Colors.green,
                            child: Text(
                              customer.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.phone != null)
                                Text('Phone: ${customer.phone}'),
                              if (customer.email != null)
                                Text('Email: ${customer.email}'),
                              Text(
                                'Utang: ${CurrencyUtils.formatCurrency(customer.utangBalance)}',
                                style: TextStyle(
                                  color: customer.hasUtang
                                      ? Colors.orange
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('View Details'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'utang',
                                child: Text('Manage Utang'),
                              ),
                              const PopupMenuItem(
                                value: 'history',
                                child: Text('Transaction History'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'view':
                                  _showCustomerDetails(customer);
                                  break;
                                case 'edit':
                                  showDialog(
                                    context: context,
                                    builder: (context) => AddCustomerDialog(
                                      customer: customer,
                                    ), // Pass existing customer for editing
                                  );
                                  break;
                                case 'utang':
                                  _showUtangManagement(customer);
                                  break;
                                case 'history':
                                  _showTransactionHistory(customer);
                                  break;
                                case 'delete':
                                  _showDeleteConfirmation(customer);
                                  break;
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddCustomerDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.imageUrl != null)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  customer.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error, size: 50);
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, size: 100, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            if (customer.phone != null)
              _buildDetailRow('Phone', customer.phone!),
            if (customer.email != null)
              _buildDetailRow('Email', customer.email!),
            if (customer.address != null)
              _buildDetailRow('Address', customer.address!),
            _buildDetailRow(
              'Utang Balance',
              CurrencyUtils.formatCurrency(customer.utangBalance),
            ),
            _buildDetailRow(
              'Member Since',
              '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showUtangManagement(Customer customer) {
    final paymentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Utang - ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Utang:'),
                      Text(
                        CurrencyUtils.formatCurrency(customer.utangBalance),
                        style: TextStyle(
                          color: customer.utangBalance > 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
                helperText: 'Enter amount customer is paying',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(paymentController.text);
              if (amount != null && amount > 0) {
                final creditProvider = Provider.of<CreditProvider>(
                  context,
                  listen: false,
                );

                final success = await creditProvider.recordPayment(
                  customer.id!,
                  amount,
                  description: 'Payment received from ${customer.name}',
                );

                if (success) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Payment of ₱${amount.toStringAsFixed(2)} recorded successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to record payment'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${customer.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<CustomerProvider>(
                context,
                listen: false,
              );
              final success = await provider.deleteCustomer(customer.id!);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Customer "${customer.name}" deleted successfully!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete customer. ${provider.error ?? ''}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTransactionHistory(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${customer.name} - Transaction History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Consumer<CreditProvider>(
            builder: (context, provider, child) {
              final transactions = provider.getTransactionsByCustomer(
                customer.id!,
              );

              if (transactions.isEmpty) {
                return const Center(child: Text('No transactions found'));
              }

              return ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final isPayment = transaction.type == 'payment';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPayment ? Colors.green : Colors.orange,
                      child: Icon(
                        isPayment ? Icons.payment : Icons.credit_card,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      isPayment ? 'Payment' : 'Credit Sale',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(transaction.description ?? 'No description'),
                        Text(
                          '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${isPayment ? '-' : '+'}${CurrencyUtils.formatCurrency(transaction.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPayment ? Colors.green : Colors.orange,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
