import 'dart:math';
import 'package:prostock/models/batch_allocation.dart';
import 'package:prostock/models/inventory_batch.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:uuid/uuid.dart';

/// Service for managing inventory batches with FIFO logic
class BatchService {
  final LocalDatabaseService _db = LocalDatabaseService.instance;

  /// Generate a unique batch number
  String generateBatchNumber({String? productId}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999);
    final prefix = productId != null
        ? productId.substring(0, min(4, productId.length)).toUpperCase()
        : 'BATCH';
    return '$prefix-$timestamp-$random';
  }

  /// Get all batches for a product ordered by FIFO (oldest first)
  Future<List<InventoryBatch>> getBatchesByFIFO(String productId) async {
    try {
      final maps = await _db.database.then(
        (db) => db.query(
          'inventory_batches',
          where: 'product_id = ? AND quantity_remaining > 0',
          whereArgs: [productId],
          orderBy: 'date_received ASC', // FIFO: oldest first
        ),
      );

      return maps.map((map) => InventoryBatch.fromMap(map)).toList();
    } catch (e) {
      ErrorLogger.logError(
        'Error getting batches by FIFO',
        error: e,
        context: 'BatchService.getBatchesByFIFO',
      );
      return [];
    }
  }

  /// Get all batches for a product (including depleted)
  Future<List<InventoryBatch>> getAllBatches(String productId) async {
    try {
      final maps = await _db.database.then(
        (db) => db.query(
          'inventory_batches',
          where: 'product_id = ?',
          whereArgs: [productId],
          orderBy: 'date_received DESC', // Newest first for display
        ),
      );

      return maps.map((map) => InventoryBatch.fromMap(map)).toList();
    } catch (e) {
      ErrorLogger.logError(
        'Error getting all batches',
        error: e,
        context: 'BatchService.getAllBatches',
      );
      return [];
    }
  }

  /// Allocate stock using FIFO method
  /// Returns list of batch allocations needed to fulfill the quantity
  /// Throws InsufficientStockException if not enough stock available
  Future<List<BatchAllocation>> allocateStockFIFO(
    String productId,
    int quantityNeeded,
  ) async {
    try {
      final batches = await getBatchesByFIFO(productId);

      List<BatchAllocation> allocations = [];
      int remainingQty = quantityNeeded;

      for (final batch in batches) {
        if (remainingQty <= 0) break;
        if (!batch.hasStock) continue;

        // Take from this batch
        final qtyFromBatch = min(batch.quantityRemaining, remainingQty);

        allocations.add(
          BatchAllocation(
            batchId: batch.id,
            batchNumber: batch.batchNumber,
            quantity: qtyFromBatch,
            unitCost: batch.unitCost,
            dateReceived: batch.dateReceived,
          ),
        );

        remainingQty -= qtyFromBatch;
      }

      // Check if we have enough stock
      if (remainingQty > 0) {
        final available = quantityNeeded - remainingQty;
        throw InsufficientStockException(
          message:
              'Insufficient stock. Need $quantityNeeded, only $available available',
          requested: quantityNeeded,
          available: available,
        );
      }

      return allocations;
    } catch (e) {
      if (e is InsufficientStockException) rethrow;

      ErrorLogger.logError(
        'Error allocating stock FIFO',
        error: e,
        context: 'BatchService.allocateStockFIFO',
      );
      rethrow;
    }
  }

  /// Create a new batch
  Future<InventoryBatch> createBatch({
    required String productId,
    required int quantity,
    required double unitCost,
    String? supplierId,
    String? notes,
    String? customBatchNumber,
  }) async {
    try {
      final batch = InventoryBatch(
        id: const Uuid().v4(),
        productId: productId,
        batchNumber:
            customBatchNumber ?? generateBatchNumber(productId: productId),
        quantityReceived: quantity,
        quantityRemaining: quantity,
        unitCost: unitCost,
        dateReceived: DateTime.now(),
        supplierId: supplierId,
        notes: notes,
      );

      await _db.database.then(
        (db) => db.insert('inventory_batches', batch.toMap()),
      );

      return batch;
    } catch (e) {
      ErrorLogger.logError(
        'Error creating batch',
        error: e,
        context: 'BatchService.createBatch',
      );
      rethrow;
    }
  }

  /// Reduce batch quantity (called during sales)
  Future<void> reduceBatchQuantity(String batchId, int quantity) async {
    try {
      final db = await _db.database;

      // Get current batch
      final maps = await db.query(
        'inventory_batches',
        where: 'id = ?',
        whereArgs: [batchId],
      );

      if (maps.isEmpty) {
        throw Exception('Batch not found: $batchId');
      }

      final batch = InventoryBatch.fromMap(maps.first);

      if (batch.quantityRemaining < quantity) {
        throw Exception(
          'Insufficient batch stock. Batch ${batch.batchNumber} has ${batch.quantityRemaining}, need $quantity',
        );
      }

      final newQuantity = batch.quantityRemaining - quantity;

      await db.update(
        'inventory_batches',
        {
          'quantity_remaining': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [batchId],
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error reducing batch quantity',
        error: e,
        context: 'BatchService.reduceBatchQuantity',
      );
      rethrow;
    }
  }

  /// Get total available stock for a product across all batches
  Future<int> getTotalAvailableStock(String productId) async {
    try {
      final batches = await getBatchesByFIFO(productId);
      return batches.fold<int>(
        0,
        (sum, batch) => sum + batch.quantityRemaining,
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error getting total available stock',
        error: e,
        context: 'BatchService.getTotalAvailableStock',
      );
      return 0;
    }
  }

  /// Calculate weighted average cost across all batches
  Future<double> calculateAverageCost(String productId) async {
    try {
      final batches = await getBatchesByFIFO(productId);

      if (batches.isEmpty) return 0.0;

      double totalValue = 0.0;
      int totalQuantity = 0;

      for (final batch in batches) {
        totalValue += batch.quantityRemaining * batch.unitCost;
        totalQuantity += batch.quantityRemaining;
      }

      return totalQuantity > 0 ? totalValue / totalQuantity : 0.0;
    } catch (e) {
      ErrorLogger.logError(
        'Error calculating average cost',
        error: e,
        context: 'BatchService.calculateAverageCost',
      );
      return 0.0;
    }
  }

  /// Get batch by ID
  Future<InventoryBatch?> getBatchById(String batchId) async {
    try {
      final maps = await _db.database.then(
        (db) => db.query(
          'inventory_batches',
          where: 'id = ?',
          whereArgs: [batchId],
        ),
      );

      if (maps.isEmpty) return null;
      return InventoryBatch.fromMap(maps.first);
    } catch (e) {
      ErrorLogger.logError(
        'Error getting batch by ID',
        error: e,
        context: 'BatchService.getBatchById',
      );
      return null;
    }
  }

  /// Delete a batch (only if not referenced in sales)
  Future<void> deleteBatch(String batchId) async {
    try {
      await _db.database.then(
        (db) => db.delete(
          'inventory_batches',
          where: 'id = ?',
          whereArgs: [batchId],
        ),
      );
    } catch (e) {
      ErrorLogger.logError(
        'Error deleting batch',
        error: e,
        context: 'BatchService.deleteBatch',
      );
      rethrow;
    }
  }
}
