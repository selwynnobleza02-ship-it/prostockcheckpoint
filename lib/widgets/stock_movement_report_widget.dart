import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/stock_movement_provider.dart';

class StockMovementReportWidget extends StatefulWidget {
  const StockMovementReportWidget({super.key});

  @override
  State<StockMovementReportWidget> createState() =>
      _StockMovementReportWidgetState();
}

class _StockMovementReportWidgetState extends State<StockMovementReportWidget> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _endDate ?? DateTime.now(),
    );
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialDateRange,
    );

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });
      _loadMovements();
    }
  }

  void _loadMovements() {
    Provider.of<StockMovementProvider>(
      context,
      listen: false,
    ).loadMovements(startDate: _startDate, endDate: _endDate);
  }

  @override
  void initState() {
    super.initState();
    // Initial load without date filter
    _loadMovements();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _startDate != null && _endDate != null
                    ? 'Period: ${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}'
                    : 'All time',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDateRange(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<StockMovementProvider>(
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

              final inventoryProvider = Provider.of<InventoryProvider>(
                context,
                listen: false,
              );
              final movements = provider.movements;

              if (movements.isEmpty) {
                return const Center(
                  child: Text('No stock movements recorded for this period.'),
                );
              }

              return ListView.builder(
                itemCount: movements.length,
                itemBuilder: (context, index) {
                  final movement = movements[index];
                  final product = inventoryProvider.getProductById(
                    movement.productId,
                  );
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                        '${isStockIn
                            ? '+'
                            : isStockOut
                            ? '-'
                            : ''}${movement.quantity.abs()}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
