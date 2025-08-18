import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../providers/credit_provider.dart';
import '../models/customer.dart';
import '../widgets/add_customer_dialog.dart';
import '../utils/currency_utils.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';

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
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredCustomers = provider.customers.where((customer) {
                  return customer.name.toLowerCase().contains(_searchQuery) ||
                      (customer.phone?.toLowerCase().contains(_searchQuery) ??
                          false) ||
                      (customer.email?.toLowerCase().contains(_searchQuery) ??
                          false);
                }).toList();

                if (filteredCustomers.isEmpty) {
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

                return ListView.builder(
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: customer.hasOverdueBalance
                              ? Colors.red
                              : customer.currentBalance > 0
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
                            Row(
                              children: [
                                Text(
                                  'Credit: ${CurrencyUtils.formatCurrency(customer.creditLimit)}',
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Balance: ${CurrencyUtils.formatCurrency(customer.currentBalance)}',
                                  style: TextStyle(
                                    color: customer.hasOverdueBalance
                                        ? Colors.red
                                        : customer.currentBalance > 0
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (customer.hasOverdueBalance)
                              const Text(
                                'OVERDUE BALANCE!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                              value: 'credit',
                              child: Text('Manage Credit'),
                            ),
                            const PopupMenuItem(
                              value: 'history',
                              child: Text('Transaction History'),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                _showCustomerDetails(customer);
                                break;
                              case 'credit':
                                _showCreditManagement(customer);
                                break;
                              case 'history':
                                _showTransactionHistory(customer);
                                break;
                            }
                          },
                        ),
                      ),
                    );
                  },
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
            if (customer.phone != null)
              _buildDetailRow('Phone', customer.phone!),
            if (customer.email != null)
              _buildDetailRow('Email', customer.email!),
            if (customer.address != null)
              _buildDetailRow('Address', customer.address!),
            _buildDetailRow(
              'Credit Limit',
              CurrencyUtils.formatCurrency(customer.creditLimit),
            ),
            _buildDetailRow(
              'Current Balance',
              CurrencyUtils.formatCurrency(customer.currentBalance),
            ),
            _buildDetailRow(
              'Available Credit',
              CurrencyUtils.formatCurrency(customer.availableCredit),
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

  void _showCreditManagement(Customer customer) {
    final paymentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Credit - ${customer.name}'),
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
                      const Text('Credit Limit:'),
                      Text(
                        CurrencyUtils.formatCurrency(customer.creditLimit),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Balance:'),
                      Text(
                        CurrencyUtils.formatCurrency(
                          customer.currentBalance,
                        ),
                        style: TextStyle(
                          color: customer.currentBalance > 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available Credit:'),
                      Text(
                        CurrencyUtils.formatCurrency(
                          customer.availableCredit,
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
                final customerProvider = Provider.of<CustomerProvider>(
                  context,
                  listen: false,
                );

                final success = await creditProvider.recordPayment(
                  customer.id!,
                  amount,
                  description: 'Payment received from ${customer.name}',
                );

                if (success) {
                  // Refresh customer data
                  await customerProvider.refreshCustomers();

                  if (mounted) {
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
                  if (mounted) {
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
