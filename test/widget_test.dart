// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prostock/main.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/screens/login_screen.dart';
import 'package:prostock/screens/dashboard_screen.dart';
import 'package:prostock/widgets/dashboard_card.dart';
import 'package:prostock/widgets/barcode_scanner_widget.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/providers/connectivity_provider.dart'; // New
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

  group('Retail Credit App Tests', () {
    testWidgets('App starts with splash screen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const RetailCreditApp());

      // Verify that the splash screen is displayed
      expect(find.text('Retail Credit Manager'), findsOneWidget);
      expect(find.text('Managing your business made easy'), findsOneWidget);
      expect(find.byIcon(Icons.store), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Login screen displays correctly', (WidgetTester tester) async {
      // Create a test widget with providers
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(
              create: (_) => InventoryProvider(ConnectivityProvider()),
            ),
            ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
              create: (context) => SalesProvider(
                inventoryProvider: context.read<InventoryProvider>(),
              ),
              update: (context, inventoryProvider, previousSalesProvider) =>
                  previousSalesProvider ??
                  SalesProvider(inventoryProvider: inventoryProvider),
            ),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => CreditProvider()),
          ],
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      // Verify login screen elements
      expect(find.text('Retail Credit Manager'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Demo Credentials'), findsOneWidget);
    });

    testWidgets('Login form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(
              create: (_) => InventoryProvider(ConnectivityProvider()),
            ),
            ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
              create: (context) => SalesProvider(
                inventoryProvider: context.read<InventoryProvider>(),
              ),
              update: (context, inventoryProvider, previousSalesProvider) =>
                  previousSalesProvider ??
                  SalesProvider(inventoryProvider: inventoryProvider),
            ),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => CreditProvider()),
          ],
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      // Try to submit empty form
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Verify validation messages appear
      expect(find.text('Please enter your username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Dashboard cards display correctly with ₱ symbol', (
      WidgetTester tester,
    ) async {
      // Set up authenticated state
      final authProvider = AuthProvider();
      final loginResult = await authProvider.login('admin', 'admin123');

      // Verify login was successful before proceeding
      expect(
        loginResult,
        isTrue,
        reason: 'Login should succeed with valid credentials',
      );
      expect(
        authProvider.isAuthenticated,
        isTrue,
        reason: 'User should be authenticated',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(
              create: (_) => InventoryProvider(ConnectivityProvider()),
            ),
            ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
              create: (context) => SalesProvider(
                inventoryProvider: context.read<InventoryProvider>(),
              ),
              update: (context, inventoryProvider, previousSalesProvider) =>
                  previousSalesProvider ??
                  SalesProvider(inventoryProvider: inventoryProvider),
            ),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => CreditProvider()),
          ],
          child: MaterialApp(
            home: DashboardHome(
              onNavigateToTab: (int index) {
                // Mock navigation callback for testing
              },
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify dashboard elements
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Total Products'), findsOneWidget);
      expect(find.text('Low Stock Items'), findsOneWidget);
      expect(find.text('Today\'s Sales'), findsOneWidget);
      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('Sales Overview'), findsOneWidget);

      // Verify Philippine Peso symbol appears and dollar sign does not
      expect(find.textContaining('₱'), findsAtLeast(1));
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('Bottom navigation works', (WidgetTester tester) async {
      // Set up authenticated state
      final authProvider = AuthProvider();
      final loginResult = await authProvider.login('admin', 'admin123');
      expect(loginResult, isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider(
              create: (_) => InventoryProvider(ConnectivityProvider()),
            ),
            ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
              create: (context) => SalesProvider(
                inventoryProvider: context.read<InventoryProvider>(),
              ),
              update: (context, inventoryProvider, previousSalesProvider) =>
                  previousSalesProvider ??
                  SalesProvider(inventoryProvider: inventoryProvider),
            ),
            ChangeNotifierProvider(create: (_) => CustomerProvider()),
            ChangeNotifierProvider(create: (_) => CreditProvider()),
          ],
          child: MaterialApp(home: DashboardScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Test navigation to different tabs
      expect(find.text('Dashboard'), findsOneWidget);

      // Tap on Inventory tab
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Inventory'), findsOneWidget);

      // Tap on POS tab
      await tester.tap(find.text('POS'));
      await tester.pumpAndSettle();
      expect(find.text('Point of Sale'), findsOneWidget);
    });

    testWidgets('Barcode scanner displays correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => InventoryProvider(ConnectivityProvider()),
            ),
            ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
              create: (context) => SalesProvider(
                inventoryProvider: context.read<InventoryProvider>(),
              ),
              update: (context, inventoryProvider, previousSalesProvider) =>
                  previousSalesProvider ??
                  SalesProvider(inventoryProvider: inventoryProvider),
            ),
          ],
          child: MaterialApp(home: BarcodeScannerWidget()),
        ),
      );

      // Wait for initialization
      await tester.pump(Duration(seconds: 1));

      // Verify scanner elements
      expect(find.text('Scan Barcode'), findsOneWidget);
      expect(find.text('Position barcode in the frame'), findsOneWidget);
      expect(
        find.text('Camera will automatically scan when detected'),
        findsOneWidget,
      );
    });

    testWidgets('Dashboard cards prevent overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150, // Small width to test overflow prevention
              height: 100,
              child: DashboardCard(
                title: 'Very Long Title That Could Cause Overflow Issues',
                value: '999999999',
                icon: Icons.science,
                color: Colors.blue,
                isCurrency: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no overflow errors occurred
      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardCard), findsOneWidget);
    });

    testWidgets('Login handles invalid credentials', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider();

      // Test invalid login
      final loginResult = await authProvider.login('invalid', 'credentials');
      expect(
        loginResult,
        isFalse,
        reason: 'Login should fail with invalid credentials',
      );
      expect(
        authProvider.isAuthenticated,
        isFalse,
        reason: 'User should not be authenticated',
      );
    });
  });

  group('Widget Tests', () {
    testWidgets('DashboardCard displays correct information', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Test Title',
              value: '42',
              icon: Icons.science,
              color: Colors.blue,
              isCurrency: false,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.science), findsOneWidget);
    });

    testWidgets('Currency displays use ₱ symbol', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Today\'s Sales',
              value: '₱1,234.56',
              icon: Icons.attach_money,
              color: Colors.green,
              isCurrency: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('₱'), findsOneWidget);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('Count values display without currency symbols', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Total Products',
              value: '150',
              icon: Icons.inventory,
              color: Colors.blue,
              isCurrency: false,
            ),
          ),
        ),
      );

      expect(find.text('150'), findsOneWidget);
      expect(find.textContaining('₱'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
    });
  });

  group('Model Tests', () {
    test('Product model creates correctly', () {
      final product = Product(
        name: 'Test Product',

        cost: 5.50,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.name, 'Test Product');
      expect(product.price, 10.99);
      expect(product.cost, 5.50);
      expect(product.stock, 100);
      expect(product.isLowStock, false);
    });

    test('Product low stock detection works', () {
      final product = Product(
        name: 'Low Stock Product',

        cost: 5.50,
        stock: 3,
        minStock: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.isLowStock, true);
    });

    test('Product with barcode creates correctly', () {
      final product = Product(
        name: 'Barcode Product',
        barcode: '1234567890123',

        cost: 15.00,
        stock: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.barcode, '1234567890123');
      expect(product.name, 'Barcode Product');
    });

    test('Product copyWith method works correctly', () {
      final originalProduct = Product(
        name: 'Original Product',

        cost: 5.00,
        stock: 20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedProduct = originalProduct.copyWith(name: 'Updated Product');

      expect(updatedProduct.name, 'Updated Product');
      expect(updatedProduct.price, 15.00);
      expect(updatedProduct.cost, 5.00); // Should remain unchanged
      expect(updatedProduct.stock, 20); // Should remain unchanged
    });

    test('Customer credit calculations work', () {
      final customer = Customer(
        name: 'Test Customer',
        creditLimit: 1000.0,
        currentBalance: 750.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(customer.availableCredit, 250.0);
      expect(customer.hasOverdueBalance, false);

      final overdueCustomer = Customer(
        name: 'Overdue Customer',
        creditLimit: 500.0,
        currentBalance: 600.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(overdueCustomer.hasOverdueBalance, true);
    });

    test('Customer with zero credit limit', () {
      final customer = Customer(
        name: 'No Credit Customer',
        creditLimit: 0.0,
        currentBalance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(customer.availableCredit, 0.0);
      expect(customer.hasOverdueBalance, false);
    });
  });

  group('Currency Formatting Tests', () {
    test('CurrencyUtils formats correctly', () {
      expect(CurrencyUtils.formatCurrency(1234.56), equals('₱1,234.56'));
      expect(CurrencyUtils.formatCurrency(0.0), equals('₱0.00'));
      expect(CurrencyUtils.formatCurrencyWhole(1234.56), equals('₱1,235'));
      expect(CurrencyUtils.formatCurrency(1234567.89), equals('₱1,234,567.89'));
    });

    test('Currency validation works', () {
      expect(CurrencyUtils.isValidCurrency('₱1,234.56'), isTrue);
      expect(CurrencyUtils.isValidCurrency('\$1,234.56'), isFalse);
      expect(CurrencyUtils.isValidCurrency('invalid'), isFalse);
    });

    test('Currency parsing works', () {
      expect(CurrencyUtils.parseCurrency('₱1,234.56'), equals(1234.56));
      expect(CurrencyUtils.parseCurrency('₱0.00'), equals(0.0));
    });

    test('All currency displays should use Philippine Peso', () {
      final testAmounts = [0.0, 1.0, 10.50, 100.99, 1000.00, 9999.99];

      for (final amount in testAmounts) {
        final formatted = CurrencyUtils.formatCurrency(amount);
        expect(
          formatted.startsWith('₱'),
          isTrue,
          reason: 'Amount $amount should start with ₱',
        );
        expect(
          formatted.contains('\$'),
          isFalse,
          reason: 'Amount $amount should not contain "\$"',
        );
      }
    });

    group('Error Handling Tests', () {
      testWidgets('App handles provider errors gracefully', (
        WidgetTester tester,
      ) async {
        // Create providers that might throw errors
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider(
                create: (_) => InventoryProvider(ConnectivityProvider()),
              ),
              ChangeNotifierProxyProvider<InventoryProvider, SalesProvider>(
                create: (context) => SalesProvider(
                  inventoryProvider: context.read<InventoryProvider>(),
                ),
                update: (context, inventoryProvider, previousSalesProvider) =>
                    previousSalesProvider ??
                    SalesProvider(inventoryProvider: inventoryProvider),
              ),
              ChangeNotifierProvider(create: (_) => CustomerProvider()),
              ChangeNotifierProvider(create: (_) => CreditProvider()),
            ],
            child: MaterialApp(home: LoginScreen()),
          ),
        );

        // Verify no exceptions are thrown during widget build
        expect(tester.takeException(), isNull);
      });
    }); // <- Make sure you have proper closing braces and semicolons
  });
}
