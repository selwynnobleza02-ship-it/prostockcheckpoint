import 'package:prostock/models/offline_operation.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';

class OperationQueueService {
  final LocalDatabaseService _localDatabaseService;

  OperationQueueService(this._localDatabaseService);

  Future<void> queueOperation(OfflineOperation operation) async {
    if (operation.type == OperationType.createSaleTransaction) {
      final saleMap = operation.data['sale'] as Map<String, dynamic>;
      final sale = Sale.fromMap(saleMap).copyWith(isSynced: 0);
      final saleItems = (operation.data['saleItems'] as List)
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList();

      await _localDatabaseService.insertSale(sale.toMap());
      for (final item in saleItems) {
        await _localDatabaseService.insertSaleItem(item.toMap());
      }
    }

    try {
      final db = await _localDatabaseService.database;
      await db.insert('offline_operations', operation.toMap());
      ErrorLogger.logInfo(
        'Queued operation: ${operation.type} - ${operation.id}',
        context: 'OperationQueueService.queueOperation',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error queuing operation',
        error: e,
        context: 'OperationQueueService.queueOperation',
      );
    }
  }

  Future<List<OfflineOperation>> getPendingOperations() async {
    try {
      final db = await _localDatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'offline_operations',
      );
      return List.generate(maps.length, (i) {
        return OfflineOperation.fromMap(maps[i]);
      });
    } catch (e) {
      ErrorLogger.logError(
        'Error loading pending operations from DB',
        error: e,
        context: 'OperationQueueService.getPendingOperations',
      );
      return [];
    }
  }

  Future<void> clearPendingOperations() async {
    try {
      final db = await _localDatabaseService.database;
      await db.delete('offline_operations');
      ErrorLogger.logInfo(
        'Pending operations cleared',
        context: 'OperationQueueService.clearPendingOperations',
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error clearing pending operations',
        error: e,
        context: 'OperationQueueService.clearPendingOperations',
      );
    }
  }

  Future<List<Sale>> getPendingSales() async {
    final db = await _localDatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) {
      return Sale.fromMap(maps[i]);
    });
  }
}
