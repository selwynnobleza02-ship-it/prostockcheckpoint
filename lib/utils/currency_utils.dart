class CurrencyUtils {
  static const String currencySymbol = '₱';
  static const String incorrectSymbol = r'$';

  /// Formats a double value as Philippine Peso currency
  /// Example: formatCurrency(1234.56) returns "₱1,234.56"
  static String formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    // Add commas to integer part
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final integerWithCommas = integerPart.replaceAllMapped(
      regex,
      (Match m) => '${m[1]},',
    );

    return '$currencySymbol$integerWithCommas.$decimalPart';
  }

  /// Formats currency without decimal places for whole numbers
  /// Example: formatCurrencyWhole(1000.00) returns "₱1,000"
  static String formatCurrencyWhole(double amount) {
    if (amount == amount.roundToDouble()) {
      return '$currencySymbol${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    }
    return formatCurrency(amount);
  }

  /// Parses a currency string back to double
  /// Example: parseCurrency("₱1,234.56") returns 1234.56
  static double parseCurrency(String currencyString) {
    final cleanString = currencyString
        .replaceAll(currencySymbol, '')
        .replaceAll(incorrectSymbol, '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleanString) ?? 0.0;
  }

  /// Validates if a string is a valid currency format
  static bool isValidCurrency(String value) {
    final cleanValue = value
        .replaceAll(currencySymbol, '')
        .replaceAll(incorrectSymbol, '')
        .replaceAll(',', '')
        .trim();
    final parsed = double.tryParse(cleanValue);
    return parsed != null && parsed >= 0;
  }

  /// Validates that a currency string uses the correct symbol
  static bool isValidCurrencyFormat(String currencyString) {
    return currencyString.contains(currencySymbol) &&
        !currencyString.contains(incorrectSymbol);
  }

  /// Converts any \$ symbols to ₱ symbols
  static String fixCurrencySymbol(String currencyString) {
    return currencyString.replaceAll(incorrectSymbol, currencySymbol);
  }

  /// Enhanced currency validator to ensure no dollar signs appear in the app
  static String validateAndFix(String input) {
    // Replace any dollar signs with peso signs
    String fixed = input.replaceAll(incorrectSymbol, currencySymbol);

    // If it's a number without currency symbol, add peso sign
    final numericValue = double.tryParse(input);
    if (numericValue != null) {
      return '$currencySymbol${numericValue.toStringAsFixed(2)}';
    }

    return fixed;
  }

  /// Checks if a string contains any dollar signs
  static bool containsDollarSign(String input) {
    return input.contains(incorrectSymbol);
  }

  /// Scans a list of strings for dollar signs
  static List<String> findDollarSigns(List<String> inputs) {
    return inputs.where((input) => containsDollarSign(input)).toList();
  }

  /// Validates that all currency displays in a widget tree use peso signs
  static bool validateCurrencyConsistency(List<String> displayValues) {
    for (String value in displayValues) {
      if (containsDollarSign(value)) {
        return false;
      }
    }
    return true;
  }
}
