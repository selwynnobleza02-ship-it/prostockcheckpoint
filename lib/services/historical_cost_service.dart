import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/cost_history.dart';
import 'package:prostock/services/cost_history_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/models/product.dart';

class HistoricalCostService {
  final CostHistoryService _costHistoryService;
  final LocalDatabaseService _localDatabaseService;

  HistoricalCostService(this._costHistoryService, this._localDatabaseService);

  /// Get historical cost for a sale item at the time of sale
  Future<double> getHistoricalCostForSaleItem(
    SaleItem saleItem,
    DateTime saleDate,
  ) async {
    try {
      // First try to get cost from cost history at the time of sale
      final costAtTime = await _costHistoryService.getCostAtTime(
        saleItem.productId,
        saleDate,
      );

      if (costAtTime != null) {
        return costAtTime;
      }

      // Fallback to current product cost if no historical data
      final products = await _localDatabaseService.getAllProducts();
      final product = products.firstWhere(
        (p) => p.id == saleItem.productId,
        orElse: () => Product(
          id: saleItem.productId,
          name: 'Unknown Product',
          cost: 0.0,
          stock: 0,
          minStock: 0,
          category: 'Unknown',
          version: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return product.cost;
    } catch (e) {
      // Fallback to current product cost on error
      final products = await _localDatabaseService.getAllProducts();
      final product = products.firstWhere(
        (p) => p.id == saleItem.productId,
        orElse: () => Product(
          id: saleItem.productId,
          name: 'Unknown Product',
          cost: 0.0,
          stock: 0,
          minStock: 0,
          category: 'Unknown',
          version: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return product.cost;
    }
  }

  /// Get historical costs for multiple sale items (BATCH OPTIMIZED)
  /// Returns a Map of saleItemId -> historical cost
  Future<Map<String, double>> getHistoricalCostsForSaleItems(
    List<SaleItem> saleItems,
    DateTime saleDate,
  ) async {
    try {
      if (saleItems.isEmpty) return {};

      // Get unique product IDs
      final productIds = saleItems
          .map((item) => item.productId)
          .toSet()
          .toList();

      // Fetch historical costs for all products in batches
      final productCosts = await _costHistoryService.getBatchCostsAtTime(
        productIds,
        saleDate,
      );

      // Get current products as fallback
      final products = await _localDatabaseService.getAllProducts();
      final productById = {for (final p in products) p.id: p};

      // Map sale items to their costs
      final Map<String, double> costs = {};
      for (final item in saleItems) {
        // Try historical cost first
        double cost = productCosts[item.productId] ?? 0.0;

        // Fallback to current product cost if no historical data
        if (cost == 0.0) {
          final product = productById[item.productId];
          cost = product?.cost ?? 0.0;
        }

        costs[item.id] = cost;
      }

      return costs;
    } catch (e) {
      // Fallback to current product costs on error
      final products = await _localDatabaseService.getAllProducts();
      final productById = {for (final p in products) p.id: p};

      final Map<String, double> costs = {};
      for (final item in saleItems) {
        final product = productById[item.productId];
        costs[item.id] = product?.cost ?? 0.0;
      }

      return costs;
    }
  }

  /// Get cost history for a product within a date range
  Future<List<CostHistory>> getCostHistoryForProduct(
    String productId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _costHistoryService.getCostHistoryByDateRange(
      startDate,
      endDate,
      productId: productId,
    );
  }

  /// Get all cost history for multiple products
  Future<List<CostHistory>> getCostHistoryForProducts(
    List<String> productIds,
  ) async {
    return await _costHistoryService.getCostHistoryByProducts(productIds);
  }
}
