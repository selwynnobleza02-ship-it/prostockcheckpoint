import 'package:intl/intl.dart';

class ChartUtils {
  static Map<DateTime, double> groupDataByFilter<T>(
    List<T> data,
    String filter,
    DateTime Function(T) dateSelector,
    double Function(T) valueSelector,
  ) {
    // First filter data by time scope
    final filteredData = _filterDataByTimeScope(data, filter, dateSelector);
    final Map<DateTime, double> groupedData = {};

    for (final item in filteredData) {
      DateTime key;
      final date = dateSelector(item);

      if (filter == "Daily") {
        key = DateTime(date.year, date.month, date.day);
      } else if (filter == "Weekly") {
        // Group by Monday of the week
        final dayOfWeek = date.weekday;
        key = DateTime(date.year, date.month, date.day - dayOfWeek + 1);
      } else if (filter == "Monthly") {
        key = DateTime(date.year, date.month);
      } else {
        // Yearly
        key = DateTime(date.year);
      }

      groupedData[key] = (groupedData[key] ?? 0) + valueSelector(item);
    }

    // Merge with complete date range to show zero values for missing periods
    return _mergeWithDateRange(groupedData, filter);
  }

  /// Filter data based on the selected time scope
  static List<T> _filterDataByTimeScope<T>(
    List<T> data,
    String filter,
    DateTime Function(T) dateSelector,
  ) {
    final now = DateTime.now();
    late DateTime cutoffDate;

    switch (filter) {
      case "Daily":
        // Last 7 days
        cutoffDate = DateTime(now.year, now.month, now.day - 6);
        break;
      case "Weekly":
        // Last 5 weeks (35 days)
        cutoffDate = DateTime(now.year, now.month, now.day - 34);
        break;
      case "Monthly":
        // Last 12 months
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case "Yearly":
        // Last 5 years
        cutoffDate = DateTime(now.year - 4, now.month, now.day);
        break;
      default:
        return data;
    }

    return data.where((item) {
      final itemDate = dateSelector(item);
      return itemDate.isAfter(cutoffDate) ||
          itemDate.isAtSameMomentAs(cutoffDate);
    }).toList();
  }

  /// Generate complete date range for the filter
  static List<DateTime> _generateDateRange(String filter) {
    final now = DateTime.now();
    final List<DateTime> dates = [];

    switch (filter) {
      case "Daily":
        // Last 7 days
        for (int i = 6; i >= 0; i--) {
          final date = DateTime(now.year, now.month, now.day - i);
          dates.add(date);
        }
        break;

      case "Weekly":
        // Last 5 weeks (Monday of each week)
        final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));
        for (int i = 4; i >= 0; i--) {
          final weekStart = mondayThisWeek.subtract(Duration(days: i * 7));
          dates.add(DateTime(weekStart.year, weekStart.month, weekStart.day));
        }
        break;

      case "Monthly":
        // Last 12 months
        for (int i = 11; i >= 0; i--) {
          final monthDate = DateTime(now.year, now.month - i, 1);
          dates.add(monthDate);
        }
        break;

      case "Yearly":
        // Last 5 years
        for (int i = 4; i >= 0; i--) {
          final yearDate = DateTime(now.year - i, 1, 1);
          dates.add(yearDate);
        }
        break;
    }

    return dates;
  }

  /// Merge generated date range with actual data to show zero values
  static Map<DateTime, double> _mergeWithDateRange(
    Map<DateTime, double> data,
    String filter,
  ) {
    final dateRange = _generateDateRange(filter);
    final Map<DateTime, double> merged = {};

    for (final date in dateRange) {
      DateTime key;

      if (filter == "Daily") {
        key = DateTime(date.year, date.month, date.day);
      } else if (filter == "Weekly") {
        final dayOfWeek = date.weekday;
        key = DateTime(date.year, date.month, date.day - dayOfWeek + 1);
      } else if (filter == "Monthly") {
        key = DateTime(date.year, date.month);
      } else {
        // Yearly
        key = DateTime(date.year);
      }

      merged[key] = data[key] ?? 0.0;
    }

    return merged;
  }

  /// Public method for merging with date range (for external use if needed)
  static Map<DateTime, double> mergeWithDateRange(
    Map<DateTime, double> data,
    String filter,
  ) {
    return _mergeWithDateRange(data, filter);
  }

  static String formatBottomTitle(DateTime date, String filter) {
    if (filter == "Daily") {
      // Return day names: Mon, Tue, Wed, etc.
      return DateFormat('E').format(date);
    } else if (filter == "Weekly") {
      // Return week ranges: Sep 1-7, Sep 8-14, etc.
      final endOfWeek = date.add(const Duration(days: 6));
      final startFormat = DateFormat('MMM d').format(date);
      final endDay = endOfWeek.day;

      if (date.month == endOfWeek.month) {
        return '$startFormat-$endDay';
      } else {
        final endFormat = DateFormat('MMM d').format(endOfWeek);
        return '$startFormat-$endFormat';
      }
    } else if (filter == "Monthly") {
      // Return month names: Jan, Feb, Mar, etc.
      return DateFormat('MMM').format(date);
    } else {
      // Yearly
      // Return year: 2023, 2024, etc.
      return DateFormat('yyyy').format(date);
    }
  }
}
