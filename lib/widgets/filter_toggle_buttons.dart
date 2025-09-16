import 'package:flutter/material.dart';

class FilterToggleButtons extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Color fillColor;
  final Color color;

  const FilterToggleButtons({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.fillColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ToggleButtons(
        isSelected: [
          selectedFilter == "Daily",
          selectedFilter == "Weekly",
          selectedFilter == "Monthly",
          selectedFilter == "Yearly",
        ],
        onPressed: (index) {
          final filter = ["Daily", "Weekly", "Monthly", "Yearly"][index];
          onFilterChanged(filter);
        },
        borderRadius: BorderRadius.circular(12),
        selectedColor: Colors.white,
        fillColor: fillColor,
        color: color,
        constraints: const BoxConstraints(
          minHeight: 36,
          minWidth: 70,
        ),
        children: const [
          Text("Daily"),
          Text("Weekly"),
          Text("Monthly"),
          Text("Yearly"),
        ],
      ),
    );
  }
}
