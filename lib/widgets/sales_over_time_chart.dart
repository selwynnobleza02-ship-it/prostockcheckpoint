import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:prostock/utils/chart_utils.dart';
import '../models/sale.dart';
import 'filter_toggle_buttons.dart';

class SalesOverTimeChart extends StatefulWidget {
  final List<Sale> sales;

  const SalesOverTimeChart({super.key, required this.sales});

  @override
  State<SalesOverTimeChart> createState() => _SalesOverTimeChartState();
}

class _SalesOverTimeChartState extends State<SalesOverTimeChart> {
  String _selectedFilter = "Daily"; // default

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Header + Filter
              Column(
                children: [
                  const Text(
                    "Sales Over Time",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  /// Filter Buttons
                  FilterToggleButtons(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    fillColor: Colors.blue,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              /// Chart
              Expanded(child: LineChart(_mainData())),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _mainData() {
    final spots = _getChartSpots();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
        getDrawingVerticalLine: (value) =>
            FlLine(color: Colors.grey.shade300, strokeWidth: 0.5),
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
            reservedSize: 32,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            getTitlesWidget: leftTitleWidgets,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (spots.length - 1).toDouble(),
      minY: 0,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade800],
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withValues(alpha: 0.3),
                Colors.blue.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getChartSpots() {
    if (widget.sales.isEmpty) return [const FlSpot(0, 0)];

    // groupDataByFilter now handles time scoping and merging internally
    final groupedSales = ChartUtils.groupDataByFilter<Sale>(
      widget.sales,
      _selectedFilter,
      (sale) => sale.createdAt,
      (sale) => sale.totalAmount,
    );

    final sortedKeys = groupedSales.keys.toList()..sort();

    return List.generate(sortedKeys.length, (i) {
      final date = sortedKeys[i];
      final total = groupedSales[date]!;
      return FlSpot(i.toDouble(), total);
    });
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    final groupedKeys = _getSortedKeys();
    if (value.toInt() >= groupedKeys.length) return const SizedBox.shrink();

    final date = groupedKeys[value.toInt()];
    final text = ChartUtils.formatBottomTitle(date, _selectedFilter);

    return SideTitleWidget(
      meta: meta,
      space: 6,
      child: Transform.rotate(
        angle: -0.5, // Tilt text by ~30 degrees
        child: Text(text, style: style),
      ),
    );
  }

  List<DateTime> _getSortedKeys() {
    // groupDataByFilter now handles time scoping and merging internally
    final groupedSales = ChartUtils.groupDataByFilter<Sale>(
      widget.sales,
      _selectedFilter,
      (sale) => sale.createdAt,
      (sale) => sale.totalAmount,
    );

    return groupedSales.keys.toList()..sort();
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff67727d),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    String text;
    if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(1)}k';
    } else {
      text = value.toStringAsFixed(0);
    }

    return Text(text, style: style);
  }
}
