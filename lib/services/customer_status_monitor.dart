import 'package:flutter/material.dart';
import 'package:prostock/models/customer.dart';
import 'package:prostock/services/notification_service.dart';
import 'package:prostock/services/local_database_service.dart';

enum CustomerStatus {
  good, // Green - no balance or within credit limit
  warning, // Orange - has balance but not overdue
  almostDue, // Yellow - payment due within 1-2 days
  overdue, // Red - overdue payments
}

class CustomerStatusMonitor {
  static final CustomerStatusMonitor _instance =
      CustomerStatusMonitor._internal();
  factory CustomerStatusMonitor() => _instance;
  CustomerStatusMonitor._internal();

  final NotificationService _notificationService = NotificationService();
  final LocalDatabaseService _localDatabaseService =
      LocalDatabaseService.instance;

  // Track previous customer statuses to detect changes
  final Map<String, CustomerStatus> _previousStatuses = {};

  /// Initialize the monitor with current customer statuses
  Future<void> initialize() async {
    await _loadCurrentStatuses();
  }

  /// Check for customer status changes and send notifications
  Future<void> checkStatusChanges(List<Customer> customers) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    for (final customer in customers) {
      final currentStatus = await _determineCustomerStatus(
        customer,
        todayStart,
      );
      final previousStatus = _previousStatuses[customer.id];

      // Only notify if status actually changed
      if (previousStatus != null && previousStatus != currentStatus) {
        await _sendStatusChangeNotification(
          customer,
          previousStatus,
          currentStatus,
        );
      }

      // Update the stored status
      _previousStatuses[customer.id] = currentStatus;
    }
  }

  /// Determine the current status of a customer
  Future<CustomerStatus> _determineCustomerStatus(
    Customer customer,
    DateTime todayStart,
  ) async {
    // Check if customer has overdue payments (2 days past due date)
    final db = await _localDatabaseService.database;
    final overdueThreshold = todayStart.subtract(const Duration(days: 2));
    final overdueSales = await db.query(
      'sales',
      where: 'customer_id = ? AND due_date < ? AND due_date IS NOT NULL',
      whereArgs: [customer.id, overdueThreshold.toIso8601String()],
    );

    if (overdueSales.isNotEmpty) {
      return CustomerStatus.overdue;
    }

    // Get all sales with due dates for this customer
    final allSalesWithDueDates = await db.query(
      'sales',
      where: 'customer_id = ? AND due_date IS NOT NULL',
      whereArgs: [customer.id],
      orderBy: 'due_date ASC',
    );

    if (allSalesWithDueDates.isEmpty) {
      // No sales with due dates, check if customer has balance
      if (customer.balance > 0) {
        return CustomerStatus.warning;
      }
      return CustomerStatus.good;
    }

    // Find the earliest due date among all sales
    final earliestDueDate = DateTime.parse(
      allSalesWithDueDates.first['due_date'] as String,
    );
    final daysUntilDue = earliestDueDate.difference(todayStart).inDays;

    // Determine status based on earliest due date
    if (daysUntilDue <= -2) {
      // Overdue (2+ days past due date)
      return CustomerStatus.overdue;
    } else if (daysUntilDue <= 2) {
      // Due within 1-2 days (including due today and 1 day past due)
      return CustomerStatus.almostDue;
    } else if (customer.balance > 0) {
      // Has balance but not due soon
      return CustomerStatus.warning;
    }

    return CustomerStatus.good;
  }

  /// Send notification when customer status changes
  Future<void> _sendStatusChangeNotification(
    Customer customer,
    CustomerStatus oldStatus,
    CustomerStatus newStatus,
  ) async {
    String title;
    String body;
    int notificationId = customer.id.hashCode;

    switch (newStatus) {
      case CustomerStatus.overdue:
        title = '🚨 Customer Overdue Alert';
        body = '${customer.name} has overdue payments and needs attention';
        break;
      case CustomerStatus.almostDue:
        title = '⏰ Payment Due Soon';
        body = await _getAlmostDueMessage(customer);
        break;
      case CustomerStatus.warning:
        title = '⚠️ Customer Balance Alert';
        body =
            '${customer.name} has an outstanding balance of ₱${customer.balance.toStringAsFixed(2)}';
        break;
      case CustomerStatus.good:
        title = '✅ Customer Status Updated';
        body = '${customer.name} is now in good standing';
        break;
    }

    await _notificationService.showNotification(
      notificationId,
      title,
      body,
      'customer_status:${customer.id}:${newStatus.name}',
    );
  }

  /// Get detailed message for almost due status
  Future<String> _getAlmostDueMessage(Customer customer) async {
    final db = await _localDatabaseService.database;
    final todayStart = DateTime.now();
    final almostDueStart = todayStart.subtract(
      const Duration(days: 1),
    ); // Include 1 day past due
    final almostDueEnd = todayStart.add(
      const Duration(days: 2),
    ); // Include 2 days from now

    final almostDueSales = await db.query(
      'sales',
      where:
          'customer_id = ? AND due_date >= ? AND due_date <= ? AND due_date IS NOT NULL',
      whereArgs: [
        customer.id,
        almostDueStart.toIso8601String(),
        almostDueEnd.toIso8601String(),
      ],
      orderBy: 'due_date ASC',
    );

    if (almostDueSales.isEmpty) {
      return '${customer.name} has payments due within 1-2 days';
    }

    final earliestDueDate = DateTime.parse(
      almostDueSales.first['due_date'] as String,
    );
    final daysUntilDue = earliestDueDate.difference(todayStart).inDays;

    if (daysUntilDue == 0) {
      return '${customer.name} has payment due today (₱${customer.balance.toStringAsFixed(2)})';
    } else if (daysUntilDue == 1) {
      return '${customer.name} has payment due tomorrow (₱${customer.balance.toStringAsFixed(2)})';
    } else if (daysUntilDue == -1) {
      return '${customer.name} has payment 1 day overdue (₱${customer.balance.toStringAsFixed(2)})';
    } else if (daysUntilDue > 0) {
      return '${customer.name} has payment due in $daysUntilDue days (₱${customer.balance.toStringAsFixed(2)})';
    } else {
      return '${customer.name} has payment ${-daysUntilDue} days overdue (₱${customer.balance.toStringAsFixed(2)})';
    }
  }

  /// Load current customer statuses from database
  Future<void> _loadCurrentStatuses() async {
    final db = await _localDatabaseService.database;
    final customers = await db.query('customers');
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    for (final customerData in customers) {
      final customer = Customer.fromMap(customerData);
      final status = await _determineCustomerStatus(customer, todayStart);
      _previousStatuses[customer.id] = status;
    }
  }

  /// Get status color for UI display
  static Color getStatusColor(CustomerStatus status) {
    switch (status) {
      case CustomerStatus.good:
        return Colors.green;
      case CustomerStatus.warning:
        return Colors.orange;
      case CustomerStatus.almostDue:
        return Colors.amber;
      case CustomerStatus.overdue:
        return Colors.red;
    }
  }

  /// Get status description for UI display
  static String getStatusDescription(CustomerStatus status) {
    switch (status) {
      case CustomerStatus.good:
        return 'Good Standing';
      case CustomerStatus.warning:
        return 'Has Balance';
      case CustomerStatus.almostDue:
        return 'Due Soon';
      case CustomerStatus.overdue:
        return 'Overdue';
    }
  }
}
