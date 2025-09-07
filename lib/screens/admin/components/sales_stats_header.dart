import 'package:flutter/material.dart';
import 'package:prostock/models/sale.dart';
import 'package:intl/intl.dart';

class SalesStatsHeader extends StatelessWidget {
  final List<Sale> sales;
  final Function(DateTime?, DateTime?) onDateRangeChanged;
  final DateTime? startDate;
  final DateTime? endDate;

  const SalesStatsHeader({
    super.key,
    required this.sales,
    required this.onDateRangeChanged,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final totalSales = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final numberOfSales = sales.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[900],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total Sales', NumberFormat.currency(symbol: '₱').format(totalSales)),
              _buildStatCard('Number of Sales', numberOfSales.toString()),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _selectDateRange(context),
            icon: const Icon(Icons.date_range),
            label: Text(_getDateRangeText()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getDateRangeText() {
    if (startDate == null || endDate == null) {
      return 'Select Date Range';
    }
    return '${DateFormat.yMd().format(startDate!)} - ${DateFormat.yMd().format(endDate!)}';
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = startDate != null && endDate != null
        ? DateTimeRange(start: startDate!, end: endDate!)
        : null;
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (newDateRange != null) {
      onDateRangeChanged(newDateRange.start, newDateRange.end);
    }
  }
}
