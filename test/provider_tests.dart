import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:prostock/models/paginated_result.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/models/product.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/services/firestore_service.dart';

// Generate mocks
@GenerateMocks([FirestoreService])
import 'provider_tests.mocks.dart';

void main() {
  group('InventoryProvider Tests', () {
    late InventoryProvider inventoryProvider;
    late MockFirestoreService mockFirestoreService;

    setUp(() {
      mockFirestoreService = MockFirestoreService();
      inventoryProvider = InventoryProvider();
    });

    test('loadProducts updates products list', () async {
      // Arrange
      final testProducts = [
        Product(
          id: '1',
          name: 'Test Product 1',
          price: 10.0,
          cost: 5.0,
          stock: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: '2',
          name: 'Test Product 2',
          price: 20.0,
          cost: 10.0,
          stock: 50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        mockFirestoreService.getProductsPaginated(
          limit: anyNamed('limit'),
          lastDocument: anyNamed('lastDocument'),
          searchQuery: anyNamed('searchQuery'),
        ),
      ).thenAnswer(
        (_) async => PaginatedResult(items: testProducts, lastDocument: null),
      );
      // Act
      await inventoryProvider.loadProducts();

      // Assert
      expect(inventoryProvider.products.length, equals(2));
      expect(inventoryProvider.products[0].name, equals('Test Product 1'));
      expect(inventoryProvider.isLoading, isFalse);
    });

    test('addProduct adds product to list', () async {
      // Arrange
      final newProduct = Product(
        name: 'New Product',
        price: 15.0,
        cost: 7.5,
        stock: 75,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(
        mockFirestoreService.insertProduct(any),
      ).thenAnswer((_) async => 'new-product-id');

      // Act
      final result = await inventoryProvider.addProduct(newProduct);

      // Assert
      expect(result, isTrue);
      expect(inventoryProvider.products.length, equals(1));
      expect(inventoryProvider.products[0].name, equals('New Product'));
    });

    test('reduceStock reduces product stock correctly', () async {
      // Arrange
      final product = Product(
        id: '1',
        name: 'Test Product',
        price: 10.0,
        cost: 5.0,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      inventoryProvider.products.add(product);

      when(mockFirestoreService.updateProduct(any)).thenAnswer((_) async => {});
      when(
        mockFirestoreService.insertStockMovement(
          any.toString(),
          any.toString(),
          any.toString() as int,
          any,
        ),
      ).thenAnswer((_) async => 'movement-id');

      // Act
      final result = await inventoryProvider.reduceStock(1 as String, 10);

      // Assert
      expect(result, isTrue);
      expect(inventoryProvider.products[0].stock, equals(90));
    });

    test('reduceStock fails with insufficient stock', () async {
      // Arrange
      final product = Product(
        id: '1',
        name: 'Test Product',
        price: 10.0,
        cost: 5.0,
        stock: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      inventoryProvider.products.add(product);

      // Act
      final result = await inventoryProvider.reduceStock(1 as String, 10);

      // Assert
      expect(result, isFalse);
      expect(inventoryProvider.error, contains('Insufficient stock'));
    });

    test('lowStockProducts returns products with low stock', () {
      // Arrange
      final products = [
        Product(
          id: '1',
          name: 'Normal Stock',
          price: 10.0,
          cost: 5.0,
          stock: 100,
          minStock: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: '2',
          name: 'Low Stock',
          price: 20.0,
          cost: 10.0,
          stock: 5,
          minStock: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      inventoryProvider.products.addAll(products);

      // Act
      final lowStockProducts = inventoryProvider.lowStockProducts;

      // Assert
      expect(lowStockProducts.length, equals(1));
      expect(lowStockProducts[0].name, equals('Low Stock'));
    });
  });

  group('SalesProvider Tests', () {
    late SalesProvider salesProvider;
    late InventoryProvider inventoryProvider;

    setUp(() {
      inventoryProvider = InventoryProvider();
      salesProvider = SalesProvider(inventoryProvider: inventoryProvider);
    });

    test('addItemToCurrentSale adds item correctly', () {
      // Arrange
      final product = Product(
        id: '1',
        name: 'Test Product',
        price: 10.0,
        cost: 5.0,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      salesProvider.addItemToCurrentSale(product, 2);

      // Assert
      expect(salesProvider.currentSaleItems.length, equals(1));
      expect(salesProvider.currentSaleItems[0].quantity, equals(2));
      expect(salesProvider.currentSaleItems[0].totalPrice, equals(20.0));
      expect(salesProvider.currentSaleTotal, equals(20.0));
    });

    test('addItemToCurrentSale updates existing item quantity', () {
      // Arrange
      final product = Product(
        id: '1',
        name: 'Test Product',
        price: 10.0,
        cost: 5.0,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      salesProvider.addItemToCurrentSale(product, 2);
      salesProvider.addItemToCurrentSale(product, 3);

      // Assert
      expect(salesProvider.currentSaleItems.length, equals(1));
      expect(salesProvider.currentSaleItems[0].quantity, equals(5));
      expect(salesProvider.currentSaleItems[0].totalPrice, equals(50.0));
    });

    test('removeItemFromCurrentSale removes item correctly', () {
      // Arrange
      final product = Product(
        id: '1',
        name: 'Test Product',
        price: 10.0,
        cost: 5.0,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      salesProvider.addItemToCurrentSale(product, 2);

      // Act
      salesProvider.removeItemFromCurrentSale(0);

      // Assert
      expect(salesProvider.currentSaleItems.length, equals(0));
      expect(salesProvider.currentSaleTotal, equals(0.0));
    });

    test('clearCurrentSale clears all items', () {
      // Arrange
      final product = Product(
        id: '1',
        name: 'Test Product',
        price: 10.0,
        cost: 5.0,
        stock: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      salesProvider.addItemToCurrentSale(product, 2);

      // Act
      salesProvider.clearCurrentSale();

      // Assert
      expect(salesProvider.currentSaleItems.length, equals(0));
      expect(salesProvider.currentSaleTotal, equals(0.0));
      expect(salesProvider.error, isNull);
    });
  });

  group('AuthProvider Tests', () {
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider();
    });

    test('initial state is not authenticated', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
    });

    test('login with valid credentials succeeds', () async {
      // Act
      final result = await authProvider.login('admin', 'admin123');

      // Assert
      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser, isNotNull);
    });

    test('login with invalid credentials fails', () async {
      // Act
      final result = await authProvider.login('invalid', 'credentials');

      // Assert
      expect(result, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
    });

    test('logout clears authentication state', () async {
      // Arrange
      await authProvider.login('admin', 'admin123');
      expect(authProvider.isAuthenticated, isTrue);

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
    });
  });

  group('CustomerProvider Tests', () {
    late CustomerProvider customerProvider;

    setUp(() {
      customerProvider = CustomerProvider();
    });

    test('addCustomer adds customer to list', () async {
      // Arrange
      final customer = Customer(
        name: 'Test Customer',
        email: 'test@example.com',
        phone: '+1234567890',
        creditLimit: 1000.0,
        currentBalance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final result = await customerProvider.addCustomer(customer);

      // Assert
      expect(result, isTrue);
      expect(customerProvider.customers.length, equals(1));
      expect(customerProvider.customers[0].name, equals('Test Customer'));
    });

    test('updateCustomerBalance updates balance correctly', () async {
      // Arrange
      final customer = Customer(
        id: '1',
        name: 'Test Customer',
        creditLimit: 1000.0,
        currentBalance: 100.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      customerProvider.customers.add(customer);

      // Act
      final result = await customerProvider.updateCustomerBalance(
        1 as String,
        50.0,
      );

      // Assert
      expect(result, isTrue);
      expect(customerProvider.customers[0].currentBalance, equals(150.0));
    });
  });
}
