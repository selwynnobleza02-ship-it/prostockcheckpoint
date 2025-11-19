import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/services/pdf_report_service.dart';
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
                  // First, ask user which export method they prefer
                  if (!context.mounted) return;
                  final exportMethod = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Choose Export Method'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How would you like to export your staff report?',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.article,
                              color: Colors.blue,
                            ),
                            title: const Text('Single PDF (Limited)'),
                            subtitle: const Text(
                              'One PDF with limited entries per section',
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () => Navigator.pop(context, 'single'),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.library_books,
                              color: Colors.green,
                            ),
                            title: const Text('Separate PDFs (Complete)'),
                            subtitle: const Text(
                              'One PDF per section with ALL entries',
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () => Navigator.pop(context, 'separate'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );

                  if (exportMethod == null || !context.mounted) return;

                  final scaffold = ScaffoldMessenger.of(context);

                  // Show loading indicator
                  scaffold.showSnackBar(
                    const SnackBar(
                      content: Text('Generating PDF...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  final activities = await _activityStream.first;

                  // Validate we have data to export
                  if (activities.isEmpty) {
                    scaffold.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No staff activity data available to export.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }

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

                  // For Separate PDFs, use original sections - system auto-splits large sections
                  List<PdfReportSection> filteredSections = sections;

                  try {
                    // Show progress dialog
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              exportMethod == 'separate'
                                  ? 'Generating ${sections.length} PDF files...\nPlease wait.'
                                  : 'Generating PDF...\nPlease wait.',
                            ),
                          ],
                        ),
                      ),
                    );

                    // Generate PDFs based on chosen method
                    if (exportMethod == 'separate') {
                      // Generate one PDF per section with ALL data
                      final files = await pdf.generatePdfPerSection(
                        reportTitle:
                            'Staff Performance Report - Sari-Sari Store',
                        startDate: null,
                        endDate: null,
                        sections:
                            sections, // Use original sections without limits
                      );

                      // Close progress dialog
                      if (!context.mounted) return;
                      Navigator.of(context).pop();

                      if (!context.mounted) return;
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${files.length} PDF files saved to Downloads folder',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }

                    // Generate single PDF with limited data
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
                      if (!context.mounted) return;
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
                        content: Text(
                          'Error generating PDF: ${e.toString().length > 100 ? e.toString().substring(0, 100) + '...' : e.toString()}',
                        ),
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
