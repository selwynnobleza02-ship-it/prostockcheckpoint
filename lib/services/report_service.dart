import 'package:prostock/models/customer.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/models/stock_movement.dart';
import 'package:prostock/models/tax_rule.dart';
import 'package:prostock/services/tax_service.dart';
import 'package:prostock/services/tax_rules_service.dart';

class ReportService {
  // Sales calculations
  // Treat only cash-like sales as sales (exclude credit checkouts and payment entries)
  double calculateTotalSales(List<Sale> sales) {
    return sales
        .where((s) => _isCashLikeSale(s.paymentMethod))
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double calculateTodaySales(List<Sale> sales) {
    final today = DateTime.now();
    return sales
        .where((s) => _isCashLikeSale(s.paymentMethod))
        .where(
          (sale) =>
              sale.createdAt.day == today.day &&
              sale.createdAt.month == today.month &&
              sale.createdAt.year == today.year,
        )
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  double calculateTotalCreditReceived(List<Sale> sales) {
    return sales
        .where((sale) {
          final method = sale.paymentMethod.toLowerCase();
          return method == 'credit payment' ||
              method == 'credit_payment' ||
              method == 'debt payment' ||
              method == 'debt_payment';
        })
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  // New: Calculate total credit payments from credit transactions (preferred source)
  double calculateTotalCreditPayments(List<CreditTransaction> transactions) {
    return transactions
        .where((t) => t.type.toLowerCase() == 'payment')
        .fold(0.0, (sum, t) => sum + t.amount);
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

  /// Calculate total revenue: cash-like sales + credit payments
  double calculateTotalRevenue(List<Sale> sales) {
    final cashLike = sales
        .where((s) => _isCashLikeSale(s.paymentMethod))
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    final creditPayments = calculateTotalCreditReceived(sales);
    return cashLike + creditPayments;
  }

  /// Calculate Cost of Goods Sold (COGS) based on actual items sold
  /// This uses the unitCost captured at the time of sale for exact COGS
  /// Falls back to current product cost if unitCost is missing (for old sales)
  double calculateTotalCost(List<SaleItem> saleItems, List<Product> products) {
    // Create product lookup map for fallback
    final productMap = {for (var p in products) p.id: p};

    return saleItems.fold(0.0, (sum, item) {
      // Use unitCost from sale item (captured at time of sale)
      if (item.unitCost > 0) {
        return sum + (item.quantity * item.unitCost);
      }

      // FALLBACK: For old sales without unitCost, use current product cost
      // This happens with pre-FIFO sales data
      final product = productMap[item.productId];
      if (product != null) {
        return sum + (item.quantity * product.cost);
      }

      // If product not found, skip this item
      return sum;
    });
  }

  // Calculate COGS for credit purchases from transaction items (uses unitCost from items)
  // Falls back to current product cost if unitCost is missing (for old credit sales)
  double calculateTotalCostFromCreditTransactions(
    List<CreditTransaction> transactions,
    List<Product> products,
  ) {
    // Create product lookup map for fallback
    final productMap = {for (var p in products) p.id: p};

    double total = 0.0;
    for (final tx in transactions.where(
      (t) => t.type.toLowerCase() == 'purchase',
    )) {
      for (final item in tx.items) {
        // Use unitCost from credit sale item (captured at time of sale)
        if (item.unitCost > 0) {
          total += item.unitCost * item.quantity;
        } else {
          // FALLBACK: For old credit sales without unitCost, use current product cost
          final product = productMap[item.productId];
          if (product != null) {
            total += product.cost * item.quantity;
          }
        }
      }
    }
    return total;
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
  Future<double> calculateTotalInventoryRetailValue(
    List<Product> products,
  ) async {
    double total = 0.0;
    for (final product in products) {
      final price = await TaxService.calculateSellingPriceWithRule(
        product.cost,
        productId: product.id,
        categoryName: product.category,
      );
      total += price * product.stock;
    }
    return total;
  }

  /// Calculate potential profit from current inventory
  /// This shows how much profit you could make if all current stock is sold
  Future<double> calculatePotentialInventoryProfit(
    List<Product> products,
  ) async {
    double total = 0.0;
    for (final product in products) {
      final price = await TaxService.calculateSellingPriceWithRule(
        product.cost,
        productId: product.id,
        categoryName: product.category,
      );
      total += (price - product.cost) * product.stock;
    }
    return total;
  }

  /// Batch calculate selling prices for multiple products efficiently
  /// This reduces Firestore calls by fetching all rules once
  Future<Map<String, double>> calculateBatchSellingPrices(
    List<Product> products,
  ) async {
    final rules = await TaxRulesService.getAllRules(); // Single call
    final result = <String, double>{};

    for (final product in products) {
      if (product.id == null) continue;

      final rule = _findBestRuleSync(rules, product.id, product.category);
      final price = _calculatePriceWithRule(product.cost, rule);
      result[product.id!] = price;
    }
    return result;
  }

  /// Find the best matching rule synchronously from cached rules
  TaxRule? _findBestRuleSync(
    List<TaxRule> rules,
    String? productId,
    String? categoryName,
  ) {
    // Find product-specific rule first
    if (productId != null) {
      final productRule = rules.firstWhere(
        (rule) => rule.productId == productId,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (productRule.id.isNotEmpty) return productRule;
    }

    // Find category-specific rule
    if (categoryName != null) {
      final categoryRule = rules.firstWhere(
        (rule) => rule.categoryName == categoryName,
        orElse: () => TaxRule(
          id: '',
          tubo: 0.0,
          isInclusive: true,
          priority: -1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (categoryRule.id.isNotEmpty) return categoryRule;
    }

    // Return global rule
    return rules.firstWhere(
      (rule) => rule.isGlobal,
      orElse: () => TaxRule(
        id: '',
        tubo: 0.0,
        isInclusive: true,
        priority: -1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Calculate price with a specific rule
  double _calculatePriceWithRule(double cost, TaxRule? rule) {
    if (rule != null && rule.id.isNotEmpty) {
      // Use rule: always add-on-top
      final rawPrice = cost + rule.tubo;
      return rawPrice.round().toDouble();
    }
    // Fallback to global settings
    return TaxService.calculateSellingPriceSync(cost);
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
        loss.reason.name,
        (value) => value + loss.totalCost,
        ifAbsent: () => loss.totalCost,
      );
    }
    return breakdown;
  }

  /// Calculate average order value
  double calculateAverageOrderValue(List<Sale> sales) {
    if (sales.isEmpty) return 0.0;
    final filtered = sales.where((s) => _isCashLikeSale(s.paymentMethod));
    if (filtered.isEmpty) return 0.0;
    final totalSales = calculateTotalSales(filtered.toList());
    return totalSales / filtered.length;
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

  bool _isCashLikeSale(String method) {
    final m = method.toLowerCase();
    // Treat standard immediate methods as sales; exclude credit and any payment entries
    return m == 'cash' || m == 'card' || m == 'gcash' || m == 'paymaya';
  }
}
