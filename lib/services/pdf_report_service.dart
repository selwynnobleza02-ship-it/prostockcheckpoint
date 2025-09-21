import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportSection {
  final String title;
  final List<List<String>> rows; // [ [label, value], ... ]

  PdfReportSection({required this.title, required this.rows});
}

class PdfReportService {
  Future<File> generateFinancialReport({
    required String reportTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<PdfReportSection> sections,
  }) async {
    final doc = pw.Document();
    final df = DateFormat('yyyy-MM-dd');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  startDate != null && endDate != null
                      ? '${df.format(startDate)} - ${df.format(endDate)}'
                      : 'All Time',
                ),
              ],
            ),
          ),
          ...sections.map((s) => _buildSection(s)),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        dir.path,
        'financial_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _buildSection(PdfReportSection section) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            section.title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              for (final row in section.rows)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[0]),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[1], textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
