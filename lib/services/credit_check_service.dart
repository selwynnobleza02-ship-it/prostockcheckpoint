import 'package:prostock/models/sale.dart';
import 'package:prostock/services/local_database_service.dart';
import 'package:prostock/services/notification_service.dart';

class CreditCheckService {
  final LocalDatabaseService _localDatabaseService;
  final NotificationService _notificationService;

  CreditCheckService(this._localDatabaseService, this._notificationService);

  Future<void> checkDuePaymentsAndNotify() async {
    final db = await _localDatabaseService.database;
    final sales = await db.query('sales');

    final List<Sale> allSales = sales.map((s) => Sale.fromMap(s)).toList();

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    // Almost due: 1-2 days from now
    final almostDueStart = todayStart.add(const Duration(days: 1));
    final almostDueEnd = todayStart.add(const Duration(days: 3));

    final List<Sale> almostDue = [];
    final List<Sale> due = [];
    final List<Sale> overdue = [];

    for (final sale in allSales) {
      if (sale.dueDate != null && sale.customerId != null) {
        final dueDate = sale.dueDate!;
        final dueDateStart = DateTime(dueDate.year, dueDate.month, dueDate.day);

        if (dueDateStart.isBefore(todayStart)) {
          // Overdue: due date has passed
          overdue.add(sale);
        } else if (dueDateStart.isAtSameMomentAs(todayStart)) {
          // Due today
          due.add(sale);
        } else if ((dueDateStart.isAtSameMomentAs(almostDueStart) ||
                dueDateStart.isAfter(almostDueStart)) &&
            dueDateStart.isBefore(almostDueEnd)) {
          // Almost due: 1-2 days from now
          almostDue.add(sale);
        }
      }
    }

    if (almostDue.isNotEmpty) {
      final customerNames = await _getCustomerNames(almostDue);
      _notificationService.showNotification(
        0,
        'Almost Due Payments',
        '${almostDue.length} payment(s) almost due: ${customerNames.join(', ')}',
        'almost_due',
      );
    }

    if (due.isNotEmpty) {
      final customerNames = await _getCustomerNames(due);
      _notificationService.showNotification(
        1,
        'Due Payments',
        '${due.length} payment(s) due today: ${customerNames.join(', ')}',
        'due',
      );
    }

    if (overdue.isNotEmpty) {
      final customerNames = await _getCustomerNames(overdue);
      _notificationService.showNotification(
        2,
        'Overdue Payments',
        '${overdue.length} payment(s) overdue: ${customerNames.join(', ')}',
        'overdue',
      );
    }
  }

  Future<List<String>> _getCustomerNames(List<Sale> sales) async {
    final db = await _localDatabaseService.database;
    final customerIds = sales
        .map((s) => s.customerId)
        .where((id) => id != null)
        .toSet();

    if (customerIds.isEmpty) return ['Unknown Customer'];

    final customers = await db.query(
      'customers',
      where: 'id IN (${customerIds.map((_) => '?').join(',')})',
      whereArgs: customerIds.toList(),
    );

    final customerMap = {for (var c in customers) c['id']: c['name'] as String};

    return sales
        .map((s) => customerMap[s.customerId] ?? 'Unknown Customer')
        .toSet()
        .toList();
  }
}
