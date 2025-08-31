import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/stock_movement_provider.dart';

class StockMovementReportWidget extends StatelessWidget {
  const StockMovementReportWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StockMovementProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.movements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              'Error: ${provider.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
        final movements = provider.movements;

        if (movements.isEmpty) {
          return const Center(
            child: Text('No stock movements recorded yet.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadMovements(refresh: true),
          child: ListView.builder(
            itemCount: movements.length,
            itemBuilder: (context, index) {
              final movement = movements[index];
              final product = inventoryProvider.getProductById(movement.productId);
              final productName = product?.name ?? movement.productName;

              final isStockIn = movement.movementType == 'stock_in';
              final isStockOut = movement.movementType == 'stock_out';
              final icon = isStockIn
                  ? Icons.arrow_upward
                  : isStockOut
                      ? Icons.arrow_downward
                      : Icons.sync_alt;
              final color = isStockIn
                  ? Colors.green
                  : isStockOut
                      ? Colors.red
                      : Colors.orange;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white),
                  ),
                  title: Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${movement.reason ?? movement.movementType} - ${DateFormat.yMd().add_jm().format(movement.createdAt)}',
                  ),
                  trailing: Text(
                    '${isStockIn ? '+' : isStockOut ? '-' : ''}${movement.quantity.abs()}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}