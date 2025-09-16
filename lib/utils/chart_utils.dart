import 'package:intl/intl.dart';

class ChartUtils {
  static Map<DateTime, double> groupDataByFilter<T>(
      List<T> data,
      String filter,
      DateTime Function(T) dateSelector,
      double Function(T) valueSelector) {
    final Map<DateTime, double> groupedData = {};

    for (final item in data) {
      DateTime key;
      final date = dateSelector(item);

      if (filter == "Daily") {
        key = DateTime(date.year, date.month, date.day);
      } else if (filter == "Weekly") {
        final dayOfWeek = date.weekday;
        key = DateTime(date.year, date.month, date.day - dayOfWeek + 1);
      } else if (filter == "Monthly") {
        key = DateTime(date.year, date.month);
      } else { // Yearly
        key = DateTime(date.year);
      }

      groupedData[key] = (groupedData[key] ?? 0) + valueSelector(item);
    }
    return groupedData;
  }

  static String formatBottomTitle(DateTime date, String filter) {
    if (filter == "Daily" || filter == "Weekly") {
      return DateFormat('MM/dd').format(date);
    } else if (filter == "Monthly") {
      return DateFormat('MMM yy').format(date);
    } else { // Yearly
      return DateFormat('yyyy').format(date);
    }
  }
}
