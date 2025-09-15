import 'package:prostock/screens/customers/dialogs/overdue_customers_list_dialog.dart';
import 'package:flutter/material.dart';
import 'package:prostock/screens/customers/dialogs/customer_options_dialog.dart';
import 'package:provider/provider.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/screens/customers/components/customer_list.dart';
import 'package:prostock/screens/customers/components/customer_qr_scanner.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';
import 'dart:async';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
      Provider.of<CreditProvider>(context, listen: false).fetchOverdueCustomers();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
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

  Future<void> _scanCustomerQRCode() async {
    final customerName = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const CustomerQRScanner()),
    );

    if (customerName != null && customerName.isNotEmpty) {
      if (!mounted) return;
      final customerProvider = Provider.of<CustomerProvider>(
        context,
        listen: false,
      );
      final Customer? customer = await customerProvider.getCustomerByName(
        customerName,
      );

      if (customer != null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => CustomerOptionsDialog(customer: customer),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This customer does not exist.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanCustomerQRCode,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options
            },
          ),
        ],
      ),
      body: Consumer<CreditProvider>(
        builder: (context, creditProvider, child) {
          final overdueCustomers = creditProvider.overdueCustomers;
          return Column(
            children: [
              if (overdueCustomers.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => OverdueCustomersListDialog(
                        overdueCustomers: overdueCustomers,
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 8.0),
                        Text(
                          '${overdueCustomers.length} customer(s) with overdue balance',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(child: CustomerList(scrollController: _scrollController)),
            ],
          );
        },
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
}
