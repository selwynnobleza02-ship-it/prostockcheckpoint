import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Operation Type Enumeration - Defines all supported offline operations
enum OperationType {
  insertProduct,
  updateProduct,
  insertCustomer,
  updateCustomer,
  createSaleTransaction,
  insertCreditTransaction,
  updateCustomerBalance,
  insertLoss,
  insertPriceHistory,
}

/// Offline Operation Model - Serializable operation container
///
/// OPERATION STRUCTURE:
/// - Unique ID for deduplication and tracking
/// - Operation type for proper execution routing
/// - Serialized data payload with all necessary information
/// - Timestamp for chronological processing and conflict resolution
class OfflineOperation {
  final int? dbId;
  final String id;
  final OperationType type;
  final String collectionName;
  final String? documentId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  final int? version;

  OfflineOperation({
    this.dbId,
    String? id,
    required this.type,
    required this.collectionName,
    this.documentId,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.version,
  }) : id = id ?? const Uuid().v4();

  OfflineOperation copyWith({
    int? dbId,
    String? id,
    OperationType? type,
    String? collectionName,
    String? documentId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
    int? version,
  }) {
    return OfflineOperation(
      dbId: dbId ?? this.dbId,
      id: id ?? this.id,
      type: type ?? this.type,
      collectionName: collectionName ?? this.collectionName,
      documentId: documentId ?? this.documentId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operation_id': id,
      'operation_type': type.toString().split('.').last,
      'collection_name': collectionName,
      'document_id': documentId,
      'data': jsonEncode(data),
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
      'version': version,
    };
  }

  factory OfflineOperation.fromMap(Map<String, dynamic> map) {
    return OfflineOperation(
      dbId: map['id'] as int,
      id: map['operation_id'] as String,
      type: OperationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['operation_type'],
      ),
      collectionName: map['collection_name'] as String,
      documentId: map['document_id'] as String?,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      timestamp: DateTime.parse(map['timestamp'] as String),
      retryCount: map['retry_count'] ?? 0,
      version: map['version'] as int?,
    );
  }
}
