import 'package:flutter_test/flutter_test.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/providers/connectivity_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/models/product.dart';

void main() {
  group('Performance Tests', () {
    test('InventoryProvider handles large product lists efficiently', () async {
      final authProvider = AuthProvider(); // New AuthProvider for this test
      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );
      final stopwatch = Stopwatch()..start();

      // Generate large number of products
      final products = List.generate(
        1000,
        (index) => Product(
          id: index.toString(),
          name: 'Product $index',

          cost: 5.0 + index,
          stock: 100 + index,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Add products to provider
      inventoryProvider.products.addAll(products);

      // Test search performance
      final searchResults = inventoryProvider.products
          .where((p) => p.name.contains('Product 5'))
          .toList();

      stopwatch.stop();

      // Verify performance (should complete in reasonable time)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(searchResults.length, greaterThan(0));
      expect(inventoryProvider.products.length, equals(1000));
    });

    test('SalesProvider handles multiple sale items efficiently', () async {
      final authProvider = AuthProvider(); // New AuthProvider for this test
      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );
      final salesProvider = SalesProvider(inventoryProvider: inventoryProvider);
      final stopwatch = Stopwatch()..start();

      // Add multiple products to inventory
      final products = List.generate(
        100,
        (index) => Product(
          id: index.toString(),
          name: 'Product $index',

          cost: 5.0,
          stock: 1000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      inventoryProvider.products.addAll(products);

      // Add many items to current sale
      for (int i = 0; i < 50; i++) {
        salesProvider.addItemToCurrentSale(products[i], 2);
      }

      stopwatch.stop();

      // Verify performance and correctness
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(salesProvider.currentSaleItems.length, equals(50));
      expect(
        salesProvider.currentSaleTotal,
        equals(1000.0),
      ); // 50 items * 2 qty * 10.0 price
    });

    test('Cache performance in providers', () async {
      final authProvider = AuthProvider(); // New AuthProvider for this test
      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );
      final stopwatch = Stopwatch();

      // First load (should be slower - cache miss)
      stopwatch.start();
      await inventoryProvider.loadProducts();
      stopwatch.stop();
      final firstLoadTime = stopwatch.elapsedMilliseconds;

      stopwatch.reset();

      // Second load (should be faster - cache hit)
      stopwatch.start();
      await inventoryProvider.loadProducts();
      stopwatch.stop();
      final secondLoadTime = stopwatch.elapsedMilliseconds;

      // Cache should improve performance
      expect(secondLoadTime, lessThanOrEqualTo(firstLoadTime));
    });

    test('Memory usage with large datasets', () {
      final authProvider = AuthProvider(); // New AuthProvider for this test
      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );

      // Add large dataset
      final products = List.generate(
        5000,
        (index) => Product(
          id: index.toString(),
          name: 'Product $index',

          cost: 5.0,
          stock: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      inventoryProvider.products.addAll(products);

      // Test memory efficiency operations
      final lowStockProducts = inventoryProvider.lowStockProducts;
      final criticalStockProducts = inventoryProvider.criticalStockProducts;

      // Verify operations complete without memory issues
      expect(inventoryProvider.products.length, equals(5000));
      expect(lowStockProducts, isA<List<Product>>());
      expect(criticalStockProducts, isA<List<Product>>());
    });
  });
}
