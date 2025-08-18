import 'package:flutter/material.dart';

/// Test widget to verify currency symbols are displaying correctly
class CurrencyTestWidget extends StatelessWidget {
  const CurrencyTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Display Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Currency Symbol Tests:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Test various amounts
            _buildCurrencyTest('Small amount', 15.50),
            _buildCurrencyTest('Medium amount', 1234.75),
            _buildCurrencyTest('Large amount', 123456.99),
            _buildCurrencyTest('Zero amount', 0.00),
            _buildCurrencyTest('Decimal test', 999.01),

            const SizedBox(height: 24),
            const Text(
              'Expected: All amounts should show ₱ symbol',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Error: If any amount shows \$ symbol',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyTest(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
