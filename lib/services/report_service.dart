import 'package:prostock/models/customer.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/stock_movement.dart';

class ReportService {
  // Sales calculations
  double calculateTotalSales(List<Sale> sales) {
    return sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double calculateTodaySales(List<Sale> sales) {
    final today = DateTime.now();
    return sales
        .where(
          (sale) =>
              sale.createdAt.day == today.day &&
              sale.createdAt.month == today.month &&
              sale.createdAt.year == today.year,
        )
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  // Customer calculations
  int calculateTotalCustomers(List<Customer> customers) {
    return customers.length;
  }

  int calculateCustomersWithBalance(List<Customer> customers) {
    return customers.where((c) => c.balance > 0).length;
  }

  double calculateTotalBalance(List<Customer> customers) {
    return customers.fold(0.0, (sum, c) => sum + c.balance);
  }

  // Financial calculations - CORRECTED VERSIONS

  /// Calculate total revenue from sales
  double calculateTotalRevenue(List<Sale> sales) {
    return calculateTotalSales(sales);
  }

  /// Calculate Cost of Goods Sold (COGS) based on actual items sold
  /// This should use the cost price of products, not selling price
  double calculateTotalCost(List<SaleItem> saleItems, List<Product> products) {
    final productMap = {for (var p in products) p.id: p};
    return saleItems.fold(0.0, (sum, item) {
      final product = productMap[item.productId];
      if (product != null) {
        // Using product.cost (wholesale/purchase price) not product.price (selling price)
        return sum + (item.quantity * product.cost);
      }
      return sum;
    });
  }

  /// Calculate total losses (damaged goods, expired items, etc.)
  double calculateTotalLoss(List<Loss> losses) {
    return losses.fold(0.0, (sum, loss) => sum + loss.totalCost);
  }

  /// Calculate Gross Profit
  /// Formula: Revenue - COGS - Losses
  double calculateGrossProfit(
    double totalRevenue,
    double totalCost,
    double totalLoss,
  ) {
    return totalRevenue - totalCost - totalLoss;
  }

  /// Calculate Net Profit (if you want to include operating expenses)
  /// Formula: Gross Profit - Operating Expenses
  double calculateNetProfit(double grossProfit, double operatingExpenses) {
    return grossProfit - operatingExpenses;
  }

  /// Calculate Gross Profit Margin
  /// Formula: (Gross Profit / Revenue) × 100
  double calculateProfitMargin(double grossProfit, double totalRevenue) {
    if (totalRevenue == 0) {
      return 0.0;
    }
    return (grossProfit / totalRevenue) * 100;
  }

  /// Calculate Return on Investment (ROI)
  /// Formula: (Net Profit / Total Investment) × 100
  /// Using COGS as investment proxy since we don't have initial investment data
  double calculateRoi(double grossProfit, double totalCost) {
    if (totalCost == 0) {
      return 0.0;
    }
    return (grossProfit / totalCost) * 100;
  }

  /// Alternative ROI calculation using markup percentage
  /// Formula: ((Selling Price - Cost Price) / Cost Price) × 100
  double calculateMarkupPercentage(double totalRevenue, double totalCost) {
    if (totalCost == 0) {
      return 0.0;
    }
    return ((totalRevenue - totalCost) / totalCost) * 100;
  }

  /// Calculate inventory turnover ratio
  /// Formula: COGS / Average Inventory Value
  double calculateInventoryTurnover(
    double totalCost,
    double averageInventoryValue,
  ) {
    if (averageInventoryValue == 0) {
      return 0.0;
    }
    return totalCost / averageInventoryValue;
  }

  /// Calculate days in inventory
  /// Formula: 365 / Inventory Turnover
  double calculateDaysInInventory(double inventoryTurnover) {
    if (inventoryTurnover == 0) {
      return 0.0;
    }
    return 365 / inventoryTurnover;
  }

  // Inventory calculations
  int calculateTotalProducts(List<Product> products) {
    return products.length;
  }

  int calculateLowStockCount(List<Product> products) {
    return products.where((p) => p.stock <= p.minStock).length;
  }

  /// Calculate total inventory value using cost price (recommended for financial reporting)
  /// This represents your actual investment/capital tied up in inventory
  double calculateTotalInventoryValue(List<Product> products) {
    return products.fold(
      0.0,
      (sum, product) => sum + (product.cost * product.stock),
    );
  }

  double calculateBeginningInventoryValue(
    List<Product> currentProducts,
    List<StockMovement> movements,
  ) {
    final movementQuantities = <String, int>{};

    for (final movement in movements) {
      movementQuantities.update(
        movement.productId,
        (value) => value + movement.quantity,
        ifAbsent: () => movement.quantity,
      );
    }

    double beginningValue = 0.0;
    for (final product in currentProducts) {
      final quantityMoved = movementQuantities[product.id] ?? 0;
      final beginningStock = product.stock - quantityMoved;
      beginningValue += beginningStock * product.cost;
    }

    return beginningValue > 0 ? beginningValue : 0.0;
  }

  /// Calculate total inventory value using selling price (for retail/market value)
  /// This represents potential revenue if all inventory is sold at current prices
  double calculateTotalInventoryRetailValue(List<Product> products) {
    return products.fold(
      0.0,
      (sum, product) => sum + (product.price * product.stock),
    );
  }

  /// Calculate potential profit from current inventory
  /// This shows how much profit you could make if all current stock is sold
  double calculatePotentialInventoryProfit(List<Product> products) {
    return products.fold(
      0.0,
      (sum, product) => sum + ((product.price - product.cost) * product.stock),
    );
  }

  /// Get top selling products by quantity sold
  List<Product> getTopSellingProducts(
    List<SaleItem> saleItems,
    List<Product> products,
  ) {
    final productSaleCount = <String, int>{};
    for (final item in saleItems) {
      productSaleCount.update(
        item.productId,
        (value) => value + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    final sortedProductIds = productSaleCount.keys.toList(growable: false)
      ..sort((a, b) => productSaleCount[b]!.compareTo(productSaleCount[a]!));

    final productMap = {for (var p in products) p.id: p};
    final topProducts = sortedProductIds
        .map((id) => productMap[id])
        .where((p) => p != null)
        .cast<Product>()
        .take(10) // Limit to top 10
        .toList();

    return topProducts;
  }

  /// Get top selling products by revenue generated
  List<MapEntry<Product, double>> getTopSellingProductsByRevenue(
    List<SaleItem> saleItems,
    List<Product> products,
  ) {
    final productRevenue = <String, double>{};
    final productMap = {for (var p in products) p.id: p};

    for (final item in saleItems) {
      final product = productMap[item.productId];
      if (product != null) {
        final revenue =
            item.quantity *
            item.unitPrice; // Use item.price (actual selling price)
        productRevenue.update(
          item.productId,
          (value) => value + revenue,
          ifAbsent: () => revenue,
        );
      }
    }

    final sortedEntries = productRevenue.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .where((entry) => productMap[entry.key] != null) // Check before mapping
        .map((entry) => MapEntry(productMap[entry.key]!, entry.value))
        .take(10)
        .toList();
  }

  /// Calculate loss breakdown by reason
  Map<String, double> getLossBreakdown(List<Loss> losses) {
    final breakdown = <String, double>{};
    for (final loss in losses) {
      breakdown.update(
        loss.reason,
        (value) => value + loss.totalCost,
        ifAbsent: () => loss.totalCost,
      );
    }
    return breakdown;
  }

  /// Calculate average order value
  double calculateAverageOrderValue(List<Sale> sales) {
    if (sales.isEmpty) return 0.0;
    final totalRevenue = calculateTotalRevenue(sales);
    return totalRevenue / sales.length;
  }

  /// Calculate conversion rate (if you have visitor/inquiry data)
  double calculateConversionRate(int totalSales, int totalInquiries) {
    if (totalInquiries == 0) return 0.0;
    return (totalSales / totalInquiries) * 100;
  }

  /// Calculate customer lifetime value (simplified version)
  double calculateCustomerLifetimeValue(
    double averageOrderValue,
    double purchaseFrequency,
    double customerLifespanYears,
  ) {
    return averageOrderValue * purchaseFrequency * customerLifespanYears;
  }
}
