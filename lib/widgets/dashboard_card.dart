import 'package:flutter/material.dart';
import '../utils/currency_utils.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isCurrency;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isCurrency = false, // Default to false for count values
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(
          12,
        ), // Reduced padding to prevent overflow
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Better space distribution
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 28, // Reduced icon size to prevent overflow
                ),
                Flexible(
                  // Added Flexible to prevent text overflow
                  child: Text(
                    _formatDisplayValue(value),
                    style: TextStyle(
                      fontSize: 20, // Reduced font size to prevent overflow
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis, // Handle text overflow
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4), // Reduced spacing
            Text(
              title,
              style: const TextStyle(
                fontSize: 12, // Reduced font size
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis, // Handle text overflow
              maxLines: 2, // Allow title to wrap to 2 lines if needed
            ),
          ],
        ),
      ),
    );
  }

  String _formatDisplayValue(String value) {
    if (isCurrency) {
      // If the value already contains currency symbol, validate it
      if (value.contains('₱') || value.contains('\$')) {
        // Replace any $ symbols with ₱ symbols
        return value.replaceAll('\$', '₱');
      }

      // If it's a pure number, try to parse and format it as currency
      final numericValue = double.tryParse(value);
      if (numericValue != null) {
        return CurrencyUtils.formatCurrency(numericValue);
      }
    }

    // For non-currency values, just return the value as-is (whole numbers)
    return value;
  }
}
