import 'package:flutter/material.dart';
import 'package:prostock/models/sale.dart';
import 'package:intl/intl.dart';

class SalesList extends StatelessWidget {
  final List<Sale> sales;

  const SalesList({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text('Sale ID: ${sale.id}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total: ${NumberFormat.currency(symbol: '₱').format(sale.totalAmount)}'),
                Text('Payment Method: ${sale.paymentMethod}'),
                Text('Date: ${DateFormat.yMd().add_jm().format(sale.createdAt)}'),
              ],
            ),
            trailing: Text(sale.status, style: TextStyle(color: _getStatusColor(sale.status))),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
