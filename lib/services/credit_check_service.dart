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
    final tomorrow = today.add(const Duration(days: 1));

    final List<Sale> almostDue = [];
    final List<Sale> due = [];
    final List<Sale> overdue = [];

    for (final sale in allSales) {
      if (sale.dueDate != null) {
        final dueDate = sale.dueDate!;
        if (dueDate.year == tomorrow.year && dueDate.month == tomorrow.month && dueDate.day == tomorrow.day) {
          almostDue.add(sale);
        } else if (dueDate.year == today.year && dueDate.month == today.month && dueDate.day == today.day) {
          due.add(sale);
        } else if (dueDate.isBefore(today)) {
          overdue.add(sale);
        }
      }
    }

    if (almostDue.isNotEmpty) {
      _notificationService.showNotification(
        0,
        'Almost Due Payments',
        'You have ${almostDue.length} payment(s) almost due.',
        'almost_due',
      );
    }

    if (due.isNotEmpty) {
      _notificationService.showNotification(
        1,
        'Due Payments',
        'You have ${due.length} payment(s) due today.',
        'due',
      );
    }

    if (overdue.isNotEmpty) {
      _notificationService.showNotification(
        2,
        'Overdue Payments',
        'You have ${overdue.length} payment(s) overdue.',
        'overdue',
      );
    }
  }
}