import 'dart:math';

import 'package:prostock/models/product.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemandSuggestion {
  final Product product;
  final double velocityPerDay;
  final int currentThreshold;
  final int suggestedThreshold;

  DemandSuggestion({
    required this.product,
    required this.velocityPerDay,
    required this.currentThreshold,
    required this.suggestedThreshold,
  });
}

class DemandAnalysisService {
  final LocalDatabaseService _db;
  final NotificationService _notificationService;

  DemandAnalysisService(this._db, this._notificationService);

  static const String _prefsSnoozeKey =
      'demand_snooze_until'; // map<productId, isoString>
  static const String _prefsLastSuggestedAtKey =
      'demand_last_suggested_at'; // map<productId, isoString>
  static const String _prefsLastAcceptedAtKey =
      'demand_last_accepted_at'; // map<productId, isoString>

  Future<List<DemandSuggestion>> computeSuggestions({
    int windowDays = 7,
    int fallbackWindowDays = 30,
    double highDemandThresholdPerDay = 20.0,
    int leadTimeDays = 2,
    int minDeltaUnits = 5,
    double minDeltaPercent = 0.2,
  }) async {
    final products = await _db.getAllProducts();

    // Load sales within fallback window
    final since = DateTime.now().subtract(Duration(days: fallbackWindowDays));
    final sales = await _db.getSalesSince(since);
    final saleIds = sales.map((s) => s['id'].toString()).toList();
    final saleItems = await _db.getSaleItemsBySaleIds(saleIds);

    // Aggregate quantities by productId -> dateString -> qty
    final Map<String, Map<String, int>> perDay = {};
    for (final item in saleItems) {
      final saleId = item['saleId']?.toString();
      final sale = sales.firstWhere(
        (s) => s['id'].toString() == saleId,
        orElse: () => {},
      );
      if (sale.isEmpty) continue;
      final createdAt = DateTime.tryParse(sale['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      if (createdAt.isBefore(since)) continue;
      final productId = item['productId']?.toString();
      if (productId == null) continue;
      final dateKey = DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
      ).toIso8601String();
      final qty = (item['quantity'] as int?) ?? 0;
      perDay.putIfAbsent(productId, () => {});
      perDay[productId]![dateKey] = (perDay[productId]![dateKey] ?? 0) + qty;
    }

    // Compute velocity and suggestions
    final Map<String, Product> productMap = {
      for (final p in products)
        if (p.id != null) p.id!: p,
    };
    final List<DemandSuggestion> suggestions = [];

    final now = DateTime.now();

    for (final entry in perDay.entries) {
      final productId = entry.key;
      final product = productMap[productId];
      if (product == null) continue;

      // Build series for windowDays; if sparse, extend to fallbackWindowDays
      double totalQtyWindow = 0;
      int daysCounted = 0;
      for (int i = 0; i < windowDays; i++) {
        final d = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        final k = DateTime(d.year, d.month, d.day).toIso8601String();
        totalQtyWindow += (entry.value[k] ?? 0).toDouble();
        daysCounted += 1;
      }
      double velocity = daysCounted > 0 ? (totalQtyWindow / daysCounted) : 0.0;

      if (velocity < highDemandThresholdPerDay) {
        // Try fallback window if within 30 days the avg could qualify
        double totalQtyFallback = 0;
        for (int i = 0; i < fallbackWindowDays; i++) {
          final d = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: i));
          final k = DateTime(d.year, d.month, d.day).toIso8601String();
          totalQtyFallback += (entry.value[k] ?? 0).toDouble();
        }
        final velocityFallback = totalQtyFallback / max(1, fallbackWindowDays);
        velocity = velocityFallback;
      }

      if (velocity >= highDemandThresholdPerDay) {
        final suggested = (velocity * (leadTimeDays + 1)).ceil();
        final current = product.minStock;
        final deltaUnits = suggested - current;
        final deltaPercent = current > 0 ? deltaUnits / current : 1.0;
        if (deltaUnits >= minDeltaUnits || deltaPercent >= minDeltaPercent) {
          if (await _isEligibleToSuggest(productId, now)) {
            suggestions.add(
              DemandSuggestion(
                product: product,
                velocityPerDay: velocity,
                currentThreshold: current,
                suggestedThreshold: min(
                  current + max(deltaUnits, 0),
                  current + max(5, (current * 0.5).ceil()),
                ),
              ),
            );
          }
        }
      }
    }

    // Sort by biggest gap first
    suggestions.sort(
      (a, b) => (b.suggestedThreshold - b.currentThreshold).compareTo(
        a.suggestedThreshold - a.currentThreshold,
      ),
    );

    return suggestions;
  }

  Future<bool> _isEligibleToSuggest(String productId, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final snoozeMap = Map<String, String>.from(
      (prefs.getStringList(_prefsSnoozeKey) ?? []).fold<Map<String, String>>(
        {},
        (m, s) {
          final parts = s.split('|');
          if (parts.length == 2) m[parts[0]] = parts[1];
          return m;
        },
      ),
    );
    final snoozedUntilStr = snoozeMap[productId];
    if (snoozedUntilStr != null) {
      final snoozedUntil = DateTime.tryParse(snoozedUntilStr);
      if (snoozedUntil != null && snoozedUntil.isAfter(now)) return false;
    }
    // Cooldown after accept: 30 days
    final acceptedMap = Map<String, String>.from(
      (prefs.getStringList(_prefsLastAcceptedAtKey) ?? [])
          .fold<Map<String, String>>({}, (m, s) {
            final parts = s.split('|');
            if (parts.length == 2) m[parts[0]] = parts[1];
            return m;
          }),
    );
    final acceptedAtStr = acceptedMap[productId];
    if (acceptedAtStr != null) {
      final acceptedAt = DateTime.tryParse(acceptedAtStr);
      if (acceptedAt != null &&
          acceptedAt.isAfter(now.subtract(const Duration(days: 30)))) {
        return false;
      }
    }
    return true;
  }

  Future<void> markSuggestedNow(List<String> productIds) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsLastSuggestedAtKey) ?? [];
    final Map<String, String> map = {};
    for (final s in list) {
      final parts = s.split('|');
      if (parts.length == 2) map[parts[0]] = parts[1];
    }
    final now = DateTime.now().toIso8601String();
    for (final id in productIds) {
      map[id] = now;
    }
    prefs.setStringList(
      _prefsLastSuggestedAtKey,
      map.entries.map((e) => '${e.key}|${e.value}').toList(),
    );
  }

  Future<void> snooze(
    String productId, {
    Duration duration = const Duration(days: 7),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsSnoozeKey) ?? [];
    final Map<String, String> map = {};
    for (final s in list) {
      final parts = s.split('|');
      if (parts.length == 2) map[parts[0]] = parts[1];
    }
    map[productId] = DateTime.now().add(duration).toIso8601String();
    prefs.setStringList(
      _prefsSnoozeKey,
      map.entries.map((e) => '${e.key}|${e.value}').toList(),
    );
  }

  Future<void> acceptSuggestion(String productId, int newThreshold) async {
    // Update local DB min_stock; queue remote via OfflineManager is handled elsewhere
    await _db.updateProductMinStock(productId, newThreshold);
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsLastAcceptedAtKey) ?? [];
    final Map<String, String> map = {};
    for (final s in list) {
      final parts = s.split('|');
      if (parts.length == 2) map[parts[0]] = parts[1];
    }
    map[productId] = DateTime.now().toIso8601String();
    prefs.setStringList(
      _prefsLastAcceptedAtKey,
      map.entries.map((e) => '${e.key}|${e.value}').toList(),
    );
  }

  Future<int> runDailyAndNotify() async {
    final suggestions = await computeSuggestions();
    if (suggestions.isNotEmpty) {
      await markSuggestedNow(suggestions.map((s) => s.product.id!).toList());
      await _notificationService.showNotification(
        4001,
        'High demand detected',
        'Review ${suggestions.length} product(s) to adjust low-stock thresholds',
        'inventory_suggestions',
      );
    }
    return suggestions.length;
  }
}
