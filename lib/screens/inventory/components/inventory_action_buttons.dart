import 'package:flutter/material.dart';
import 'package:prostock/widgets/barcode_scanner_widget.dart';

class InventoryActionButtons extends StatelessWidget {
  const InventoryActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
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
    );
  }
}
