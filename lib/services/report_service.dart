import 'package:prostock/models/customer.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';

class ReportService {
  // Sales calculations
  double calculateTotalSales(List<Sale> sales) {
    return sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double calculateTodaySales(List<Sale> sales) {
    final today = DateTime.now();
    return sales
        .where((sale) =>
            sale.createdAt.day == today.day &&
            sale.createdAt.month == today.month &&
            sale.createdAt.year == today.year)
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

  // Financial calculations
  double calculateTotalRevenue(List<Sale> sales) {
    return calculateTotalSales(sales);
  }

  double calculateTotalCost(List<SaleItem> saleItems, List<Product> products) {
    final productMap = {for (var p in products) p.id: p};
    return saleItems.fold(0.0, (sum, item) {
      final product = productMap[item.productId];
      if (product != null) {
        return sum + (item.quantity * product.cost);
      }
      return sum;
    });
  }

  double calculateTotalLoss(List<Loss> losses) {
    return losses.fold(
      0.0,
      (sum, loss) => sum + loss.totalCost,
    );
  }

  double calculateGrossProfit(double totalRevenue, double totalCost, double totalLoss) {
    return totalRevenue - totalCost - totalLoss;
  }

  double calculateProfitMargin(double grossProfit, double totalRevenue) {
    if (totalRevenue == 0) {
      return 0.0;
    }
    return (grossProfit / totalRevenue) * 100;
  }

  double calculateRoi(double grossProfit, double totalCost) {
    if (totalCost == 0) {
      return 0.0;
    }
    return (grossProfit / totalCost) * 100;
  }

  // Inventory calculations
  int calculateTotalProducts(List<Product> products) {
    return products.length;
  }

  int calculateLowStockCount(List<Product> products) {
    return products.where((p) => p.stock <= p.minStock).length;
  }

  double calculateTotalInventoryValue(List<Product> products) {
    return products.fold(
      0.0,
      (sum, product) => sum + (product.price * product.stock),
    );
  }

  List<Product> getTopSellingProducts(
    List<SaleItem> saleItems,
    List<Product> products,
  ) {
    final productSaleCount = <String, int>{};
    for (final item in saleItems) {
      productSaleCount.update(item.productId, (value) => value + item.quantity,
          ifAbsent: () => item.quantity);
    }

    final sortedProductIds = productSaleCount.keys.toList(
      growable: false,
    )..sort((a, b) => productSaleCount[b]!.compareTo(productSaleCount[a]!));

    final productMap = {for (var p in products) p.id: p};
    final topProducts = sortedProductIds
        .map((id) => productMap[id])
        .where((p) => p != null)
        .cast<Product>()
        .toList();

    return topProducts;
  }

  Map<String, double> getLossBreakdown(List<Loss> losses) {
    final breakdown = <String, double>{};
    for (final loss in losses) {
      breakdown.update(loss.reason, (value) => value + loss.totalCost,
          ifAbsent: () => loss.totalCost);
    }
    return breakdown;
  }
}
