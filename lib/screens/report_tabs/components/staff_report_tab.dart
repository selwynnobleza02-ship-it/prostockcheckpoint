import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prostock/providers/auth_provider.dart';
import 'package:prostock/services/firestore/activity_service.dart';
import 'package:prostock/models/user_activity.dart';
import 'package:prostock/services/pdf_report_service.dart';

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
                final scaffold = ScaffoldMessenger.of(context);
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('Generating PDF...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
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
                  final file = await pdf.generateFinancialReport(
                    reportTitle: 'Staff Performance Report - Sari-Sari Store',
                    startDate: null,
                    endDate: null,
                    sections: sections,
                  );

                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('PDF saved: ${file.path}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error generating PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
