import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'tax_history_service.dart';
import 'tax_rules_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore/pricing_service.dart';
import 'dart:async';
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
  static StreamSubscription? _settingsSubscription;

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

      // Hydrate from Firestore and subscribe for updates (best-effort)
      try {
        final pricing = PricingService(FirebaseFirestore.instance);
        final remote = await pricing.getGlobalSettings();
        if (remote != null) {
          final remoteAmount =
              (remote['tuboAmount'] ?? _defaultTuboAmount) * 1.0;
          final remoteInclusive =
              (remote['isInclusive'] ?? _defaultTuboInclusive) == true;
          await _writeLocal(remoteAmount, remoteInclusive);
        }

        _settingsSubscription = pricing.watchGlobalSettings().listen((
          data,
        ) async {
          if (data == null) return;
          final amount = (data['tuboAmount'] ?? _defaultTuboAmount) * 1.0;
          final inclusive =
              (data['isInclusive'] ?? _defaultTuboInclusive) == true;
          await _writeLocal(amount, inclusive);
          _instance.notifyListeners();
        });
      } catch (_) {}
    } catch (e) {
      _cachedTuboAmount = _defaultTuboAmount;
      _cachedTuboInclusive = _defaultTuboInclusive;
      _isInitialized = true;
    }
  }

  static Future<void> _writeLocal(double amount, bool inclusive) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedTuboAmount = amount;
    _cachedTuboInclusive = inclusive;
    await prefs.setDouble(_tuboAmountKey, amount);
    await prefs.setBool(_tuboInclusiveKey, inclusive);
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
      await _writeLocal(amount, getCachedTuboInclusive());
      final success = true;

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
        // Push to Firestore (best-effort)
        try {
          final pricing = PricingService(FirebaseFirestore.instance);
          await pricing.setGlobalSettings(
            tuboAmount: amount,
            isInclusive: getCachedTuboInclusive(),
            updatedBy: changedByUserName,
          );
        } catch (_) {}
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
      await _writeLocal(getCachedTuboAmount(), inclusive);
      final success = true;

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
      // Push to Firestore (best-effort)
      try {
        final pricing = PricingService(FirebaseFirestore.instance);
        await pricing.setGlobalSettings(
          tuboAmount: getCachedTuboAmount(),
          isInclusive: inclusive,
          updatedBy: changedByUserName,
        );
      } catch (_) {}
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Calculate selling price based on cost and tubo settings (synchronous)
  static double calculateSellingPriceSync(double cost) {
    // Added-on-top only: selling price = cost + tubo, rounded to nearest peso
    final tuboAmount = getCachedTuboAmount();
    final rawPrice = cost + tuboAmount;
    return rawPrice.round().toDouble();
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
    // Added-on-top only: cost = selling price - tubo
    final tuboAmount = getCachedTuboAmount();
    return sellingPrice - tuboAmount;
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
    // Added-on-top only: tubo is the fixed amount added
    final tuboAmount = getCachedTuboAmount();
    return tuboAmount;
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
      // Use rule: always add-on-top
      final rawPrice = cost + rule.tubo;
      return rawPrice.round().toDouble();
    }
    // Fallback to global
    return calculateSellingPriceSync(cost);
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

    return {
      'tuboAmount': tuboAmount,
      'isInclusive': false,
      'tuboAmountFormatted': '₱${tuboAmount.toStringAsFixed(2)}',
      'pricingMethod': 'Tubo Added on Top',
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
