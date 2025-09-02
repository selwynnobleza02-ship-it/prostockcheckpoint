import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prostock/utils/error_logger.dart';

class CacheService {
  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString('cache_$key', jsonString);
      await prefs.setString(
        'cache_${key}_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error caching data',
        error: e,
        context: 'CacheService.cacheData',
      );
    }
  }

  Future<T?> getCachedData<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cache_$key');

      if (jsonString != null) {
        final data = jsonDecode(jsonString);
        if (data is List) {
          return data
                  .map((item) => fromJson(item as Map<String, dynamic>))
                  .toList()
              as T;
        } else if (data is Map<String, dynamic>) {
          return fromJson(data);
        }
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error getting cached data',
        error: e,
        context: 'CacheService.getCachedData',
      );
    }
    return null;
  }

  Future<bool> isCacheValid(String key, Duration maxAge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString('cache_${key}_timestamp');

      if (timestampString != null) {
        final timestamp = DateTime.parse(timestampString);
        return DateTime.now().difference(timestamp) < maxAge;
      }
    } catch (e) {
      ErrorLogger.logError(
        'Error checking cache validity',
        error: e,
        context: 'CacheService.isCacheValid',
      );
    }
    return false;
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('cache_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      ErrorLogger.logInfo(
        'Cache cleared',
        context: 'CacheService.clearCache',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error clearing cache',
        error: e,
        context: 'CacheService.clearCache',
      );
    }
  }

  Future<void> saveLastSyncTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', time.toIso8601String());
    } catch (e) {
      ErrorLogger.logError(
        'Error saving last sync time',
        error: e,
        context: 'CacheService.saveLastSyncTime',
      );
    }
  }
}
