import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/providers/connectivity_provider.dart';
import 'package:provider/provider.dart';
import 'package:prostock/main.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/models/product.dart';

void main() {
  group('Integration Tests', () {
    testWidgets('Complete login to dashboard flow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const RetailCreditApp());

      // Wait for splash screen
      await tester.pump(Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Should navigate to login screen
      expect(find.text('Sign in to continue'), findsOneWidget);

      // Enter credentials
      await tester.enterText(find.byType(TextFormField).first, 'admin');
      await tester.enterText(find.byType(TextFormField).last, 'admin123');

      // Tap sign in
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should navigate to dashboard based on role
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('Complete POS sale workflow', (WidgetTester tester) async {
      // Set up authenticated state
      final authProvider = AuthProvider();
      await authProvider.login('admin', 'admin123');

      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );
      final salesProvider = SalesProvider(inventoryProvider: inventoryProvider);

      // Add test product to inventory
      final testProduct = Product(
        id: '1',
        name: 'Test Product',
        barcode: '1234567890',

        cost: 5.0,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      inventoryProvider.products.add(testProduct);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider.value(value: salesProvider),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => CreditProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // Simulate POS interface
                  ElevatedButton(
                    onPressed: () {
                      salesProvider.addItemToCurrentSale(testProduct, 2);
                    },
                    child: Text('Add Item'),
                  ),
                  Text('Total: ${salesProvider.formattedCurrentSaleTotal}'),
                  ElevatedButton(
                    onPressed: () async {
                      await salesProvider.completeSale(paymentMethod: 'Cash');
                    },
                    child: Text('Complete Sale'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Add item to cart
      await tester.tap(find.text('Add Item'));
      await tester.pump();

      // Verify item added
      expect(find.textContaining('₱20.00'), findsOneWidget);

      // Complete sale
      await tester.tap(find.text('Complete Sale'));
      await tester.pumpAndSettle();

      // Verify sale completed
      expect(salesProvider.currentSaleItems.length, equals(0));
      expect(inventoryProvider.products[0].stock, equals(98));
    });

    testWidgets('Barcode scanning to product addition flow', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider(); // New AuthProvider for this test
      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: inventoryProvider),
            ChangeNotifierProvider(
              create: (_) =>
                  SalesProvider(inventoryProvider: inventoryProvider),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Simulate barcode scan result
                      final newProduct = Product(
                        name: 'Scanned Product',
                        barcode: '9876543210',

                        cost: 15.0,
                        stock: 50,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      await inventoryProvider.addProduct(newProduct);
                    },
                    child: Text('Simulate Barcode Scan'),
                  ),
                  Text('Products: ${inventoryProvider.products.length}'),
                ],
              ),
            ),
          ),
        ),
      );

      // Simulate barcode scan
      await tester.tap(find.text('Simulate Barcode Scan'));
      await tester.pumpAndSettle();

      // Verify product added
      expect(inventoryProvider.products.length, equals(1));
      expect(inventoryProvider.products[0].name, equals('Scanned Product'));
    });

    testWidgets('Customer credit management flow', (WidgetTester tester) async {
      final customerProvider = CustomerProvider();
      final creditProvider = CreditProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: customerProvider),
            ChangeNotifierProvider.value(value: creditProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Add test customer
                      final customer = Customer(
                        id: '1',
                        name: 'Test Customer',
                        creditLimit: 1000.0,
                        currentBalance: 0.0,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      await customerProvider.addCustomer(customer);
                    },
                    child: Text('Add Customer'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Record credit sale
                      await creditProvider.recordCreditSale(
                        '1',
                        100.0,
                        description: 'Test sale',
                      );
                    },
                    child: Text('Record Credit Sale'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Record payment
                      await creditProvider.recordPayment(
                        '1',
                        50.0,
                        description: 'Cash payment',
                      );
                    },
                    child: Text('Record Payment'),
                  ),
                  Text('Customers: ${customerProvider.customers.length}'),
                ],
              ),
            ),
          ),
        ),
      );

      // Add customer
      await tester.tap(find.text('Add Customer'));
      await tester.pumpAndSettle();
      expect(customerProvider.customers.length, equals(1));

      // Record credit sale
      await tester.tap(find.text('Record Credit Sale'));
      await tester.pumpAndSettle();
      expect(customerProvider.customers[0].currentBalance, equals(100.0));

      // Record payment
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();
      expect(customerProvider.customers[0].currentBalance, equals(50.0));
    });

    testWidgets('Error handling in providers', (WidgetTester tester) async {
      final authProvider = AuthProvider(); // New AuthProvider for this test
      final inventoryProvider = InventoryProvider(
        authProvider as ConnectivityProvider,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider.value(value: inventoryProvider)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Try to reduce stock from non-existent product
                      await inventoryProvider.reduceStock('non-existent', 10);
                    },
                    child: Text('Test Error'),
                  ),
                  if (inventoryProvider.error != null)
                    Text('Error: ${inventoryProvider.error}'),
                ],
              ),
            ),
          ),
        ),
      );

      // Trigger error
      await tester.tap(find.text('Test Error'));
      await tester.pumpAndSettle();

      // Verify error handling
      expect(find.textContaining('Error:'), findsOneWidget);
      expect(inventoryProvider.error, isNotNull);
    });
  });
}
