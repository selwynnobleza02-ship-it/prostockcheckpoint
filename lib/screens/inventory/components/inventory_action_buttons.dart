import 'package:flutter/material.dart';
import 'package:prostock/widgets/barcode_scanner_widget.dart';
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
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BarcodeScannerWidget(
                          mode: ScannerMode.receiveStock,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_box),
                  label: const Text('Receive Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BarcodeScannerWidget(
                          mode: ScannerMode.removeStock,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.remove_circle),
                  label: const Text('Remove Stock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
