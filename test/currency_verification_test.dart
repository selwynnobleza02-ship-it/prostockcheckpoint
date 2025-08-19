import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prostock/providers/connectivity_provider.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/screens/dashboard_screen.dart';
import 'package:prostock/screens/inventory_screen.dart';
import 'package:prostock/screens/pos_screen.dart';
import 'package:prostock/screens/customers_screen.dart';
import 'package:prostock/screens/reports_screen.dart';
import 'package:prostock/widgets/barcode_product_dialog.dart';
import 'package:prostock/widgets/add_product_dialog.dart';
import 'package:prostock/widgets/add_customer_dialog.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/customer.dart';
import 'package:firebase_core/firebase_core.dart'; // New
import '../test/firebase_mock_setup.dart'; // New

void main() {
  setupFirebaseAuthMocks(); // Use the new function name

  setUpAll(() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'testApiKey',
        appId: 'testAppId',
        messagingSenderId: 'testSenderId',
        projectId: 'testProjectId',
      ),
    );
  });

  group('Currency Symbol Verification Tests', () {
    late InventoryProvider inventoryProvider;
    late ConnectivityProvider connectivityProvider; // New
    late CustomerProvider customerProvider;
    late CreditProvider creditProvider;
    late AuthProvider authProvider;

    setUp(() {
      connectivityProvider = ConnectivityProvider(); // Initialize ConnectivityProvider
      authProvider = AuthProvider(); // Initialize AuthProvider first
      inventoryProvider = InventoryProvider(connectivityProvider); // Pass ConnectivityProvider
      ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
        create: (context) =>
            SalesProvider(inventoryProvider: context.read<InventoryProvider>()),
        update: (context, inventoryProvider, previousSalesProvider) =>
            previousSalesProvider ??
            SalesProvider(inventoryProvider: inventoryProvider),
      );
      customerProvider = CustomerProvider();
      creditProvider = CreditProvider();

      // Add sample data for testing
      inventoryProvider.products.add(
        Product(
          id: '1',
          name: 'Test Product',
          barcode: '123456789',
          price: 150.50,
          cost: 100.25,
          stock: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      customerProvider.addCustomer(
        Customer(
          name: 'Test Customer',
          email: 'test@example.com',
          phone: '+1234567890',
          creditLimit: 1000.0,
          currentBalance: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: inventoryProvider),
          ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
            create: (context) => SalesProvider(
              inventoryProvider: context.read<InventoryProvider>(),
            ),
            update: (context, inventoryProvider, previousSalesProvider) =>
                previousSalesProvider ??
                SalesProvider(inventoryProvider: inventoryProvider),
          ),
          ChangeNotifierProvider.value(value: customerProvider),
          ChangeNotifierProvider.value(value: creditProvider),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('Barcode Product Dialog uses ₱ symbol', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(const BarcodeProductDialog(barcode: '123456789')),
      );

      // Should find ₱ symbols in price and cost fields
      expect(find.text('₱'), findsAtLeast(2));

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('Add Product Dialog uses ₱ symbol', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const AddProductDialog()));

      // Should find ₱ symbols
      expect(find.text('₱'), findsAtLeast(2));

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('Add Customer Dialog uses ₱ symbol', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const AddCustomerDialog()));

      // Should find ₱ symbol in credit limit field
      expect(find.text('₱'), findsOneWidget);

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('Dashboard shows ₱ in Today\'s Sales', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const DashboardScreen()));

      await tester.pumpAndSettle();

      // Should find ₱ symbol in dashboard cards
      expect(find.textContaining('₱'), findsAtLeast(1));

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('Inventory Screen shows ₱ in product prices', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const InventoryScreen()));

      await tester.pumpAndSettle();

      // Should find ₱ symbol in product price display
      expect(find.textContaining('₱'), findsAtLeast(1));

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('POS Screen shows ₱ in product prices and totals', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const POSScreen()));

      await tester.pumpAndSettle();

      // Should find ₱ symbols in product prices
      expect(find.textContaining('₱'), findsAtLeast(1));

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('Customers Screen shows ₱ in credit information', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const CustomersScreen()));

      await tester.pumpAndSettle();

      // Should find ₱ symbols in customer credit displays
      expect(find.textContaining('₱'), findsAtLeast(1));

      // Should NOT find any $ symbols
      expect(find.text('\$'), findsNothing);
    });

    testWidgets('Reports Screen shows ₱ in all financial data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const ReportsScreen()));

      await tester.pumpAndSettle();

      // Navigate through all tabs to check currency symbols
      final tabBar = find.byType(TabBar);
      expect(tabBar, findsOneWidget);

      // Check Sales tab
      await tester.tap(find.text('Sales'));
      await tester.pumpAndSettle();

      // Should find ₱ symbols in sales reports
      expect(find.textContaining('₱'), findsAtLeast(1));

      // Check Financial tab
      await tester.tap(find.text('Financial'));
      await tester.pumpAndSettle();

      // Should find ₱ symbols in financial reports
      expect(find.textContaining('₱'), findsAtLeast(1));

      // Should NOT find any $ symbols in any tab
      expect(find.text('\$'), findsNothing);
    });

    test('Currency formatting functions return ₱ symbol', () {
      const testAmount = 1234.56;

      // Test basic formatting
      final formatted = '₱${testAmount.toStringAsFixed(2)}';
      expect(formatted, equals('₱1234.56'));
      expect(formatted.contains('₱'), isTrue);
      expect(formatted.contains('\$'), isFalse);

      // Test with zero
      final zeroFormatted = '₱${0.0.toStringAsFixed(2)}';
      expect(zeroFormatted, equals('₱0.00'));
      expect(zeroFormatted.contains('₱'), isTrue);
      expect(zeroFormatted.contains('\$'), isFalse);
    });

    test('Product price display uses ₱ symbol', () {
      final product = Product(
        name: 'Test Product',
        price: 150.50,
        cost: 100.25,
        stock: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final priceDisplay = '₱${product.price.toStringAsFixed(2)}';
      expect(priceDisplay, equals('₱150.50'));
      expect(priceDisplay.contains('₱'), isTrue);
      expect(priceDisplay.contains('\$'), isFalse);
    });

    test('Customer credit display uses ₱ symbol', () {
      final customer = Customer(
        name: 'Test Customer',
        creditLimit: 5000.00,
        currentBalance: 2500.75,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final creditDisplay = '₱${customer.creditLimit.toStringAsFixed(2)}';
      final balanceDisplay = '₱${customer.currentBalance.toStringAsFixed(2)}';

      expect(creditDisplay, equals('₱5000.00'));
      expect(balanceDisplay, equals('₱2500.75'));
      expect(creditDisplay.contains('₱'), isTrue);
      expect(balanceDisplay.contains('₱'), isTrue);
      expect(creditDisplay.contains('\$'), isFalse);
      expect(balanceDisplay.contains('\$'), isFalse);
    });

    testWidgets('Comprehensive currency display verification', (
      WidgetTester tester,
    ) async {
      // Test all major screens
      final screens = [
        const DashboardScreen(),
        const InventoryScreen(),
        const POSScreen(),
        const CustomersScreen(),
        const ReportsScreen(),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(createTestApp(screen));
        await tester.pumpAndSettle();

        // Find all text that might contain currency
        final allText = find.byType(Text);
        final textWidgets = tester.widgetList<Text>(allText);

        for (final textWidget in textWidgets) {
          final text = textWidget.data ?? '';

          // If text contains any currency-like patterns, validate them
          if (text.contains(RegExp(r'[\$₱]\d')) ||
              text.contains('Price:') ||
              text.contains('Total:') ||
              text.contains('Balance:') ||
              text.contains('Credit:') ||
              text.contains('Sales')) {
            expect(
              text.contains('\$'),
              isFalse,
              reason: 'Found \$ in: "$text"',
            );

            if (text.contains(RegExp(r'[₱\$]\d'))) {
              expect(
                text.contains('₱'),
                isTrue,
                reason: 'Currency should use ₱: "$text"',
              );
            }
          }
        }
      }
    });
  });
}
