import 'package:flutter/material.dart';
import 'package:prostock/utils/notification_tester.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _isLoading = false;

  Future<void> _runTest(
    String testName,
    Future<void> Function() testFunction,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await testFunction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$testName completed! Check your notifications.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$testName failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Notification System',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use these buttons to test if notifications are working properly. You should receive push notifications like text messages.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runTest(
                      'Direct Notification Test',
                      NotificationTester.testDirectNotifications,
                    ),
              icon: const Icon(Icons.notifications_active),
              label: const Text('Test Direct Notifications'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runTest(
                      'Customer Payment Check',
                      NotificationTester.testCustomerPaymentNotifications,
                    ),
              icon: const Icon(Icons.payment),
              label: const Text('Test Customer Payment Notifications'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runTest(
                      'Scheduled Notification Test',
                      NotificationTester.testScheduledNotification,
                    ),
              icon: const Icon(Icons.schedule),
              label: const Text('Test Scheduled Notification (10s delay)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 32),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            const Expanded(child: SizedBox()),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Test:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap "Test Direct Notifications" - you should get 4 test notifications immediately',
                  ),
                  Text(
                    '2. Tap "Test Customer Payment Notifications" - checks your actual sales data',
                  ),
                  Text(
                    '3. Tap "Test Scheduled Notification" - you\'ll get a notification in 10 seconds',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'If you don\'t receive notifications, check your device\'s notification permissions for ProStock.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
