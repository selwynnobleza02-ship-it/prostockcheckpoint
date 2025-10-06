import 'package:prostock/services/customer_status_monitor.dart';
import 'package:prostock/models/customer.dart';

/// Test utility for customer status monitoring
class CustomerStatusTest {
  static Future<void> testStatusChanges() async {
    final monitor = CustomerStatusMonitor();
    await monitor.initialize();

    // Create test customers with different statuses
    final testCustomers = [
      Customer(
        id: 'test1',
        name: 'Test Customer 1',
        balance: 0.0,
        creditLimit: 1000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Customer(
        id: 'test2',
        name: 'Test Customer 2',
        balance: 500.0,
        creditLimit: 1000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Customer(
        id: 'test3',
        name: 'Test Customer 3',
        balance: 1200.0,
        creditLimit: 1000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    // Test status monitoring
    await monitor.checkStatusChanges(testCustomers);

    print('Customer status monitoring test completed');
  }
}
