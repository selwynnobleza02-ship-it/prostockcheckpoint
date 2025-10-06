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

  /// Get historical costs for multiple sale items
  Future<Map<String, double>> getHistoricalCostsForSaleItems(
    List<SaleItem> saleItems,
    DateTime saleDate,
  ) async {
    final Map<String, double> costs = {};

    for (final item in saleItems) {
      costs[item.id] = await getHistoricalCostForSaleItem(item, saleDate);
    }

    return costs;
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
