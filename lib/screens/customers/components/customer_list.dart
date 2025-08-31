import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/screens/customers/components/customer_list_item.dart';

class CustomerList extends StatelessWidget {
  final ScrollController scrollController;

  const CustomerList({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
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
            provider.clearError();
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
          onRefresh: () => provider.loadCustomers(refresh: true),
          child: ListView.builder(
            controller: scrollController,
            itemCount: provider.customers.length + (provider.hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.customers.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final customer = provider.customers[index];
              return CustomerListItem(customer: customer);
            },
          ),
        );
      },
    );
  }
}
