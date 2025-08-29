import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/loss.dart';

class LossOverTimeChart extends StatefulWidget {
  final List<Loss> losses;

  const LossOverTimeChart({super.key, required this.losses});

  @override
  State<LossOverTimeChart> createState() => _LossOverTimeChartState();
}

class _LossOverTimeChartState extends State<LossOverTimeChart> {
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
                    "Losses Over Time",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  /// Filter Buttons (Daily / Monthly / Yearly)
                  Center(
                    child: ToggleButtons(
                      isSelected: [
                        _selectedFilter == "Daily",
                        _selectedFilter == "Monthly",
                        _selectedFilter == "Yearly",
                      ],
                      onPressed: (index) {
                        setState(() {
                          _selectedFilter = [
                            "Daily",
                            "Monthly",
                            "Yearly",
                          ][index];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      selectedColor: Colors.white,
                      fillColor: Colors.red,
                      color: Colors.red,
                      constraints: const BoxConstraints(
                        minHeight: 36,
                        minWidth: 70,
                      ),
                      children: const [
                        Text("Daily"),
                        Text("Monthly"),
                        Text("Yearly"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              /// Chart
              Expanded(child: BarChart(_mainData())),
            ],
          ),
        ),
      ),
    );
  }

  BarChartData _mainData() {
    final barGroups = _getChartGroups();

    return BarChartData(
      barGroups: barGroups,
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
    );
  }

  List<BarChartGroupData> _getChartGroups() {
    if (widget.losses.isEmpty) return [];

    final Map<DateTime, double> groupedLosses = {};

    for (final loss in widget.losses) {
      DateTime key;

      if (_selectedFilter == "Daily") {
        key = DateTime(
          loss.timestamp.year,
          loss.timestamp.month,
          loss.timestamp.day,
        );
      } else if (_selectedFilter == "Monthly") {
        key = DateTime(loss.timestamp.year, loss.timestamp.month);
      } else {
        key = DateTime(loss.timestamp.year);
      }

      groupedLosses[key] = (groupedLosses[key] ?? 0) + loss.totalCost;
    }

    final sortedKeys = groupedLosses.keys.toList()..sort();

    return List.generate(sortedKeys.length, (i) {
      final date = sortedKeys[i];
      final total = groupedLosses[date]!;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: total,
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade800],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
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
    String text;

    if (_selectedFilter == "Daily") {
      text = DateFormat('MM/dd').format(date);
    } else if (_selectedFilter == "Monthly") {
      text = DateFormat('MMM yy').format(date);
    } else {
      text = DateFormat('yyyy').format(date);
    }

    return SideTitleWidget(
      meta: meta,
      space: 6,
      child: Text(text, style: style),
    );
  }

  List<DateTime> _getSortedKeys() {
    final Map<DateTime, double> groupedLosses = {};

    for (final loss in widget.losses) {
      DateTime key;
      if (_selectedFilter == "Daily") {
        key = DateTime(
          loss.timestamp.year,
          loss.timestamp.month,
          loss.timestamp.day,
        );
      } else if (_selectedFilter == "Monthly") {
        key = DateTime(loss.timestamp.year, loss.timestamp.month);
      } else {
        key = DateTime(loss.timestamp.year);
      }
      groupedLosses[key] = (groupedLosses[key] ?? 0) + loss.totalCost;
    }
    return groupedLosses.keys.toList()..sort();
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

    return Text(text, style: style, textAlign: TextAlign.left);
  }
}
