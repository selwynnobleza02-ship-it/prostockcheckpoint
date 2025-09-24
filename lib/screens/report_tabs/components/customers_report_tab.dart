import 'package:flutter/material.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';

class CustomersReportTab extends StatelessWidget {
  const CustomersReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();
    return Consumer2<CustomerProvider, SalesProvider>(
      builder: (context, customerProvider, salesProvider, child) {
        final totalCustomers = reportService.calculateTotalCustomers(
          customerProvider.customers,
        );
        final customersWithBalance = reportService
            .calculateCustomersWithBalance(customerProvider.customers);
        final totalBalance = reportService.calculateTotalBalance(
          customerProvider.customers,
        );

        // Calculate additional metrics
        final activeCustomers = customerProvider.customers
            .where((c) => c.balance == 0)
            .length;
        final averageBalance = customersWithBalance > 0
            ? totalBalance / customersWithBalance
            : 0.0;
        final totalCreditReceived = reportService.calculateTotalCreditReceived(
          salesProvider.sales,
        );
        final highestBalance = customerProvider.customers.isNotEmpty
            ? customerProvider.customers
                  .map((c) => c.balance)
                  .reduce((a, b) => a > b ? a : b)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced summary cards grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  buildSummaryCard(
                    context,
                    'Total Customers',
                    totalCustomers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  buildSummaryCard(
                    context,
                    'Active Customers',
                    activeCustomers.toString(),
                    Icons.person_outline,
                    Colors.green,
                  ),
                  buildSummaryCard(
                    context,
                    'With Balance',
                    customersWithBalance.toString(),
                    Icons.credit_card_off,
                    Colors.orange,
                  ),
                  buildSummaryCard(
                    context,
                    'Total Credit Received',
                    CurrencyUtils.formatCurrency(totalCreditReceived),
                    Icons.attach_money,
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Balance summary cards
              Row(
                children: [
                  Expanded(
                    child: buildSummaryCard(
                      context,
                      'Total Outstanding',
                      CurrencyUtils.formatCurrency(totalBalance),
                      Icons.account_balance,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: buildSummaryCard(
                      context,
                      'Average Balance',
                      CurrencyUtils.formatCurrency(averageBalance),
                      Icons.calculate,
                      Colors.teal,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              buildSummaryCard(
                context,
                'Highest Balance',
                CurrencyUtils.formatCurrency(highestBalance),
                Icons.trending_up,
                Colors.indigo,
              ),

              const SizedBox(height: 24),

              // Customer Analysis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Active Customers:')),
                        Flexible(
                          child: Text(
                            '${totalCustomers > 0 ? ((activeCustomers / totalCustomers) * 100).toStringAsFixed(1) : 0}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Contact Coverage:')),
                        Flexible(
                          child: Text(
                            '${totalCustomers > 0 ? ((customerProvider.customers.where((c) => c.phone?.isNotEmpty == true).length / totalCustomers) * 100).toStringAsFixed(1) : 0}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  customerProvider.customers
                                              .where(
                                                (c) =>
                                                    c.phone?.isNotEmpty == true,
                                              )
                                              .length /
                                          (totalCustomers == 0
                                              ? 1
                                              : totalCustomers) >=
                                      0.8
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Collection Status:')),
                        Flexible(
                          child: Text(
                            _getCollectionStatus(totalBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getCollectionStatusColor(totalBalance),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Customer Health:')),
                        Flexible(
                          child: Text(
                            _getCustomerHealth(
                              customersWithBalance,
                              totalCustomers,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getCustomerHealthColor(
                                customersWithBalance,
                                totalCustomers,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (customersWithBalance > 0) ...[
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.orange.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Outstanding Balances',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: customerProvider.customers
                      .where((c) => c.balance > 0)
                      .length,
                  itemBuilder: (context, index) {
                    final customer =
                        customerProvider.customers
                            .where((c) => c.balance > 0)
                            .toList()
                          ..sort((a, b) => b.balance.compareTo(a.balance));
                    final customerData = customer[index];
                    final isHighPriority =
                        customerData.balance > (averageBalance * 1.5);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isHighPriority
                                ? Colors.red.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            isHighPriority ? Icons.priority_high : Icons.person,
                            color: isHighPriority
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          customerData.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Phone: ${customerData.phone ?? 'Not provided'}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (customerData.phone?.isEmpty != false)
                              Text(
                                'No contact info',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyUtils.formatCurrency(
                                customerData.balance,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isHighPriority
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                            if (isHighPriority)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Text(
                                  'HIGH',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                CustomerDetailsDialog(customer: customerData),
                          );
                        },
                      ),
                    );
                  },
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Outstanding Balances',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All customers have cleared their balances',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getCollectionStatus(double totalBalance) {
    if (totalBalance == 0) return 'Excellent';
    if (totalBalance < 10000) return 'Good';
    if (totalBalance < 50000) return 'Fair';
    return 'Needs Attention';
  }

  Color _getCollectionStatusColor(double totalBalance) {
    if (totalBalance == 0) return Colors.green;
    if (totalBalance < 10000) return Colors.blue;
    if (totalBalance < 50000) return Colors.orange;
    return Colors.red;
  }

  String _getCustomerHealth(int withBalance, int total) {
    if (total == 0) return 'No Data';
    final healthyPercentage = ((total - withBalance) / total) * 100;

    if (healthyPercentage >= 90) return 'Excellent';
    if (healthyPercentage >= 75) return 'Good';
    if (healthyPercentage >= 60) return 'Fair';
    return 'Needs Attention';
  }

  Color _getCustomerHealthColor(int withBalance, int total) {
    if (total == 0) return Colors.grey;
    final healthyPercentage = ((total - withBalance) / total) * 100;

    if (healthyPercentage >= 90) return Colors.green;
    if (healthyPercentage >= 75) return Colors.blue;
    if (healthyPercentage >= 60) return Colors.orange;
    return Colors.red;
  }
}
