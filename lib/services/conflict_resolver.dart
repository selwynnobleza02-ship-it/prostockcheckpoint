import 'package:prostock/utils/error_logger.dart';

/// Resolves conflicts between local and remote data
class ConflictResolver {
  bool _isInitialized = false;

  ConflictResolver();

  /// Initialize the conflict resolver
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    ErrorLogger.logInfo(
      'ConflictResolver initialized',
      context: 'ConflictResolver.initialize',
    );
  }

  /// Resolve conflict between local and remote data
  Future<ConflictResolution> resolveConflict(
    ConflictData local,
    ConflictData remote,
  ) async {
    if (!_isInitialized) {
      throw StateError('ConflictResolver not initialized');
    }

    ErrorLogger.logInfo(
      'Resolving conflict for ${local.id}',
      context: 'ConflictResolver.resolveConflict',
    );

    // Strategy 1: Version-based resolution
    if (local.version != null && remote.version != null) {
      if (local.version! > remote.version!) {
        ErrorLogger.logInfo(
          'Using local data (higher version: ${local.version} vs ${remote.version})',
          context: 'ConflictResolver.resolveConflict',
        );
        return ConflictResolution.useLocal(local);
      } else if (remote.version! > local.version!) {
        ErrorLogger.logInfo(
          'Using remote data (higher version: ${remote.version} vs ${local.version})',
          context: 'ConflictResolver.resolveConflict',
        );
        return ConflictResolution.useRemote(remote);
      }
    }

    // Strategy 2: Timestamp-based resolution
    if (local.lastModified != null && remote.lastModified != null) {
      if (local.lastModified!.isAfter(remote.lastModified!)) {
        ErrorLogger.logInfo(
          'Using local data (newer timestamp)',
          context: 'ConflictResolver.resolveConflict',
        );
        return ConflictResolution.useLocal(local);
      } else if (remote.lastModified!.isAfter(local.lastModified!)) {
        ErrorLogger.logInfo(
          'Using remote data (newer timestamp)',
          context: 'ConflictResolver.resolveConflict',
        );
        return ConflictResolution.useRemote(remote);
      }
    }

    // Strategy 3: Merge resolution
    ErrorLogger.logInfo(
      'Attempting to merge data for ${local.id}',
      context: 'ConflictResolver.resolveConflict',
    );

    return ConflictResolution.merge(await _mergeData(local, remote));
  }

  /// Merge local and remote data
  Future<ConflictData> _mergeData(
    ConflictData local,
    ConflictData remote,
  ) async {
    // Create merged data with local as base
    final mergedData = Map<String, dynamic>.from(local.data);

    // Merge non-conflicting fields from remote
    for (final entry in remote.data.entries) {
      if (!mergedData.containsKey(entry.key)) {
        mergedData[entry.key] = entry.value;
      } else if (mergedData[entry.key] != entry.value) {
        // Handle conflicting fields based on type
        mergedData[entry.key] = await _mergeField(
          entry.key,
          mergedData[entry.key],
          entry.value,
        );
      }
    }

    return ConflictData(
      id: local.id,
      data: mergedData,
      version: (local.version ?? 0) + 1,
      lastModified: DateTime.now(),
      source: ConflictSource.merged,
    );
  }

  /// Merge individual fields
  Future<dynamic> _mergeField(
    String fieldName,
    dynamic localValue,
    dynamic remoteValue,
  ) async {
    // Handle different field types
    if (localValue is String && remoteValue is String) {
      // For strings, prefer the longer one (more complete)
      return localValue.length >= remoteValue.length ? localValue : remoteValue;
    } else if (localValue is num && remoteValue is num) {
      // For numbers, prefer the higher value
      return localValue >= remoteValue ? localValue : remoteValue;
    } else if (localValue is Map && remoteValue is Map) {
      // For maps, merge recursively
      final merged = Map<String, dynamic>.from(localValue);
      for (final entry in remoteValue.entries) {
        if (!merged.containsKey(entry.key)) {
          merged[entry.key] = entry.value;
        }
      }
      return merged;
    } else if (localValue is List && remoteValue is List) {
      // For lists, combine and remove duplicates
      final combined = List.from(localValue);
      for (final item in remoteValue) {
        if (!combined.contains(item)) {
          combined.add(item);
        }
      }
      return combined;
    } else {
      // For other types, prefer local value
      return localValue;
    }
  }

  /// Get conflict resolution strategy for specific data type
  ConflictResolutionStrategy getStrategy(String dataType) {
    switch (dataType.toLowerCase()) {
      case 'sale':
        return ConflictResolutionStrategy.lastWriteWins;
      case 'product':
        return ConflictResolutionStrategy.merge;
      case 'customer':
        return ConflictResolutionStrategy.merge;
      case 'stock':
        return ConflictResolutionStrategy.merge;
      default:
        return ConflictResolutionStrategy.lastWriteWins;
    }
  }
}

/// Represents data involved in a conflict
class ConflictData {
  final String id;
  final Map<String, dynamic> data;
  final int? version;
  final DateTime? lastModified;
  final ConflictSource source;

  const ConflictData({
    required this.id,
    required this.data,
    this.version,
    this.lastModified,
    this.source = ConflictSource.unknown,
  });
}

/// Source of conflict data
enum ConflictSource { local, remote, merged, unknown }

/// Result of conflict resolution
class ConflictResolution {
  final ConflictResolutionType type;
  final ConflictData? data;
  final String? reason;

  const ConflictResolution({required this.type, this.data, this.reason});

  factory ConflictResolution.useLocal(ConflictData data) {
    return ConflictResolution(
      type: ConflictResolutionType.useLocal,
      data: data,
      reason: 'Local data is newer or more complete',
    );
  }

  factory ConflictResolution.useRemote(ConflictData data) {
    return ConflictResolution(
      type: ConflictResolutionType.useRemote,
      data: data,
      reason: 'Remote data is newer or more complete',
    );
  }

  factory ConflictResolution.merge(ConflictData data) {
    return ConflictResolution(
      type: ConflictResolutionType.merge,
      data: data,
      reason: 'Data merged from both sources',
    );
  }

  factory ConflictResolution.manual(ConflictData data) {
    return ConflictResolution(
      type: ConflictResolutionType.manual,
      data: data,
      reason: 'Manual resolution required',
    );
  }
}

/// Type of conflict resolution
enum ConflictResolutionType { useLocal, useRemote, merge, manual }

/// Strategy for conflict resolution
enum ConflictResolutionStrategy { lastWriteWins, firstWriteWins, merge, manual }

