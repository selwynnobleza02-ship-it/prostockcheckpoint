import 'package:flutter/material.dart';
import 'package:prostock/providers/sales_provider.dart';
import 'package:prostock/providers/inventory_provider.dart';
import 'package:prostock/models/credit_transaction.dart';
import 'package:prostock/screens/customers/dialogs/customer_details_dialog.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/customer_provider.dart';
import 'package:prostock/services/report_service.dart';
import 'package:prostock/utils/currency_utils.dart';
import 'package:prostock/widgets/report_helpers.dart';
import 'package:prostock/services/pdf_report_service.dart';
import 'package:prostock/widgets/export_filter_dialog.dart';
import 'dart:io';

class CustomersReportTab extends StatelessWidget {
  final List<CreditTransaction> creditTransactions;
  const CustomersReportTab({super.key, this.creditTransactions = const []});

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
        final totalCreditReceived = reportService.calculateTotalCreditPayments(
          creditTransactions,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    onPressed: () async {
                      try {
                        // Show filter options
                        final exportOptions = ExportFilterOptions(
                          useDataRangeFilter: false,
                          startDate: null,
                          endDate: null,
                        );

                        // Show the filter dialog
                        final result = await showDialog<ExportFilterOptions>(
                          context: context,
                          builder: (context) => ExportFilterDialog(
                            initialOptions: exportOptions,
                            onApply: (options) {
                              Navigator.of(context).pop(options);
                            },
                          ),
                        );

                        // If user cancelled the dialog
                        if (result == null || !context.mounted) return;

                        final options = result;
                        final scaffold = ScaffoldMessenger.of(context);

                        // Show loading indicator
                        scaffold.showSnackBar(
                          const SnackBar(
                            content: Text('Generating PDF...'),
                            duration: Duration(seconds: 2),
                          ),
                        );

                        final pdf = PdfReportService();
                        final inventory = context.read<InventoryProvider>();
                        final productById = {
                          for (final p in inventory.products) p.id: p,
                        };
                        final sections = <PdfReportSection>[
                          PdfReportSection(
                            title: 'Customer Summary',
                            rows: [
                              ['Total Customers', totalCustomers.toString()],
                              ['Active Customers', activeCustomers.toString()],
                              ['With Balance', customersWithBalance.toString()],
                              [
                                'Total Outstanding',
                                CurrencyUtils.formatCurrency(totalBalance),
                              ],
                              [
                                'Average Balance',
                                CurrencyUtils.formatCurrency(averageBalance),
                              ],
                              [
                                'Total Credit Received',
                                CurrencyUtils.formatCurrency(
                                  totalCreditReceived,
                                ),
                              ],
                              [
                                'Highest Balance',
                                CurrencyUtils.formatCurrency(highestBalance),
                              ],
                            ],
                          ),
                        ];

                        // Build per-customer total payments received
                        final Map<String, double> paymentsByCustomer = {};
                        for (final tx in creditTransactions.where(
                          (t) => t.type.toLowerCase() == 'payment',
                        )) {
                          paymentsByCustomer.update(
                            tx.customerId,
                            (v) => v + tx.amount,
                            ifAbsent: () => tx.amount,
                          );
                        }

                        if (paymentsByCustomer.isNotEmpty) {
                          final nameById = {
                            for (final c in customerProvider.customers)
                              c.id: c.name,
                          };
                          final paymentRows = <List<String>>[];
                          double totalReceived = 0.0;
                          final customerIds =
                              paymentsByCustomer.keys.toList(growable: false)
                                ..sort(
                                  (a, b) => (nameById[a] ?? a).compareTo(
                                    nameById[b] ?? b,
                                  ),
                                );
                          for (final id in customerIds) {
                            final name = nameById[id] ?? 'Unknown Customer';
                            final amount = paymentsByCustomer[id] ?? 0.0;
                            paymentRows.add([
                              name,
                              CurrencyUtils.formatCurrency(amount),
                            ]);
                            totalReceived += amount;
                          }
                          paymentRows.add([
                            'Total Received',
                            CurrencyUtils.formatCurrency(totalReceived),
                          ]);
                          sections.add(
                            PdfReportSection(
                              title: 'Customer Payments Received',
                              rows: paymentRows,
                            ),
                          );
                        }

                        // Build per-customer balances
                        final balanceRows = <List<String>>[];
                        double totalOutstanding = 0.0;
                        final customersSorted = [...customerProvider.customers]
                          ..sort((a, b) => a.name.compareTo(b.name));
                        for (final c in customersSorted) {
                          balanceRows.add([
                            c.name,
                            CurrencyUtils.formatCurrency(c.balance),
                          ]);
                          totalOutstanding += c.balance;
                        }
                        if (balanceRows.isNotEmpty) {
                          balanceRows.add([
                            'Total Outstanding',
                            CurrencyUtils.formatCurrency(totalOutstanding),
                          ]);
                          sections.add(
                            PdfReportSection(
                              title: 'Customer Balances',
                              rows: balanceRows,
                            ),
                          );
                        }

                        // Utang breakdown per customer: products bought on credit
                        // Include both credit sales and credit transactions
                        for (final customer in customersSorted) {
                          final Map<String, int> qtyByProduct = {};
                          final Map<String, double> amountByProduct = {};

                          // 1. Process credit sales (from salesProvider.sales)
                          final creditSalesForCustomer = salesProvider.sales
                              .where(
                                (s) =>
                                    (s.customerId == customer.id) &&
                                    s.paymentMethod.toLowerCase() == 'credit',
                              )
                              .toList();

                          if (creditSalesForCustomer.isNotEmpty) {
                            final saleIds = creditSalesForCustomer
                                .map((s) => s.id)
                                .whereType<String>()
                                .toSet();

                            for (final item in salesProvider.saleItems) {
                              if (saleIds.contains(item.saleId)) {
                                qtyByProduct.update(
                                  item.productId,
                                  (v) => v + item.quantity,
                                  ifAbsent: () => item.quantity,
                                );
                                amountByProduct.update(
                                  item.productId,
                                  (v) => v + item.totalPrice,
                                  ifAbsent: () => item.totalPrice,
                                );
                              }
                            }
                          }

                          // 2. Process credit transactions (from CreditTransaction with type 'purchase')
                          final creditTransactionsForCustomer =
                              creditTransactions
                                  .where(
                                    (t) =>
                                        (t.customerId == customer.id) &&
                                        t.type.toLowerCase() == 'purchase',
                                  )
                                  .toList();

                          for (final transaction
                              in creditTransactionsForCustomer) {
                            for (final item in transaction.items) {
                              qtyByProduct.update(
                                item.productId,
                                (v) => v + item.quantity,
                                ifAbsent: () => item.quantity,
                              );
                              amountByProduct.update(
                                item.productId,
                                (v) => v + item.totalPrice,
                                ifAbsent: () => item.totalPrice,
                              );
                            }
                          }

                          if (qtyByProduct.isEmpty) continue;

                          final rows =
                              <List<String>>[]; // [Product, Quantity, Amount]
                          int totalQty = 0;
                          double totalAmt = 0.0;
                          final productIds =
                              qtyByProduct.keys.toList(growable: false)..sort(
                                (a, b) => (productById[a]?.name ?? a).compareTo(
                                  productById[b]?.name ?? b,
                                ),
                              );
                          for (final pid in productIds) {
                            final name =
                                productById[pid]?.name ?? 'Unknown Product';
                            final qty = qtyByProduct[pid] ?? 0;
                            final amt = amountByProduct[pid] ?? 0.0;
                            rows.add([
                              name,
                              qty.toString(),
                              CurrencyUtils.formatCurrency(amt),
                            ]);
                            totalQty += qty;
                            totalAmt += amt;
                          }

                          rows.add([
                            'Total',
                            totalQty.toString(),
                            CurrencyUtils.formatCurrency(totalAmt),
                          ]);

                          sections.add(
                            PdfReportSection(
                              title: 'Utang Breakdown - ${customer.name}',
                              rows: rows,
                            ),
                          );
                        }

                        // Apply filter options to limit data
                        List<PdfReportSection> filteredSections = sections;
                        if (options.limitItemCount || options.summaryOnly) {
                          filteredSections = pdf.applyDataLimits(
                            sections,
                            maxRowsPerSection: options.maxItemCount,
                            summaryOnly: options.summaryOnly,
                          );
                        }

                        try {
                          // Show progress dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Generating PDF...\nPlease wait.'),
                                ],
                              ),
                            ),
                          );

                          // Generate the PDF with filtered sections in background
                          final file = await pdf.generatePdfInBackground(
                            reportTitle:
                                'Customer Activity Report - Sari-Sari Store',
                            startDate: null,
                            endDate: null,
                            sections: filteredSections,
                          );

                          // Close progress dialog
                          if (!context.mounted) return;
                          Navigator.of(context).pop();

                          if (!context.mounted) return;
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text('PDF saved: ${file.path}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } catch (e) {
                          // Close progress dialog if still showing
                          if (!context.mounted) return;
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }

                          // If we get TooManyPagesException, try paginated approach
                          if (e.toString().contains('TooManyPagesException')) {
                            scaffold.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Document too large, splitting into multiple PDFs...',
                                ),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );

                            // Show progress dialog for paginated generation
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Creating multiple PDF files...\nPlease wait.',
                                    ),
                                  ],
                                ),
                              ),
                            );

                            // Generate paginated PDFs in background
                            final files = await pdf
                                .generatePaginatedPDFsInBackground(
                                  reportTitle:
                                      'Customer Activity Report - Sari-Sari Store',
                                  startDate: null,
                                  endDate: null,
                                  sections: filteredSections,
                                  sectionsPerPdf: 3, // Fewer sections per PDF
                                );

                            // Close progress dialog
                            if (!context.mounted) return;
                            Navigator.of(context).pop();

                            if (!context.mounted) return;

                            scaffold.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Generated ${files.length} PDF files in ${Directory(files.first.parent.path).path}',
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          } else {
                            rethrow; // Re-throw to be caught by outer catch
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error generating PDF: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Enhanced summary cards grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
                    Icons.credit_card,
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
                  color: Theme.of(context).colorScheme.surfaceContainer,
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
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Outstanding Balances',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    final colorScheme = Theme.of(context).colorScheme;
                    final textTheme = Theme.of(context).textTheme;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                CustomerDetailsDialog(customer: customerData),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isHighPriority
                                      ? colorScheme.errorContainer
                                      : colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  isHighPriority
                                      ? Icons.priority_high
                                      : Icons.person,
                                  color: isHighPriority
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onSecondaryContainer,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerData.name,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phone: ${customerData.phone ?? 'Not provided'}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (customerData.phone?.isEmpty != false)
                                      Text(
                                        'No contact info',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.error,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Amount & Badge
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyUtils.formatCurrency(
                                      customerData.balance,
                                    ),
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isHighPriority
                                          ? colorScheme.error
                                          : colorScheme.secondary,
                                    ),
                                  ),
                                  if (isHighPriority) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'HIGH',
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Outstanding Balances',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All customers have cleared their balances',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
