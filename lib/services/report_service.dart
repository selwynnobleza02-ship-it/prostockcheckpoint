import 'package:prostock/models/customer.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale.dart';

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

  double calculateTotalCost(List<Product> products) {
    return products.fold(
      0.0,
      (sum, product) => sum + (product.cost * product.stock),
    );
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
}
