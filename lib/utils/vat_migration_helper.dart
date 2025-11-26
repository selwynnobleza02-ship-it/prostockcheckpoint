import '../services/tax_rules_service.dart';

/// Helper utility to trigger VAT implementation price recalculation
///
/// This should be called once after deploying the VAT changes to update
/// all product price history with the new VAT-based prices.
///
/// Usage:
/// ```dart
/// await VATMigrationHelper.applyVATToPrices();
/// ```
class VATMigrationHelper {
  /// Recalculate all product prices with 12% VAT and record in price history
  ///
  /// This will:
  /// - Calculate new VAT-based prices for all products
  /// - Record price changes in price history with reason "VAT implementation (12%)"
  /// - Preserve manual price overrides
  /// - Skip products where price hasn't changed
  static Future<void> applyVATToPrices() async {
    await TaxRulesService.recalculateAllPricesForVAT();
  }
}
