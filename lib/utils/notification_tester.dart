import 'package:prostock/services/credit_check_service.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/notification_service.dart';

/// Utility class to test notifications manually
class NotificationTester {
  static Future<void> testCustomerPaymentNotifications() async {
    final notificationService = NotificationService();
    final creditCheckService = CreditCheckService(
      LocalDatabaseService.instance,
      notificationService,
    );

    // Test the actual credit check service
    await creditCheckService.checkDuePaymentsAndNotify();
  }

  static Future<void> testDirectNotifications() async {
    final notificationService = NotificationService();

    // Test direct notifications
    await notificationService.showNotification(
      999,
      'Test Notification',
      'This is a test notification to verify the system works',
      'test',
    );

    // Test overdue notification
    await notificationService.showNotification(
      998,
      'Test Overdue Payment',
      'John Doe has an overdue payment of \$150.00',
      'test_overdue',
    );

    // Test due today notification
    await notificationService.showNotification(
      997,
      'Test Due Payment',
      'Jane Smith has a payment due today of \$75.00',
      'test_due',
    );

    // Test almost due notification
    await notificationService.showNotification(
      996,
      'Test Almost Due Payment',
      'Mike Johnson has a payment due in 3 days of \$200.00',
      'test_almost_due',
    );
  }

  static Future<void> testScheduledNotification() async {
    final notificationService = NotificationService();

    // Schedule a notification for 10 seconds from now
    await notificationService.scheduleNotification(
      id: 995,
      title: 'Scheduled Test',
      body: 'This notification was scheduled 10 seconds ago',
      scheduledDate: DateTime.now().add(const Duration(seconds: 10)),
      payload: 'scheduled_test',
    );
  }
}
