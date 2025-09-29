import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tax_rule.dart';

class TaxRulesService {
  static const String _rulesKey = 'tax_rules';
  static const int _maxRules = 100; // Limit to prevent storage bloat

  /// Get all tax rules
  static Future<List<TaxRule>> getAllRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = prefs.getString(_rulesKey) ?? '[]';
      final List<dynamic> rulesList = jsonDecode(rulesJson);

      return rulesList.map((rule) => TaxRule.fromMap(rule)).toList()..sort(
        (a, b) => b.priority.compareTo(a.priority),
      ); // Sort by priority desc
    } catch (e) {
      return [];
    }
  }

  /// Get rules for a specific category
  static Future<List<TaxRule>> getRulesForCategory(String categoryName) async {
    final allRules = await getAllRules();
    return allRules.where((rule) => rule.categoryName == categoryName).toList();
  }

  /// Get rule for a specific product
  static Future<TaxRule?> getRuleForProduct(String productId) async {
    final allRules = await getAllRules();
    return allRules.firstWhere(
      (rule) => rule.productId == productId,
      orElse: () => TaxRule(
        id: '',
        tubo: 0.0,
        isInclusive: true,
        priority: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Get the best matching rule for a product and category
  static Future<TaxRule?> getBestRule({
    String? productId,
    String? categoryName,
  }) async {
    final allRules = await getAllRules();

    // Find product-specific rule first
    if (productId != null) {
      final productRule = allRules.firstWhere(
        (rule) => rule.productId == productId,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (productRule.id.isNotEmpty) return productRule;
    }

    // Find category-specific rule
    if (categoryName != null) {
      final categoryRule = allRules.firstWhere(
        (rule) => rule.categoryName == categoryName,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (categoryRule.id.isNotEmpty) return categoryRule;
    }

    // Return global rule
    return allRules.firstWhere(
      (rule) => rule.isGlobal,
      orElse: () => TaxRule(
        id: '',
        tubo: 0.0,
        isInclusive: true,
        priority: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Add a new tax rule
  static Future<bool> addRule(TaxRule rule) async {
    try {
      final allRules = await getAllRules();

      // Check if we're at the limit
      if (allRules.length >= _maxRules) {
        return false;
      }

      // Check for duplicates
      final exists = allRules.any(
        (existingRule) =>
            existingRule.id == rule.id ||
            (rule.isProduct && existingRule.productId == rule.productId) ||
            (rule.isCategory &&
                existingRule.categoryName == rule.categoryName &&
                existingRule.productId == null) ||
            (rule.isGlobal && existingRule.isGlobal),
      );

      if (exists) {
        return false;
      }

      allRules.add(rule);
      await _saveRules(allRules);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update an existing tax rule
  static Future<bool> updateRule(TaxRule rule) async {
    try {
      final allRules = await getAllRules();
      final index = allRules.indexWhere((r) => r.id == rule.id);

      if (index == -1) return false;

      allRules[index] = rule;
      await _saveRules(allRules);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a tax rule
  static Future<bool> deleteRule(String ruleId) async {
    try {
      final allRules = await getAllRules();
      allRules.removeWhere((rule) => rule.id == ruleId);
      await _saveRules(allRules);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all rules
  static Future<bool> clearAllRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rulesKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save rules to storage
  static Future<void> _saveRules(List<TaxRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = jsonEncode(rules.map((rule) => rule.toMap()).toList());
    await prefs.setString(_rulesKey, rulesJson);
  }

  /// Get available categories from existing rules
  static Future<List<String>> getAvailableCategories() async {
    final allRules = await getAllRules();
    return allRules
        .where((rule) => rule.categoryName != null)
        .map((rule) => rule.categoryName!)
        .toSet()
        .toList()
      ..sort();
  }

  /// Get priority for new rule based on type
  static int getPriorityForNewRule({String? productId, String? categoryName}) {
    if (productId != null) {
      return 100; // Product-specific has highest priority
    } else if (categoryName != null) {
      return 50; // Category-specific has medium priority
    } else {
      return 0; // Global has lowest priority
    }
  }
}
