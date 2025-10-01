import 'dart:async';
import 'package:prostock/utils/error_logger.dart';

/// Query handler for CQRS pattern
class QueryHandler {
  final Map<String, QueryHandlerFunction<Query, dynamic>> _handlers = {};

  QueryHandler();

  /// Register a query handler
  void registerHandler<T extends Query, R>(
    String queryType,
    QueryHandlerFunction<T, R> handler,
  ) {
    _handlers[queryType] = handler as QueryHandlerFunction<Query, dynamic>;
    ErrorLogger.logInfo(
      'Query handler registered for $queryType',
      context: 'QueryHandler.registerHandler',
    );
  }

  /// Handle a query
  Future<QueryResult<R>> handle<R>(Query query) async {
    try {
      final handler = _handlers[query.runtimeType.toString()];
      if (handler == null) {
        throw Exception('No handler registered for ${query.runtimeType}');
      }

      ErrorLogger.logInfo(
        'Handling query ${query.runtimeType}',
        context: 'QueryHandler.handle',
        metadata: {'queryId': query.id},
      );

      // Execute query handler
      final result = await handler(query);
      return QueryResult.success(result);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to handle query ${query.runtimeType}',
        error: e,
        context: 'QueryHandler.handle',
      );
      return QueryResult.failure('Query handling failed: ${e.toString()}');
    }
  }
}

/// Base query interface
abstract class Query {
  final String id;
  final DateTime timestamp;

  Query({String? id, DateTime? timestamp})
    : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp = timestamp ?? DateTime.now();
}

/// Query handler function type
typedef QueryHandlerFunction<T extends Query, R> = Future<R> Function(T query);

/// Result of query execution
class QueryResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  QueryResult._({required this.isSuccess, this.data, this.error});

  factory QueryResult.success(T data) {
    return QueryResult._(isSuccess: true, data: data);
  }

  factory QueryResult.failure(String error) {
    return QueryResult._(isSuccess: false, error: error);
  }
}

/// Specific query implementations
class GetSalesQuery extends Query {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
  final int? offset;

  GetSalesQuery({
    this.startDate,
    this.endDate,
    this.limit,
    this.offset,
    super.id,
    super.timestamp,
  });
}

class GetSalesByCustomerQuery extends Query {
  final String customerId;
  final DateTime? startDate;
  final DateTime? endDate;

  GetSalesByCustomerQuery({
    required this.customerId,
    this.startDate,
    this.endDate,
    super.id,
    super.timestamp,
  });
}

class GetCreditTransactionsQuery extends Query {
  final String? customerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  GetCreditTransactionsQuery({
    this.customerId,
    this.startDate,
    this.endDate,
    this.limit,
    super.id,
    super.timestamp,
  });
}

class GetProductStockQuery extends Query {
  final String productId;

  GetProductStockQuery({required this.productId, super.id, super.timestamp});
}

class GetOverdueCustomersQuery extends Query {
  final DateTime? asOfDate;

  GetOverdueCustomersQuery({this.asOfDate, super.id, super.timestamp});
}
