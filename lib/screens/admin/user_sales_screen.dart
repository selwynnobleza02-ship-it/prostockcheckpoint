import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/screens/admin/components/sales_list.dart';
import 'package:prostock/screens/admin/components/sales_stats_header.dart';

class UserSalesScreen extends StatefulWidget {
  const UserSalesScreen({super.key});

  @override
  State<UserSalesScreen> createState() => _UserSalesScreenState();
}

class _UserSalesScreenState extends State<UserSalesScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SalesProvider>().loadSales());
  }

  void _onDateRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    context.read<SalesProvider>().loadSales(refresh: true, startDate: start, endDate: end);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        return Column(
          children: [
            SalesStatsHeader(
              sales: salesProvider.sales,
              onDateRangeChanged: _onDateRangeChanged,
              startDate: _startDate,
              endDate: _endDate,
            ),
            if (salesProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (salesProvider.error != null)
              Center(child: Text(salesProvider.error!))
            else if (salesProvider.sales.isEmpty)
              const Center(child: Text('No sales found.'))
            else
              Expanded(
                child: SalesList(sales: salesProvider.sales),
              ),
          ],
        );
      },
    );
  }
}
