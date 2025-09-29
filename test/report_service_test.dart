import 'package:flutter_test/flutter_test.dart';
import 'package:prostock/models/loss.dart';
import 'package:prostock/models/loss_reason.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/sale.dart';
import 'package:prostock/models/sale_item.dart';
import 'package:prostock/services/report_service.dart';

void main() {
  group('ReportService', () {
    final reportService = ReportService();

    test('calculateTotalSales returns correct total', () {
      final sales = <Sale>[
        Sale(
          id: '1',
          totalAmount: 100,
          createdAt: DateTime.now(),
          userId: 'user1',
          paymentMethod: 'cash',
          status: 'completed',
        ),
        Sale(
          id: '2',
          totalAmount: 150,
          createdAt: DateTime.now(),
          userId: 'user1',
          paymentMethod: 'cash',
          status: 'completed',
        ),
      ];
      expect(reportService.calculateTotalSales(sales), 250);
    });

    test('calculateTotalRevenue returns correct total', () {
      final sales = <Sale>[
        Sale(
          id: '1',
          totalAmount: 100,
          createdAt: DateTime.now(),
          userId: 'user1',
          paymentMethod: 'cash',
          status: 'completed',
        ),
        Sale(
          id: '2',
          totalAmount: 150,
          createdAt: DateTime.now(),
          userId: 'user1',
          paymentMethod: 'cash',
          status: 'completed',
        ),
      ];
      expect(reportService.calculateTotalRevenue(sales), 250);
    });

    test('calculateTotalCost returns correct total', () {
      final products = <Product>[
        Product(
          id: 'p1',
          name: 'Product 1',
          cost: 10,
          stock: 100,
          minStock: 10,
          category: 'Category A',
          barcode: '12345678',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'p2',
          name: 'Product 2',
          cost: 20,
          stock: 50,
          minStock: 5,
          category: 'Category B',
          barcode: '87654321',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final saleItems = [
        SaleItem(
          id: 'si1',
          saleId: 's1',
          productId: 'p1',
          quantity: 2,
          unitPrice: 20,
          totalPrice: 40,
        ),
        SaleItem(
          id: 'si2',
          saleId: 's1',
          productId: 'p2',
          quantity: 3,
          unitPrice: 30,
          totalPrice: 90,
        ),
      ];
      expect(reportService.calculateTotalCost(saleItems, products), 80);
    });

    test('calculateTotalLoss returns correct total', () {
      final losses = [
        Loss(
          id: 'l1',
          productId: 'p1',
          quantity: 1,
          reason: LossReason.damaged,
          timestamp: DateTime.now(),
          totalCost: 10,
        ),
        Loss(
          id: 'l2',
          productId: 'p2',
          quantity: 2,
          reason: LossReason.expired,
          timestamp: DateTime.now(),
          totalCost: 40,
        ),
      ];
      expect(reportService.calculateTotalLoss(losses), 50);
    });

    test('calculateGrossProfit returns correct total', () {
      expect(reportService.calculateGrossProfit(250, 80, 50), 120);
    });
  });
}
