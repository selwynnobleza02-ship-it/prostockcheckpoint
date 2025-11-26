import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tax_rule.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore/pricing_service.dart';
import 'tax_service.dart';
import 'batch_service.dart';

class TaxRulesService {
  static const String _rulesKey = 'tax_rules';
  // Limit to prevent storage bloat

  // Request-level caching
  static List<TaxRule>? _cachedRules;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(seconds: 30);

  /// Get all tax rules
  static Future<List<TaxRule>> getAllRules({bool forceRefresh = false}) async {
    // Return cached rules if fresh
    if (!forceRefresh && _cachedRules != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        return _cachedRules!;
      }
    }

    // Try Firestore first
    try {
      final pricing = PricingService(FirebaseFirestore.instance);
      final docs = await pricing.getAllRules().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          // Return cached local rules on timeout
          return _getLocalRulesSync();
        },
      );
      final rules = docs.map((m) => TaxRule.fromMap(m)).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
      // Cache locally for offline fallback
      await _writeLocal(rules);
      // Update request-level cache
      _cachedRules = rules;
      _cacheTimestamp = DateTime.now();
      return rules;
    } catch (_) {
      // Fallback to local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final rulesJson = prefs.getString(_rulesKey) ?? '[]';
        final List<dynamic> rulesList = jsonDecode(rulesJson);
        final rules = rulesList.map((rule) => TaxRule.fromMap(rule)).toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
        // Update request-level cache
        _cachedRules = rules;
        _cacheTimestamp = DateTime.now();
        return rules;
      } catch (e) {
        return [];
      }
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

  static Future<void> _writeLocal(List<TaxRule> rules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(rules.map((r) => r.toMap()).toList());
      await prefs.setString(_rulesKey, jsonStr);
    } catch (_) {}
  }

  /// Get local rules synchronously for timeout fallback
  static List<Map<String, dynamic>> _getLocalRulesSync() {
    try {
      // This is a simplified sync version - in practice, we'd need to handle this differently
      // For now, return empty list and let the catch block handle it
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> addRule(TaxRule rule) async {
    try {
      final pricing = PricingService(FirebaseFirestore.instance);

      // Check for conflicts and replace existing rules
      await _replaceConflictingRules(rule, pricing);

      await pricing.upsertRule(rule.id, rule.toMap());

      // Invalidate cache to force refresh on next read
      _cachedRules = null;
      _cacheTimestamp = null;

      // Record price history for affected products (best-effort)
      try {
        await _recordPriceHistoryForRuleChange(
          productId: rule.productId,
          categoryName: rule.categoryName,
          isGlobal: rule.isGlobal,
        );
      } catch (_) {}
      return true;
    } catch (_) {
      // Local fallback
      final existing = await getAllRules();

      // Replace conflicting rules locally
      if (rule.isGlobal) {
        existing.removeWhere((r) => r.isGlobal);
      }
      if (rule.isCategory && (rule.categoryName != null)) {
        existing.removeWhere(
          (r) => r.isCategory && r.categoryName == rule.categoryName,
        );
      }
      if (rule.isProduct && (rule.productId != null)) {
        existing.removeWhere(
          (r) => r.isProduct && r.productId == rule.productId,
        );
      }

      existing.add(rule);
      await _writeLocal(existing);

      // Invalidate cache to force refresh on next read
      _cachedRules = null;
      _cacheTimestamp = null;

      return true;
    }
  }

  /// Check if a rule would conflict with existing rules
  static Future<TaxRule?> checkForConflicts(TaxRule rule) async {
    final existingRules = await getAllRules();

    if (rule.isGlobal) {
      final existingGlobalRule = existingRules.firstWhere(
        (r) => r.isGlobal,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingGlobalRule.id.isNotEmpty) {
        return existingGlobalRule;
      }
    }

    if (rule.isCategory && (rule.categoryName != null)) {
      final existingCategoryRule = existingRules.firstWhere(
        (r) => r.isCategory && r.categoryName == rule.categoryName,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (existingCategoryRule.id.isNotEmpty) {
        return existingCategoryRule;
      }
    }

    if (rule.isProduct && (rule.productId != null)) {
      final existingProductRule = existingRules.firstWhere(
        (r) => r.isProduct && r.productId == rule.productId,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (existingProductRule.id.isNotEmpty) {
        return existingProductRule;
      }
    }

    return null; // No conflicts found
  }

  /// Check for existing rules that would conflict with the new rule and replace them
  static Future<void> _replaceConflictingRules(
    TaxRule rule,
    PricingService pricing,
  ) async {
    final existingRules = await getAllRules();

    if (rule.isGlobal) {
      final existingGlobalRule = existingRules.firstWhere(
        (r) => r.isGlobal,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingGlobalRule.id.isNotEmpty) {
        await pricing.deleteRule(existingGlobalRule.id);
      }
    }

    if (rule.isCategory && (rule.categoryName != null)) {
      final existingCategoryRule = existingRules.firstWhere(
        (r) => r.isCategory && r.categoryName == rule.categoryName,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (existingCategoryRule.id.isNotEmpty) {
        await pricing.deleteRule(existingCategoryRule.id);
      }
    }

    if (rule.isProduct && (rule.productId != null)) {
      final existingProductRule = existingRules.firstWhere(
        (r) => r.isProduct && r.productId == rule.productId,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (existingProductRule.id.isNotEmpty) {
        await pricing.deleteRule(existingProductRule.id);
      }
    }
  }

  static Future<bool> updateRule(TaxRule rule) async {
    try {
      final pricing = PricingService(FirebaseFirestore.instance);
      await pricing.upsertRule(rule.id, rule.toMap());

      // Invalidate cache to force refresh on next read
      _cachedRules = null;
      _cacheTimestamp = null;

      // Record price history for affected products (best-effort)
      try {
        await _recordPriceHistoryForRuleChange(
          productId: rule.productId,
          categoryName: rule.categoryName,
          isGlobal: rule.isGlobal,
        );
      } catch (_) {}
      return true;
    } catch (_) {
      final existing = await getAllRules();
      final idx = existing.indexWhere((r) => r.id == rule.id);
      if (idx != -1) existing[idx] = rule;
      await _writeLocal(existing);

      // Invalidate cache to force refresh on next read
      _cachedRules = null;
      _cacheTimestamp = null;

      return true;
    }
  }

  static Future<bool> deleteRule(String ruleId) async {
    try {
      final pricing = PricingService(FirebaseFirestore.instance);
      // Try to capture the rule before deletion to know affected scope
      TaxRule? toDelete;
      try {
        final rules = await getAllRules();
        toDelete = rules.firstWhere(
          (r) => r.id == ruleId,
          orElse: () => TaxRule(
            id: '',
            tubo: 0.0,
            isInclusive: true,
            priority: -1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (toDelete.id.isEmpty) toDelete = null;
      } catch (_) {}
      await pricing.deleteRule(ruleId);

      // Invalidate cache to force refresh on next read
      _cachedRules = null;
      _cacheTimestamp = null;

      // Record price history for affected products after deletion (best-effort)
      if (toDelete != null) {
        try {
          await _recordPriceHistoryForRuleChange(
            productId: toDelete.productId,
            categoryName: toDelete.categoryName,
            isGlobal: toDelete.isGlobal,
          );
        } catch (_) {}
      }
      return true;
    } catch (_) {
      final existing = await getAllRules();
      existing.removeWhere((r) => r.id == ruleId);
      await _writeLocal(existing);

      // Invalidate cache to force refresh on next read
      _cachedRules = null;
      _cacheTimestamp = null;

      return true;
    }
  }

  // Removed duplicate local-only CRUD; Firestore-backed versions above handle writes

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

  /// Record price history when VAT pricing is implemented.
  /// This method is kept for backward compatibility but now records VAT-based prices.
  /// Note: This is no longer triggered by rule changes since VAT is constant.
  static Future<void> _recordPriceHistoryForRuleChange({
    String? productId,
    String? categoryName,
    bool isGlobal = false,
  }) async {
    // Deprecated: VAT is constant and doesn't change per product/category
    // Rules are no longer used, so this method does nothing
    // Kept for backward compatibility to prevent errors in existing code
    return;
  }

  /// Trigger price recalculation for all products after VAT implementation
  /// This creates price history entries showing the transition from tubo to VAT
  static Future<void> recalculateAllPricesForVAT() async {
    final firestore = FirebaseFirestore.instance;
    final productsCol = firestore.collection('products');
    final priceHistoryCol = firestore.collection('priceHistory');

    try {
      final snap = await productsCol.get();
      if (snap.docs.isEmpty) return;

      final batchService = BatchService();
      final batch = firestore.batch();

      for (final d in snap.docs) {
        final data = d.data();
        final id = d.id;
        final double? manualSellingPrice = (data['selling_price'] as num?)
            ?.toDouble();

        // Get FIFO batch cost (the cost that determines displayed price)
        final batches = await batchService.getBatchesByFIFO(id);
        final double batchCost = batches.isNotEmpty
            ? batches.first.unitCost
            : (data['cost'] as num?)?.toDouble() ?? 0.0;

        // Calculate new VAT-based price
        final calculatedPrice = await TaxService.calculateSellingPriceWithRule(
          batchCost,
          productId: id,
          categoryName: data['category'] as String?,
        );

        // Respect manual override if set, otherwise use calculated price
        final actualPrice = manualSellingPrice ?? calculatedPrice;

        // Check if price changed from last recorded price
        final lastPriceQuery = await priceHistoryCol
            .where('productId', isEqualTo: id)
            .get();

        bool shouldRecord = true;
        if (lastPriceQuery.docs.isNotEmpty) {
          final sortedDocs = lastPriceQuery.docs.toList()
            ..sort((a, b) {
              final aTimestamp = (a.data()['timestamp'] as Timestamp).toDate();
              final bTimestamp = (b.data()['timestamp'] as Timestamp).toDate();
              return bTimestamp.compareTo(aTimestamp);
            });
          final lastPrice =
              (sortedDocs.first.data()['price'] as num?)?.toDouble() ?? 0.0;

          // Only record if price changed (tolerance 0.009)
          if ((actualPrice - lastPrice).abs() <= 0.009) {
            shouldRecord = false;
          }
        }

        if (shouldRecord) {
          final ref = priceHistoryCol.doc();
          batch.set(ref, {
            'productId': id,
            'price': actualPrice,
            'cost': batchCost,
            'timestamp': FieldValue.serverTimestamp(),
            'reason': 'VAT implementation (12%)',
          });
        }
      }

      await batch.commit();
    } catch (e) {
      // Best effort - don't throw
      print('Error recalculating prices for VAT: $e');
    }
  }
}
