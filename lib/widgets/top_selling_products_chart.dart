import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/product.dart';
import '../models/sale.dart';

class TopSellingProductsChart extends StatelessWidget {
  final List<Product> products;
  final List<SaleItem> saleItems;

  const TopSellingProductsChart({
    super.key,
    required this.products,
    required this.saleItems,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(_mainData()),
        ),
      ),
    );
  }

  BarChartData _mainData() {
    final topProducts = _getTopSellingProducts();

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: topProducts.isNotEmpty
          ? topProducts.first.value.toDouble() * 1.2
          : 10,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.blueGrey,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final productName = topProducts[groupIndex].key;
            final quantity = topProducts[groupIndex].value;
            return BarTooltipItem(
              '$productName\n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: <TextSpan>[
                TextSpan(
                  text: 'Sold: ${quantity.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: getBottomTitles,
            reservedSize: 38,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 30),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: topProducts.asMap().entries.map((entry) {
        final index = entry.key;
        final productData = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: productData.value.toDouble(),
              color: Colors.primaries[index % Colors.primaries.length],
              width: 22,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget getBottomTitles(double value, TitleMeta meta) {
    final topProducts = _getTopSellingProducts();
    final style = TextStyle(
      color: const Color(0xff7589a2),
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    String text;
    if (value.toInt() < topProducts.length) {
      // Show first 3 letters of product name
      text = topProducts[value.toInt()].key.substring(0, 3);
    } else {
      text = '';
    }
    return SideTitleWidget(
      meta: meta,
      space: 16,
      child: Text(text, style: style),
    );
  }

  List<MapEntry<String, int>> _getTopSellingProducts() {
    final Map<String, int> productSales = {};

    for (final item in saleItems) {
      final product = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: '',
          name: 'Unknown',
          stock: 0,
          minStock: 0,
          category: '',
          cost: 0,
          createdAt: DateTime.timestamp(),
          updatedAt: DateTime.timestamp(),
        ),
      );
      if (product.id!.isNotEmpty) {
        productSales[product.name] =
            (productSales[product.name] ?? 0) + item.quantity;
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedProducts.take(5).toList();
  }
}
