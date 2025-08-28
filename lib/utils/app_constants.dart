/// A central place for constant values used throughout the application.
/// This helps in maintaining consistency and makes the code more readable
/// and easier to maintain.
library;

// ------------------- API/Query Constants ------------------- //

/// Constants related to API, database queries, and pagination.
class ApiConstants {
  static const int defaultPageSize = 30;
  static const int userActivityLimit = 10;
  static const int productSearchLimit = 50;
  static const int salesHistoryLimit = 30;
  static const int offlineBatchSize = 50;
}

// ------------------- Validation Constants ------------------- //

/// Constants for data validation rules.
class ValidationConstants {
  static const double maxTransactionAmount = 1000000.0;
  static const int maxDescriptionLength = 200;
  static const int maxNameLength = 100;
  static const int maxCategoryLength = 50;
  static const int maxSaleQuantity = 1000;
  static const int maxLocalErrors = 100;
  static const int minPhoneNumberLength = 10;
  static const int maxPhoneNumberLength = 11;
  static const int maxInputLength = 1000;
  static const int maxCollectionNameLength = 100;
  static const int maxDocIdLength = 100;
}

// ------------------- UI Constants ------------------- //

/// Constants for defining UI element properties like spacing, radius, etc.
class UiConstants {
  // Durations
  static const Duration debounceDuration = Duration(milliseconds: 300);

  // Padding and Spacing
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingExtraLarge = 40.0;
  static const double spacingExtraLarge2 = 30.0;

  // Radius
  static const double borderRadiusStandard = 10.0;

  // Font Sizes
  static const double fontSizeExtraSmall = 10.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeTitle = 32.0;
  static const double fontSizeButton = 18.0;

  // Barcode Scanner
  static const double barcodeScannerBorderLength = 40.0;
  static const double barcodeScannerCutOutSize = 280.0;
  static const double barcodeScannerBorderWidth = 3.0;

  // Constraints
  static const double receiptMaxWidth = 400.0;

  // Icon Sizes
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 30.0;
  static const double iconSizeLarge = 40.0;

  // Stroke Widths
  static const double strokeWidthSmall = 2.0;
}

// ------------------- App Default Values ------------------- //

/// Default values for various states and initializations.
class AppDefaults {
  static const int defaultTabIndex = 0;
  static const int notSynced = 0;
  static const int synced = 1;
}
