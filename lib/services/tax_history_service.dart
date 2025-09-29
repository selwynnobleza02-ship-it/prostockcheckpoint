import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/tax_settings_history.dart';

class TaxHistoryService {
  static const String _historyKey = 'tax_settings_history';
  static const int _maxHistoryEntries = 50; // Keep last 50 changes

  /// Add a new tubo settings change to history
  static Future<void> addHistoryEntry({
    required String changedByUserId,
    required String changedByUserName,
    double? oldAmount,
    double? newAmount,
    bool? oldInclusive,
    bool? newInclusive,
    required String source,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> historyList = jsonDecode(historyJson);

      final newEntry = TaxSettingsHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        changedByUserId: changedByUserId,
        changedByUserName: changedByUserName,
        oldAmount: oldAmount,
        newAmount: newAmount,
        oldInclusive: oldInclusive,
        newInclusive: newInclusive,
        timestamp: DateTime.now(),
        source: source,
      );

      // Add new entry at the beginning
      historyList.insert(0, newEntry.toMap());

      // Keep only the last _maxHistoryEntries
      if (historyList.length > _maxHistoryEntries) {
        historyList.removeRange(_maxHistoryEntries, historyList.length);
      }

      await prefs.setString(_historyKey, jsonEncode(historyList));
    } catch (e) {
      // Silently fail - history is not critical
      print('Failed to save tax history: $e');
    }
  }

  /// Get tax settings history
  static Future<List<TaxSettingsHistory>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> historyList = jsonDecode(historyJson);

      return historyList
          .map((entry) => TaxSettingsHistory.fromMap(entry))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent history (last 20 entries)
  static Future<List<TaxSettingsHistory>> getRecentHistory() async {
    final history = await getHistory();
    return history.take(20).toList();
  }

  /// Clear all history
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Failed to clear tax history: $e');
    }
  }
}
