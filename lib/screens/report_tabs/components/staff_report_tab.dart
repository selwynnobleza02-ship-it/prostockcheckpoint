import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/services/pdf_report_service.dart';
import 'package:prostock/widgets/export_filter_dialog.dart';
import 'dart:io';

class StaffReportTab extends StatefulWidget {
  const StaffReportTab({super.key});

  @override
  State<StaffReportTab> createState() => _StaffReportTabState();
}

class _StaffReportTabState extends State<StaffReportTab> {
  late Stream<List<UserActivity>> _activityStream;

  @override
  void initState() {
    super.initState();
    _activityStream = context.read<ActivityService>().getActivitiesStream();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
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

                  final activities = await _activityStream.first;

                  final actionsCount = <String, int>{};
                  for (final a in activities) {
                    actionsCount.update(
                      a.action,
                      (v) => v + 1,
                      ifAbsent: () => 1,
                    );
                  }

                  final sections = <PdfReportSection>[
                    PdfReportSection(
                      title: 'Staff Summary',
                      rows: [
                        ['Current User', auth.username ?? ''],
                        ['Total Activities', activities.length.toString()],
                      ],
                    ),
                    PdfReportSection(
                      title: 'Actions Breakdown',
                      rows: actionsCount.entries
                          .map((e) => [e.key, e.value.toString()])
                          .toList(),
                    ),
                  ];

                  final pdf = PdfReportService();

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
                      reportTitle: 'Staff Performance Report - Sari-Sari Store',
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
                      final files = await pdf.generatePaginatedPDFsInBackground(
                        reportTitle:
                            'Staff Performance Report - Sari-Sari Store',
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
                  if (mounted && context.mounted) {
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
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserActivity>>(
            stream: _activityStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final activities = snapshot.data!;
              if (activities.isEmpty) {
                return const Center(child: Text('No staff activity yet.'));
              }
              return ListView.builder(
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final a = activities[index];
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(a.action),
                    subtitle: Text(a.details ?? ''),
                    trailing: Text(
                      a.timestamp.toLocal().toString().split('.').first,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
