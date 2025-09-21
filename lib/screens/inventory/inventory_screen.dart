import 'package:flutter/material.dart';

import '../../widgets/add_product_dialog.dart';
import '../../widgets/barcode_scanner_widget.dart';
import 'dart:async';

import 'components/inventory_action_buttons.dart';
import 'components/inventory_search_bar.dart';
import 'components/product_list_view.dart';
import '../../widgets/sync_status_indicator.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
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
          InventorySearchBar(controller: _searchController),
          const InventoryActionButtons(),
          const SizedBox(height: 16),
          Expanded(child: ProductListView(searchQuery: _searchQuery)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddProductDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
