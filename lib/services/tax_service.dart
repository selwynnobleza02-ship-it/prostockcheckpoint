import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'tax_history_service.dart';
import 'tax_rules_service.dart';
import '../models/tax_rule.dart';

class TaxService extends ChangeNotifier {
  static const String _tuboAmountKey = 'tubo_amount';
  static const String _tuboInclusiveKey = 'tubo_inclusive';

  // Default values
  static const double _defaultTuboAmount = 2.0; // ₱2 default tubo
  static const bool _defaultTuboInclusive = true;

  // In-memory cache
  static double? _cachedTuboAmount;
  static bool? _cachedTuboInclusive;
  static bool _isInitialized = false;
  static final TaxService _instance = TaxService._internal();

  factory TaxService() => _instance;
  TaxService._internal();

  /// Initialize the service and load settings into cache
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedTuboAmount = prefs.getDouble(_tuboAmountKey) ?? _defaultTuboAmount;
      _cachedTuboInclusive =
          prefs.getBool(_tuboInclusiveKey) ?? _defaultTuboInclusive;
      _isInitialized = true;
    } catch (e) {
      _cachedTuboAmount = _defaultTuboAmount;
      _cachedTuboInclusive = _defaultTuboInclusive;
      _isInitialized = true;
    }
  }

  /// Get cached tubo amount (synchronous)
  static double getCachedTuboAmount() {
    return _cachedTuboAmount ?? _defaultTuboAmount;
  }

  /// Get cached tubo inclusive setting (synchronous)
  static bool getCachedTuboInclusive() {
    return _cachedTuboInclusive ?? _defaultTuboInclusive;
  }

  /// Get the current tubo amount - async version
  static Future<double> getTuboAmount() async {
    if (!_isInitialized) {
      await initialize();
    }
    return getCachedTuboAmount();
  }

  /// Check if pricing is tubo inclusive - async version
  static Future<bool> isTuboInclusive() async {
    if (!_isInitialized) {
      await initialize();
    }
    return getCachedTuboInclusive();
  }

  /// Set the tubo amount
  static Future<bool> setTuboAmount(
    double amount, {
    String? changedByUserId,
    String? changedByUserName,
    String source = 'settings_screen',
  }) async {
    try {
      if (amount < 0.0) {
        return false;
      }

      final oldAmount = _cachedTuboAmount;
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setDouble(_tuboAmountKey, amount);

      if (success) {
        _cachedTuboAmount = amount;
        _instance.notifyListeners();

        // Log history if user info is provided
        if (changedByUserId != null && changedByUserName != null) {
          await TaxHistoryService.addHistoryEntry(
            changedByUserId: changedByUserId,
            changedByUserName: changedByUserName,
            oldAmount: oldAmount,
            newAmount: amount,
            source: source,
          );
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Set whether pricing is tubo inclusive
  static Future<bool> setTuboInclusive(
    bool inclusive, {
    String? changedByUserId,
    String? changedByUserName,
    String source = 'settings_screen',
  }) async {
    try {
      final oldInclusive = _cachedTuboInclusive;
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setBool(_tuboInclusiveKey, inclusive);

      if (success) {
        _cachedTuboInclusive = inclusive;
        _instance.notifyListeners();

        // Log history if user info is provided
        if (changedByUserId != null && changedByUserName != null) {
          await TaxHistoryService.addHistoryEntry(
            changedByUserId: changedByUserId,
            changedByUserName: changedByUserName,
            oldInclusive: oldInclusive,
            newInclusive: inclusive,
            source: source,
          );
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Calculate selling price based on cost and tubo settings (synchronous)
  static double calculateSellingPriceSync(double cost) {
    final tuboAmount = getCachedTuboAmount();
    final isInclusive = getCachedTuboInclusive();

    if (isInclusive) {
      // Tubo inclusive: selling price = cost (tubo already included)
      return cost.round().toDouble();
    } else {
      // Tubo exclusive: selling price = cost + tubo, rounded to nearest peso
      final rawPrice = cost + tuboAmount;
      return rawPrice.round().toDouble();
    }
  }

  /// Calculate selling price based on cost and tubo settings (async)
  static Future<double> calculateSellingPrice(double cost) async {
    if (!_isInitialized) {
      await initialize();
    }
    return calculateSellingPriceSync(cost);
  }

  /// Batch calculate selling prices for multiple costs
  static Future<List<double>> calculateSellingPrices(List<double> costs) async {
    if (!_isInitialized) {
      await initialize();
    }

    final tuboAmount = getCachedTuboAmount();
    final isInclusive = getCachedTuboInclusive();

    return costs.map((cost) {
      if (isInclusive) {
        return cost.round().toDouble();
      } else {
        final rawPrice = cost + tuboAmount;
        return rawPrice.round().toDouble();
      }
    }).toList();
  }

  /// Calculate cost from selling price based on tubo settings (synchronous)
  static double calculateCostFromSellingPriceSync(double sellingPrice) {
    final tuboAmount = getCachedTuboAmount();
    final isInclusive = getCachedTuboInclusive();

    if (isInclusive) {
      // Tubo inclusive: cost = selling price (tubo already included)
      return sellingPrice;
    } else {
      // Tubo exclusive: cost = selling price - tubo
      return sellingPrice - tuboAmount;
    }
  }

  /// Calculate cost from selling price based on tubo settings (async)
  static Future<double> calculateCostFromSellingPrice(
    double sellingPrice,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }
    return calculateCostFromSellingPriceSync(sellingPrice);
  }

  /// Batch calculate costs from selling prices
  static Future<List<double>> calculateCostsFromSellingPrices(
    List<double> sellingPrices,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    final tuboAmount = getCachedTuboAmount();
    final isInclusive = getCachedTuboInclusive();

    return sellingPrices.map((sellingPrice) {
      if (isInclusive) {
        return sellingPrice;
      } else {
        return sellingPrice - tuboAmount;
      }
    }).toList();
  }

  /// Calculate tubo amount from selling price (synchronous)
  static double calculateTuboAmountSync(double sellingPrice) {
    final tuboAmount = getCachedTuboAmount();
    final isInclusive = getCachedTuboInclusive();

    if (isInclusive) {
      // Tubo inclusive: tubo is already included in selling price
      return tuboAmount;
    } else {
      // Tubo exclusive: tubo is the fixed amount added
      return tuboAmount;
    }
  }

  /// Calculate tubo amount from selling price (async)
  static Future<double> calculateTuboAmount(double sellingPrice) async {
    if (!_isInitialized) {
      await initialize();
    }
    return calculateTuboAmountSync(sellingPrice);
  }

  /// Batch calculate tubo amounts from selling prices
  static Future<List<double>> calculateTuboAmounts(
    List<double> sellingPrices,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    final tuboAmount = getCachedTuboAmount();

    return sellingPrices.map((sellingPrice) {
      return tuboAmount;
    }).toList();
  }

  /// Calculate selling price with category-specific tubo rule
  static Future<double> calculateSellingPriceWithRule(
    double cost, {
    String? productId,
    String? categoryName,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final rule = await TaxRulesService.getBestRule(
      productId: productId,
      categoryName: categoryName,
    );

    if (rule != null && rule.id.isNotEmpty) {
      // Use specific rule
      if (rule.isInclusive) {
        return cost.round().toDouble();
      } else {
        final rawPrice = cost + rule.tubo;
        return rawPrice.round().toDouble();
      }
    } else {
      // Fall back to global settings
      return calculateSellingPriceSync(cost);
    }
  }

  /// Calculate selling price with category-specific tubo rule (synchronous)
  static double calculateSellingPriceWithRuleSync(
    double cost, {
    String? productId,
    String? categoryName,
  }) {
    // For synchronous version, we can't easily get the rule without async
    // So we fall back to global settings
    return calculateSellingPriceSync(cost);
  }

  /// Batch calculate selling prices with category-specific rules
  static Future<List<double>> calculateSellingPricesWithRules(
    List<double> costs, {
    List<String>? productIds,
    List<String>? categoryNames,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final results = <double>[];

    for (int i = 0; i < costs.length; i++) {
      final cost = costs[i];
      final productId = productIds != null && i < productIds.length
          ? productIds[i]
          : null;
      final categoryName = categoryNames != null && i < categoryNames.length
          ? categoryNames[i]
          : null;

      final sellingPrice = await calculateSellingPriceWithRule(
        cost,
        productId: productId,
        categoryName: categoryName,
      );

      results.add(sellingPrice);
    }

    return results;
  }

  /// Get tax rule for a specific product/category
  static Future<TaxRule?> getTaxRule({
    String? productId,
    String? categoryName,
  }) async {
    return await TaxRulesService.getBestRule(
      productId: productId,
      categoryName: categoryName,
    );
  }

  /// Get all tax rules
  static Future<List<TaxRule>> getAllTaxRules() async {
    return await TaxRulesService.getAllRules();
  }

  /// Add a new tax rule
  static Future<bool> addTaxRule(TaxRule rule) async {
    return await TaxRulesService.addRule(rule);
  }

  /// Update an existing tax rule
  static Future<bool> updateTaxRule(TaxRule rule) async {
    return await TaxRulesService.updateRule(rule);
  }

  /// Delete a tax rule
  static Future<bool> deleteTaxRule(String ruleId) async {
    return await TaxRulesService.deleteRule(ruleId);
  }

  /// Get tubo information for display
  static Future<Map<String, dynamic>> getTuboInfo() async {
    final tuboAmount = await getTuboAmount();
    final isInclusive = await isTuboInclusive();

    return {
      'tuboAmount': tuboAmount,
      'isInclusive': isInclusive,
      'tuboAmountFormatted': '₱${tuboAmount.toStringAsFixed(2)}',
      'pricingMethod': isInclusive ? 'Tubo Inclusive' : 'Tubo Added on Top',
    };
  }

  /// Reset to default settings
  static Future<bool> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_tuboAmountKey, _defaultTuboAmount);
      await prefs.setBool(_tuboInclusiveKey, _defaultTuboInclusive);
      return true;
    } catch (e) {
      return false;
    }
  }
}
