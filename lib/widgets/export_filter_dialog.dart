import 'package:flutter/material.dart';

class ExportFilterOptions {
  bool useDataRangeFilter;
  bool limitItemCount;
  int maxItemCount;
  bool summaryOnly;
  DateTime? startDate;
  DateTime? endDate;

  ExportFilterOptions({
    this.useDataRangeFilter = false,
    this.limitItemCount = true,
    this.maxItemCount = 100,
    this.summaryOnly = false,
    this.startDate,
    this.endDate,
  });
}

class ExportFilterDialog extends StatefulWidget {
  final ExportFilterOptions initialOptions;
  final Function(ExportFilterOptions) onApply;

  const ExportFilterDialog({
    super.key,
    required this.initialOptions,
    required this.onApply,
  });

  @override
  State<ExportFilterDialog> createState() => _ExportFilterDialogState();
}

class _ExportFilterDialogState extends State<ExportFilterDialog> {
  late ExportFilterOptions options;

  @override
  void initState() {
    super.initState();
    options = ExportFilterOptions(
      useDataRangeFilter: widget.initialOptions.useDataRangeFilter,
      limitItemCount: widget.initialOptions.limitItemCount,
      maxItemCount: widget.initialOptions.maxItemCount,
      summaryOnly: widget.initialOptions.summaryOnly,
      startDate: widget.initialOptions.startDate,
      endDate: widget.initialOptions.endDate,
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start:
          options.startDate ??
          DateTime.now().subtract(const Duration(days: 30)),
      end: options.endDate ?? DateTime.now(),
    );

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (dateRange != null) {
      setState(() {
        options.startDate = dateRange.start;
        options.endDate = dateRange.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Export Data'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range filter
            CheckboxListTile(
              title: const Text('Filter by date range'),
              subtitle:
                  options.useDataRangeFilter &&
                      options.startDate != null &&
                      options.endDate != null
                  ? Text(
                      '${options.startDate!.toLocal().toString().split(' ')[0]} - ${options.endDate!.toLocal().toString().split(' ')[0]}',
                    )
                  : const Text('Use date range filter'),
              value: options.useDataRangeFilter,
              onChanged: (value) =>
                  setState(() => options.useDataRangeFilter = value!),
            ),

            if (options.useDataRangeFilter)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 0,
                  bottom: 8,
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Select Dates'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),

            const Divider(),

            // Limit number of items
            CheckboxListTile(
              title: const Text('Limit number of entries'),
              subtitle: options.limitItemCount
                  ? Text('Maximum ${options.maxItemCount} items per section')
                  : const Text(
                      'Include all data (may cause errors if too large)',
                    ),
              value: options.limitItemCount,
              onChanged: (value) =>
                  setState(() => options.limitItemCount = value!),
            ),

            if (options.limitItemCount)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 0,
                  bottom: 8,
                ),
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Maximum items',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: options.maxItemCount,
                  items: [25, 50, 100, 200, 300]
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count items'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => options.maxItemCount = value!),
                ),
              ),

            const Divider(),

            // Show summary only
            CheckboxListTile(
              title: const Text('Summary only'),
              subtitle: const Text(
                'Only include summary data, not detailed records',
              ),
              value: options.summaryOnly,
              onChanged: (value) =>
                  setState(() => options.summaryOnly = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, options);
          },
          child: const Text('Apply & Export'),
        ),
      ],
    );
  }
}
