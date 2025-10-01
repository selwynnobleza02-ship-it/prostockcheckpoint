import 'package:uuid/uuid.dart';

/// Base interface for all idempotent operations
/// Ensures operations can be safely repeated without side effects
abstract class IdempotentOperation {
  /// Unique identifier for this operation instance
  String get operationId;

  /// Type of operation for routing and processing
  String get operationType;

  /// Timestamp when operation was created
  DateTime get timestamp;

  /// Version for conflict resolution
  int get version;

  /// Priority for operation execution (higher = more urgent)
  int get priority => 0;

  /// Execute the operation and return result
  Future<OperationResult> execute();

  /// Check if operation can be retried on failure
  bool canRetry();

  /// Serialize operation to map for storage/transmission
  Map<String, dynamic> toMap();

  /// Create operation from map (for deserialization)
  /// This will be implemented by specific operation types
  static IdempotentOperation? fromMap(Map<String, dynamic> map) {
    // Default implementation returns null
    // Specific operation types will override this method
    return null;
  }

  /// Validate operation data before execution
  bool validate();
}

/// Result of an operation execution
class OperationResult {
  final bool isSuccess;
  final dynamic data;
  final String? error;
  final String? errorCode;
  final DateTime timestamp;
  final Duration executionTime;

  const OperationResult({
    required this.isSuccess,
    this.data,
    this.error,
    this.errorCode,
    required this.timestamp,
    required this.executionTime,
  });

  factory OperationResult.success(dynamic data, {Duration? executionTime}) {
    return OperationResult(
      isSuccess: true,
      data: data,
      timestamp: DateTime.now(),
      executionTime: executionTime ?? Duration.zero,
    );
  }

  factory OperationResult.failure(
    String error, {
    String? errorCode,
    Duration? executionTime,
  }) {
    return OperationResult(
      isSuccess: false,
      error: error,
      errorCode: errorCode,
      timestamp: DateTime.now(),
      executionTime: executionTime ?? Duration.zero,
    );
  }
}

/// Transaction result for batch operations
class TransactionResult {
  final bool isSuccess;
  final List<OperationResult> results;
  final String? transactionId;
  final String? error;
  final DateTime timestamp;

  const TransactionResult({
    required this.isSuccess,
    required this.results,
    this.transactionId,
    this.error,
    required this.timestamp,
  });

  factory TransactionResult.success(
    List<OperationResult> results, {
    String? transactionId,
  }) {
    return TransactionResult(
      isSuccess: true,
      results: results,
      transactionId: transactionId,
      timestamp: DateTime.now(),
    );
  }

  factory TransactionResult.failure(String error, {String? transactionId}) {
    return TransactionResult(
      isSuccess: false,
      results: [],
      transactionId: transactionId,
      error: error,
      timestamp: DateTime.now(),
    );
  }
}

/// Base class for all operations with common functionality
abstract class BaseOperation implements IdempotentOperation {
  @override
  final String operationId;

  @override
  final String operationType;

  @override
  final DateTime timestamp;

  @override
  final int version;

  @override
  final int priority;

  BaseOperation({
    String? operationId,
    required this.operationType,
    DateTime? timestamp,
    this.version = 1,
    this.priority = 0,
  }) : operationId = operationId ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  @override
  bool validate() {
    return operationId.isNotEmpty && operationType.isNotEmpty && version > 0;
  }

  @override
  bool canRetry() {
    return true; // Default: all operations can be retried
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'operationType': operationType,
      'timestamp': timestamp.toIso8601String(),
      'version': version,
      'priority': priority,
    };
  }
}
