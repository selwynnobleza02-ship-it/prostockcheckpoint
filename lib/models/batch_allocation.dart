/// Represents allocation of stock from a specific batch during a sale
/// Used internally by FIFO logic to track which batches contribute to a sale
class BatchAllocation {
  final String batchId;
  final String batchNumber;
  final int quantity;
  final double unitCost;
  final DateTime dateReceived;

  BatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    required this.unitCost,
    required this.dateReceived,
  });

  double get totalCost => quantity * unitCost;

  @override
  String toString() {
    return 'BatchAllocation(batch: $batchNumber, qty: $quantity @ ₱$unitCost)';
  }
}

/// Exception thrown when there's insufficient stock across all batches
class InsufficientStockException implements Exception {
  final String message;
  final int requested;
  final int available;

  InsufficientStockException({
    required this.message,
    required this.requested,
    required this.available,
  });

  @override
  String toString() => message;
}
