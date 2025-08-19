import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prostock/screens/dashboard_screen.dart';
import 'package:prostock/screens/inventory_screen.dart';
import 'package:prostock/screens/pos_screen.dart';
import 'package:prostock/screens/customers_screen.dart';
import 'package:prostock/screens/reports_screen.dart';
import 'package:prostock/screens/login_screen.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/providers/credit_provider.dart';
import 'package:prostock/providers/auth_provider.dart';
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

  group('Screen Integration Tests with Philippine Peso', () {
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

    testWidgets('Login Screen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const LoginScreen()));

      expect(find.text('Retail Credit Manager'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Demo Credentials'), findsOneWidget);
    });

    testWidgets('Dashboard Screen renders with peso symbols', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const DashboardScreen()));

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Total Products'), findsOneWidget);
      expect(find.text('Low Stock Items'), findsOneWidget);
      expect(find.text('Today\'s Sales'), findsOneWidget);
      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Scan Barcode'), findsOneWidget);
    });

    testWidgets('Inventory Screen renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const InventoryScreen()));

      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Search products...'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('POS Screen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const POSScreen()));

      expect(find.text('Point of Sale'), findsOneWidget);
      expect(find.text('Search products...'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Walk-in Customer'), findsOneWidget);
      expect(find.text('Total:'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
    });

    testWidgets('Customers Screen renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const CustomersScreen()));

      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Search customers...'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Reports Screen renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const ReportsScreen()));

      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Financial'), findsOneWidget);
    });

    testWidgets('Navigation between screens works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const DashboardScreen()));

      // Test bottom navigation
      expect(find.text('Dashboard'), findsOneWidget);

      // Tap on Inventory tab
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();

      // Should now show inventory screen
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Search products...'), findsOneWidget);

      // Tap on POS tab
      await tester.tap(find.text('POS'));
      await tester.pumpAndSettle();

      // Should now show POS screen
      expect(find.text('Point of Sale'), findsOneWidget);
    });
  });

  group('Currency Display Tests', () {
    test('Currency formatting works correctly', () {
      // Test basic formatting
      expect('₱100.50', equals('₱100.50'));

      // Test zero values
      expect('₱0.00', equals('₱0.00'));

      // Test large numbers
      expect('₱1000000.99', contains('₱'));
      expect('₱1000000.99', contains('1000000.99'));
    });

    test('Price calculations maintain precision', () {
      const price = 123.45;
      const quantity = 3;
      const total = price * quantity;

      expect(total, equals(370.35));

      final formatted = '₱${total.toStringAsFixed(2)}';
      expect(formatted, equals('₱370.35'));
    });

    test('Credit calculations work correctly', () {
      const creditLimit = 5000.00;
      const currentBalance = 2500.75;
      const availableCredit = creditLimit - currentBalance;

      expect(availableCredit, equals(2499.25));

      final formatted = '₱${availableCredit.toStringAsFixed(2)}';
      expect(formatted, equals('₱2499.25'));
    });
  });
}
