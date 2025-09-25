import 'package:flutter/material.dart';
import 'package:prostock/widgets/barcode_scanner_widget.dart';
import 'package:prostock/widgets/manual_stock_adjustment_dialog.dart';
import 'package:prostock/screens/inventory/demand_suggestions_screen.dart';

class InventoryActionButtons extends StatelessWidget {
  const InventoryActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // First row: Stock management buttons
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'scan',
                      child: ListTile(
                        leading: Icon(Icons.qr_code_scanner),
                        title: Text('Scan Barcode'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'manual',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Manual Entry'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'scan') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BarcodeScannerWidget(
                            mode: ScannerMode.receiveStock,
                          ),
                        ),
                      );
                    } else if (value == 'manual') {
                      showDialog(
                        context: context,
                        builder: (context) => const ManualStockAdjustmentDialog(
                          type: StockAdjustmentType.receive,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_box, color: Colors.white),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Receive Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'scan',
                      child: ListTile(
                        leading: Icon(Icons.qr_code_scanner),
                        title: Text('Scan Barcode'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'manual',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Manual Entry'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'scan') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BarcodeScannerWidget(
                            mode: ScannerMode.removeStock,
                          ),
                        ),
                      );
                    } else if (value == 'manual') {
                      showDialog(
                        context: context,
                        builder: (context) => const ManualStockAdjustmentDialog(
                          type: StockAdjustmentType.remove,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Remove Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: Demand suggestions button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DemandSuggestionsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Demand Suggestions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
