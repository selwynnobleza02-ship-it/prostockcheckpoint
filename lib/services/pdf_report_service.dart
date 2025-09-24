import 'dart:io';

import 'package:flutter/foundation.dart';
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

class PdfCalculationSection {
  final String title;
  final String formula;
  final String result;

  PdfCalculationSection({
    required this.title,
    required this.formula,
    required this.result,
  });
}

class PdfSummarySection {
  final String title;
  final String value;

  PdfSummarySection({required this.title, required this.value});
}

class PdfReportService {
  Future<File> generateFinancialReport({
    required String reportTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<PdfReportSection> sections,
    List<PdfCalculationSection>? calculations,
    List<PdfSummarySection>? summaries,
  }) async {
    try {
      print('PDF Service: Starting PDF generation...');
      print('PDF Service: Report title: $reportTitle');
      print('PDF Service: Sections count: ${sections.length}');
      print('PDF Service: Calculations count: ${calculations?.length ?? 0}');
      print('PDF Service: Summaries count: ${summaries?.length ?? 0}');

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
            if (calculations != null)
              ...calculations.map((c) => _buildCalculation(c)),
            if (summaries != null) ...summaries.map((s) => _buildSummary(s)),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],
        ),
      );

      print('PDF Service: Building document structure...');

      // Try to get Downloads directory, fallback to external storage if not available
      Directory? dir;
      try {
        print('PDF Service: Getting storage directory...');
        if (!kIsWeb && Platform.isAndroid) {
          // For Android, try to get the Downloads directory
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            print(
              'PDF Service: Downloads directory not found, trying external storage...',
            );
            // Fallback to external storage directory
            dir = await getExternalStorageDirectory();
            if (dir != null) {
              dir = Directory('${dir.path}/Download');
              if (!await dir.exists()) {
                print('PDF Service: Creating Download directory...');
                await dir.create(recursive: true);
              }
            }
          }
        } else {
          // For iOS, web, and other platforms, use application documents directory
          print('PDF Service: Using application documents directory...');
          dir = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        print('PDF Service: Error getting storage directory: $e');
        // Fallback to application documents directory if all else fails
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception('Could not access storage directory');
      }

      print('PDF Service: Storage directory: ${dir.path}');

      final fileName =
          'financial_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(p.join(dir.path, fileName));

      print('PDF Service: Saving PDF to: ${file.path}');

      final pdfBytes = await doc.save();
      print('PDF Service: PDF generated, size: ${pdfBytes.length} bytes');

      await file.writeAsBytes(pdfBytes);
      print('PDF Service: PDF saved successfully');

      return file;
    } catch (e) {
      print('PDF Service: Error generating PDF: $e');
      rethrow;
    }
  }

  pw.Widget _buildSection(PdfReportSection section) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section title with numbering
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(
              section.title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 8),

          // Table with clean formatting
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      _getHeaderText(section.title),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Amount',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              // Data rows
              for (int i = 0; i < section.rows.length; i++)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        section.rows[i][0],
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        _stripCurrencySymbols(section.rows[i][1]),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight:
                              _isTotalRow(section.rows[i][0]) ||
                                  _isNumericValue(section.rows[i][1])
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getHeaderText(String sectionTitle) {
    if (sectionTitle.toLowerCase().contains('income')) return 'Source';
    if (sectionTitle.toLowerCase().contains('cogs') ||
        sectionTitle.toLowerCase().contains('cost')) {
      return 'Item Category';
    }
    if (sectionTitle.toLowerCase().contains('expense')) return 'Expense Item';
    if (sectionTitle.toLowerCase().contains('cash flow')) return 'Description';
    return 'Description';
  }

  bool _isTotalRow(String text) {
    return text.toLowerCase().contains('total') ||
        text.toLowerCase().contains('net profit') ||
        text.toLowerCase().contains('gross profit');
  }

  pw.Widget _buildCalculation(PdfCalculationSection calculation) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section title
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(
              calculation.title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 8),

          // Calculation formula
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Text(
              calculation.formula,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummary(PdfSummarySection summary) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            summary.title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            _stripCurrencySymbols(summary.value),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _stripCurrencySymbols(String value) {
    // Remove common currency symbols that may not be supported by the PDF font
    final withoutSymbols = value.replaceAll(RegExp(r'[₱$€£¥₹]'), '');
    // Also trim extra whitespace that may be left over
    return withoutSymbols.trim();
  }

  bool _isNumericValue(String value) {
    // Check if the value looks like a currency amount or percentage
    return value.contains('₱') ||
        value.contains('%') ||
        value.contains('x') ||
        RegExp(r'^\d+\.?\d*$').hasMatch(value.replaceAll(',', ''));
  }
}
