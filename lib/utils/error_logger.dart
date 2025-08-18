import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';

class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._internal();
  factory ErrorLogger() => _instance;
  ErrorLogger._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<ErrorLog> _localErrors = [];

  // Log error with context
  static void logError(
    String message, {
    String? context,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final errorLog = ErrorLog(
      message: message,
      context: context ?? 'Unknown',
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint('[ERROR] ${errorLog.context}: ${errorLog.message}');
      if (errorLog.error != null) {
        debugPrint('[ERROR] Details: ${errorLog.error}');
      }
    }

    // Store locally
    _instance._localErrors.add(errorLog);

    // Keep only last 100 errors in memory
    if (_instance._localErrors.length > 100) {
      _instance._localErrors.removeAt(0);
    }

    // Try to log to Firestore (non-blocking)
    _instance._logToFirestore(errorLog);
  }

  // Log warning
  static void logWarning(
    String message, {
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('[WARNING] ${context ?? 'Unknown'}: $message');
    }
  }

  // Log info
  static void logInfo(
    String message, {
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('[INFO] ${context ?? 'Unknown'}: $message');
    }
  }

  Future<void> _logToFirestore(ErrorLog errorLog) async {
    try {
      await _firestore.collection(AppConstants.errorLogsCollection).add(errorLog.toMap());
    } catch (e) {
      // Don't throw errors from error logging
      if (kDebugMode) {
        debugPrint('[ERROR_LOGGER] Failed to log to Firestore: $e');
      }
    }
  }

  // Get recent errors for debugging
  List<ErrorLog> getRecentErrors({int limit = 50}) {
    return _localErrors.take(limit).toList();
  }

  // Clear local error cache
  void clearLocalErrors() {
    _localErrors.clear();
  }
}

class ErrorLog {
  final String message;
  final String context;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  ErrorLog({
    required this.message,
    required this.context,
    this.error,
    this.stackTrace,
    required this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'context': context,
      'error': error,
      'stackTrace': stackTrace,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'platform': 'flutter',
    };
  }

  factory ErrorLog.fromMap(Map<String, dynamic> map) {
    return ErrorLog(
      message: map['message'] ?? '',
      context: map['context'] ?? 'Unknown',
      error: map['error'],
      stackTrace: map['stackTrace'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
