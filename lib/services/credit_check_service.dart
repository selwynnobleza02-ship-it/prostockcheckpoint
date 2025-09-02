import 'package:prostock/models/customer.dart';
import 'package:prostock/models/sale.dart';

class CreditCheckService {
  List<Customer> getOverdueCustomers(List<Customer> customers, List<Sale> sales) {
    final overdueCustomers = <Customer>{};

    for (final sale in sales) {
      if (sale.paymentMethod == 'credit' &&
          sale.dueDate != null &&
          sale.dueDate!.isBefore(DateTime.now())) {
        final customer = customers.firstWhere((c) => c.id == sale.customerId);
        overdueCustomers.add(customer);
      }
    }

    return overdueCustomers.toList();
  }
}
