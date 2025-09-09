import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FinancialSummaryChart extends StatelessWidget {
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;

  const FinancialSummaryChart({
    super.key,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey,
            ),
          ),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          barGroups: _createBarGroups(),
        ),
      ),
    );
  }

  double _calculateMaxY() {
    final values = [totalRevenue, totalCost, totalProfit.abs()];
    values.sort();
    return values.last * 1.2;
  }

  List<BarChartGroupData> _createBarGroups() {
    return [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: totalRevenue,
            color: Colors.green,
            width: 22,
          ),
        ],
        showingTooltipIndicators: [0],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: totalCost,
            color: Colors.red,
            width: 22,
          ),
        ],
        showingTooltipIndicators: [0],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: totalProfit,
            color: totalProfit >= 0 ? Colors.blue : Colors.orange,
            width: 22,
          ),
        ],
        showingTooltipIndicators: [0],
      ),
    ];
  }
}
