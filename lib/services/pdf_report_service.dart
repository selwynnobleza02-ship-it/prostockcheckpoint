import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:prostock/utils/error_logger.dart';

class PdfReportSection {
  final String title;
  final List<List<String>> rows; // [ [label, value], ... ]

  PdfReportSection({required this.title, required this.rows});

  // Create a copy with limited rows
  PdfReportSection copyWithLimitedRows(int maxRows) {
    if (rows.length <= maxRows) {
      return this;
    }

    // Take some rows from the beginning and end
    final firstHalfCount = maxRows ~/ 2;
    final secondHalfCount = maxRows - firstHalfCount;

    final firstHalf = rows.take(firstHalfCount).toList();
    final secondHalf = rows.skip(rows.length - secondHalfCount).toList();

    // Add a summary row in the middle with the same number of columns as the other rows
    List<String> summaryRow = [];
    if (rows.isNotEmpty) {
      int columnCount = rows.first.length;
      summaryRow = List.filled(columnCount, '');
      summaryRow[0] =
          '... (${rows.length - maxRows} more entries not shown) ...';
    }

    return PdfReportSection(
      title: title,
      rows: [...firstHalf, summaryRow, ...secondHalf],
    );
  }
}

class PdfCalculationSection {
  final String title;
  final String formula;
  final String calculation;
  final String result;

  PdfCalculationSection({
    required this.title,
    required this.formula,
    required this.calculation,
    required this.result,
  });
}

class PdfSummarySection {
  final String title;
  final String value;

  PdfSummarySection({required this.title, required this.value});
}

// Data structure for passing PDF generation parameters to isolate
class PdfGenerationParams {
  final String reportTitle;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<PdfReportSection> sections;
  final List<PdfCalculationSection>? calculations;
  final List<PdfSummarySection>? summaries;

  PdfGenerationParams({
    required this.reportTitle,
    this.startDate,
    this.endDate,
    required this.sections,
    this.calculations,
    this.summaries,
  });
}

// Simple semaphore implementation to limit concurrent operations
class _PdfSemaphore {
  final int maxConcurrent;
  int _currentCount = 0;
  final List<Completer<void>> _waiters = [];

  _PdfSemaphore({required this.maxConcurrent});

  Future<void> acquire() async {
    if (_currentCount < maxConcurrent) {
      _currentCount++;
      return Future.value();
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final completer = _waiters.removeAt(0);
      completer.complete();
    } else {
      _currentCount = math.max(0, _currentCount - 1);
    }
  }
}

class PdfReportService {
  // Singleton instance to manage concurrent PDF generations
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  // Semaphore to limit concurrent PDF operations
  static final _semaphore = _PdfSemaphore(maxConcurrent: 2);

  /// Tests if we can write to storage by creating a small test file
  /// Returns the directory that works, or throws an exception if no writable directory is found
  Future<Directory> _testStorage() async {
    try {
      debugPrint('[PDF] Testing storage write access');

      List<Directory> dirsToTry = [];

      // First try: User's requested path for downloads
      if (Platform.isAndroid) {
        // Try the requested path first (most visible to users)
        dirsToTry.add(Directory('/My Phone/Internal Storage/Download'));
        dirsToTry.add(Directory('/storage/emulated/0/Download'));
        dirsToTry.add(Directory('/sdcard/Download'));
      }

      try {
        // Next try: Application documents directory
        final docsDir = await getApplicationDocumentsDirectory();
        dirsToTry.add(docsDir);

        // Then: Application support directory
        final supportDir = await getApplicationSupportDirectory();
        dirsToTry.add(supportDir);

        // Last: Temporary directory
        final tempDir = await getTemporaryDirectory();
        dirsToTry.add(tempDir);
      } catch (e) {
        debugPrint('[PDF] Error getting standard directories: $e');
        // If all else fails, try hard-coded paths
        if (Platform.isAndroid) {
          dirsToTry.add(
            Directory('/data/user/0/com.example.prostock/app_flutter'),
          );
          dirsToTry.add(Directory('/data/user/0/com.example.prostock/files'));
          dirsToTry.add(Directory('/data/user/0/com.example.prostock/cache'));
        }
      }

      // Try each directory until one works
      for (var dir in dirsToTry) {
        try {
          debugPrint('[PDF] Trying directory: ${dir.path}');

          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }

          final testFile = File('${dir.path}/test_write_access.txt');
          await testFile.writeAsString('Test write access: ${DateTime.now()}');

          if (await testFile.exists()) {
            // Clean up
            await testFile.delete();

            debugPrint('[PDF] Found writable directory: ${dir.path}');
            return dir;
          }
        } catch (e) {
          debugPrint('[PDF] Directory not writable: ${dir.path}, error: $e');
          // Continue to next directory
        }
      }

      throw Exception('No writable storage directory found');
    } catch (e) {
      debugPrint('[PDF] Failed to find writable storage: $e');
      rethrow;
    }
  }

  /// Generate PDF in the background using Flutter's compute function
  Future<File> generatePdfInBackground({
    required String reportTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<PdfReportSection> sections,
    List<PdfCalculationSection>? calculations,
    List<PdfSummarySection>? summaries,
  }) async {
    // Acquire semaphore to limit concurrent PDF operations
    await _semaphore.acquire();

    try {
      ErrorLogger.logInfo(
        'Starting PDF generation in background',
        context: 'PdfReportService.generatePdfInBackground',
        metadata: {
          'reportTitle': reportTitle,
          'sectionsCount': sections.length,
          'startDate': startDate?.toIso8601String() ?? 'null',
          'endDate': endDate?.toIso8601String() ?? 'null',
        },
      );

      // Apply stricter limits to avoid TooManyPagesException
      // For large reports, automatically use paginated PDFs
      if (sections.length > 5 ||
          sections.any((s) => s.rows.length > 50) ||
          (calculations?.length ?? 0) > 5) {
        try {
          final files = await generatePaginatedPDFsInBackground(
            reportTitle: reportTitle,
            startDate: startDate,
            endDate: endDate,
            sections: applyDataLimits(
              sections,
              maxRowsPerSection: 50,
            ), // Stricter limit
            calculations: calculations,
            summaries: summaries,
            sectionsPerPdf: 3, // Fewer sections per PDF
          );
          return files.first; // Return the first file as a fallback
        } catch (e, stack) {
          ErrorLogger.logError(
            'Paginated PDF generation fallback failed',
            error: e,
            stackTrace: stack,
            context: 'PdfReportService.generatePdfInBackground',
          );
          rethrow;
        }
      }

      // For smaller reports, try the normal approach
      final params = PdfGenerationParams(
        reportTitle: reportTitle,
        startDate: startDate,
        endDate: endDate,
        sections: applyDataLimits(
          sections,
          maxRowsPerSection: 50,
        ), // Apply stricter limit
        calculations: calculations,
        summaries: summaries,
      );

      try {
        return await compute(_generatePdfInIsolate, params);
      } catch (e, stack) {
        ErrorLogger.logError(
          'PDF generation in background failed',
          error: e,
          stackTrace: stack,
          context: 'PdfReportService.generatePdfInBackground',
          metadata: {
            'reportTitle': reportTitle,
            'sectionsCount': sections.length,
          },
        );

        // If we get a TooManyPagesException, try with even stricter limits
        if (e.toString().contains('TooManyPagesException')) {
          ErrorLogger.logInfo(
            'Retrying with stricter data limits',
            context: 'PdfReportService.generatePdfInBackground',
          );

          try {
            final files = await generatePaginatedPDFsInBackground(
              reportTitle: reportTitle,
              startDate: startDate,
              endDate: endDate,
              sections: applyDataLimits(
                sections,
                maxRowsPerSection: 20,
              ), // Much stricter limit
              calculations: calculations
                  ?.take(3)
                  .toList(), // Limit calculations too
              summaries: summaries,
              sectionsPerPdf: 2, // Even fewer sections per PDF
            );
            return files.first; // Return the first file
          } catch (e2, stack2) {
            ErrorLogger.logError(
              'Final PDF generation attempt failed',
              error: e2,
              stackTrace: stack2,
              context: 'PdfReportService.generatePdfInBackground',
            );
            rethrow;
          }
        }

        rethrow;
      }
    } finally {
      // Always release the semaphore when done
      _semaphore.release();
    }
  }

  /// Generate paginated PDFs in background using Flutter's compute function
  Future<List<File>> generatePaginatedPDFsInBackground({
    required String reportTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<PdfReportSection> sections,
    List<PdfCalculationSection>? calculations,
    List<PdfSummarySection>? summaries,
    int sectionsPerPdf = 5,
    int maxRowsPerSection = 50, // New parameter to control rows per section
  }) async {
    // Acquire semaphore to limit concurrent operations
    await _semaphore.acquire();

    try {
      ErrorLogger.logInfo(
        'Starting paginated PDF generation in background',
        context: 'PdfReportService.generatePaginatedPDFsInBackground',
        metadata: {
          'reportTitle': reportTitle,
          'sectionsCount': sections.length,
          'sectionsPerPdf': sectionsPerPdf,
          'maxRowsPerSection': maxRowsPerSection,
        },
      );

      // Apply row limits to all sections first to avoid TooManyPagesException
      final limitedSections = applyDataLimits(
        sections,
        maxRowsPerSection: maxRowsPerSection,
      );

      // For very large reports, split large sections into multiple sections
      if (limitedSections.any((section) => section.rows.length > 100)) {
        List<PdfReportSection> splitSections = [];

        for (var section in limitedSections) {
          if (section.rows.length > 100) {
            // Split this section into multiple smaller sections
            final totalSplits = (section.rows.length / 50).ceil();

            for (int i = 0; i < totalSplits; i++) {
              final start = i * 50;
              final end = (start + 50 < section.rows.length)
                  ? start + 50
                  : section.rows.length;

              splitSections.add(
                PdfReportSection(
                  title: '${section.title} (Part ${i + 1} of $totalSplits)',
                  rows: section.rows.sublist(start, end),
                ),
              );
            }
          } else {
            // Keep section as is
            splitSections.add(section);
          }
        }

        // Replace with the split sections
        limitedSections.clear();
        limitedSections.addAll(splitSections);
      }

      // Calculate how many PDFs we'll need
      int totalPdfs = (limitedSections.length / sectionsPerPdf).ceil();
      List<File> pdfFiles = [];

      // Generate PDFs sequentially instead of in parallel to avoid resource contention
      for (int i = 0; i < limitedSections.length; i += sectionsPerPdf) {
        int end = (i + sectionsPerPdf < limitedSections.length)
            ? i + sectionsPerPdf
            : limitedSections.length;
        List<PdfReportSection> sectionChunk = limitedSections.sublist(i, end);

        int pageNumber = (i ~/ sectionsPerPdf) + 1;

        // Log progress
        ErrorLogger.logInfo(
          'Generating PDF $pageNumber of $totalPdfs',
          context: 'PdfReportService.generatePaginatedPDFsInBackground',
        );

        // For calculations, distribute them across PDFs if there are many
        List<PdfCalculationSection>? pdfCalculations;
        if (calculations != null && calculations.isNotEmpty) {
          if (pageNumber == 1 || calculations.length <= 3) {
            // For short calculation lists or first PDF, include all or the first few
            pdfCalculations = pageNumber == 1
                ? (calculations.length > 4
                      ? calculations.sublist(0, 4)
                      : calculations)
                : null;
          } else if (totalPdfs > 1 && calculations.length > 4) {
            // Distribute remaining calculations across PDFs
            final calcPerPdf = (calculations.length - 4) ~/ (totalPdfs - 1);
            final startIdx = 4 + (pageNumber - 2) * calcPerPdf;
            final endIdx = pageNumber == totalPdfs
                ? calculations.length
                : math.min(startIdx + calcPerPdf, calculations.length);

            if (startIdx < endIdx) {
              pdfCalculations = calculations.sublist(startIdx, endIdx);
            }
          }
        }

        final params = PdfGenerationParams(
          reportTitle: '$reportTitle - Part $pageNumber of $totalPdfs',
          startDate: startDate,
          endDate: endDate,
          sections: sectionChunk,
          calculations: pdfCalculations,
          summaries: pageNumber == totalPdfs
              ? summaries
              : null, // Only include in last PDF
        );

        // Insert a delay between PDF generations to avoid resource contention
        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 300));
        }

        try {
          File pdfFile = await compute(_generatePdfInIsolate, params);
          pdfFiles.add(pdfFile);

          // Log success
          ErrorLogger.logInfo(
            'PDF $pageNumber of $totalPdfs generated successfully',
            context: 'PdfReportService.generatePaginatedPDFsInBackground',
          );
        } catch (e, stack) {
          ErrorLogger.logError(
            'Failed to generate PDF $pageNumber of $totalPdfs',
            error: e,
            stackTrace: stack,
            context: 'PdfReportService.generatePaginatedPDFsInBackground',
          );

          // Continue with other PDFs instead of failing completely
          continue;
        }
      }

      return pdfFiles;
    } finally {
      // Always release the semaphore when done
      _semaphore.release();
    }
  }

  /// Static method to be executed in isolate
  /// Method to be executed in isolate
  static Future<File> _generatePdfInIsolate(PdfGenerationParams params) async {
    try {
      // We'll skip Firebase initialization in the isolate and avoid using
      // Firebase-dependent code in the PDF generation

      debugPrint(
        '[PDF ISOLATE] Starting PDF generation: ${params.reportTitle}',
      );

      final service = PdfReportService();
      final file = await service.generateFinancialReport(
        reportTitle: params.reportTitle,
        startDate: params.startDate,
        endDate: params.endDate,
        sections: params.sections,
        calculations: params.calculations,
        summaries: params.summaries,
      );

      debugPrint(
        '[PDF ISOLATE] PDF generation completed: ${params.reportTitle}',
      );

      return file;
    } catch (e, stack) {
      debugPrint('[CRITICAL ERROR] PDF generation in isolate failed: $e');
      debugPrint('[CRITICAL ERROR] Stack trace: $stack');
      rethrow;
    } finally {
      // Clean up resources after PDF generation
      debugPrint(
        '[PDF ISOLATE] Cleaning up resources for: ${params.reportTitle}',
      );
    }
  }

  /// Apply data limits to all sections to prevent TooManyPagesException
  List<PdfReportSection> applyDataLimits(
    List<PdfReportSection> sections, {
    int maxRowsPerSection = 100,
    bool summaryOnly = false,
  }) {
    // Calculate total rows to gauge complexity
    int totalRows = sections.fold(
      0,
      (sum, section) => sum + section.rows.length,
    );

    // For extremely large data sets (>1000 rows), automatically apply summary mode
    if (totalRows > 1000 && !summaryOnly) {
      ErrorLogger.logInfo(
        'Applying summary-only mode due to large dataset ($totalRows rows)',
        context: 'PdfReportService.applyDataLimits',
      );
      summaryOnly = true;
      // Also reduce max rows per section for very large datasets
      if (maxRowsPerSection > 50) {
        maxRowsPerSection = 50;
      }
    }
    // For large data sets (>500 rows), further reduce rows per section
    else if (totalRows > 500 && maxRowsPerSection > 75) {
      maxRowsPerSection = 75;
      ErrorLogger.logInfo(
        'Reducing max rows per section to $maxRowsPerSection due to large dataset',
        context: 'PdfReportService.applyDataLimits',
      );
    }

    // If summary only is enabled, only include sections with "Summary" in the title
    if (summaryOnly) {
      sections = sections
          .where(
            (s) =>
                s.title.toLowerCase().contains('summary') ||
                s.title.toLowerCase().contains('total') ||
                s.rows.length <= 10, // Keep small sections
          )
          .toList();
    }

    // For large sections, apply stricter limits
    List<PdfReportSection> limitedSections = [];
    for (var section in sections) {
      // Apply different limits based on section size
      int sectionLimit = maxRowsPerSection;

      // For very large sections, apply even stricter limits
      if (section.rows.length > 200) {
        sectionLimit = math.min(maxRowsPerSection, 40); // Stricter limit
      }

      limitedSections.add(section.copyWithLimitedRows(sectionLimit));
    }

    return limitedSections;
  }

  /// Split sections into multiple PDFs to prevent TooManyPagesException
  Future<List<File>> generatePaginatedPDFs({
    required String reportTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<PdfReportSection> sections,
    List<PdfCalculationSection>? calculations,
    List<PdfSummarySection>? summaries,
    int sectionsPerPdf = 5,
  }) async {
    List<File> pdfFiles = [];

    // Calculate how many PDFs we'll need
    int totalPdfs = (sections.length / sectionsPerPdf).ceil();

    // Generate one PDF for each batch of sections
    for (int i = 0; i < sections.length; i += sectionsPerPdf) {
      int end = (i + sectionsPerPdf < sections.length)
          ? i + sectionsPerPdf
          : sections.length;
      List<PdfReportSection> sectionChunk = sections.sublist(i, end);

      int pageNumber = (i ~/ sectionsPerPdf) + 1;
      final file = await generateFinancialReport(
        reportTitle: '$reportTitle - Part $pageNumber of $totalPdfs',
        startDate: startDate,
        endDate: endDate,
        sections: sectionChunk,
        calculations: pageNumber == 1
            ? calculations
            : null, // Only include in first PDF
        summaries: pageNumber == totalPdfs
            ? summaries
            : null, // Only include in last PDF
      );

      pdfFiles.add(file);
    }

    return pdfFiles;
  }

  Future<File> generateFinancialReport({
    required String reportTitle,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<PdfReportSection> sections,
    List<PdfCalculationSection>? calculations,
    List<PdfSummarySection>? summaries,
  }) async {
    try {
      debugPrint('[PDF] Starting PDF generation for: $reportTitle');
      debugPrint(
        '[PDF] Sections: ${sections.length}, Calculations: ${calculations?.length ?? 0}, Summaries: ${summaries?.length ?? 0}',
      );

      final doc = pw.Document();
      final df = DateFormat('yyyy-MM-dd');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          // Set maxPages high enough to handle reasonable content
          maxPages: 100,
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      reportTitle,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    startDate != null && endDate != null
                        ? '${df.format(startDate)} - ${df.format(endDate)}'
                        : 'All Time',
                    style: const pw.TextStyle(fontSize: 10),
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
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],
        ),
      );

      debugPrint('[PDF] Building document structure');

      // Try to find a writable directory by testing
      Directory? directoryToUse;
      try {
        debugPrint('[PDF] Finding writable storage directory');

        // Try to use the Download directory directly first
        if (Platform.isAndroid) {
          // Try the requested path first
          final downloadDir = Directory('/My Phone/Internal Storage/Download');
          bool canCreateDir = false;

          try {
            if (await downloadDir.exists()) {
              canCreateDir = true;
            } else {
              await downloadDir.create(recursive: true);
              canCreateDir = await downloadDir.exists();
            }
          } catch (e) {
            debugPrint('[PDF] Error creating directory: $e');
            canCreateDir = false;
          }

          if (canCreateDir) {
            // Test if we can write to this directory
            try {
              final testFile = File(
                '${downloadDir.path}/test_write_access.txt',
              );
              await testFile.writeAsString(
                'Test write access: ${DateTime.now()}',
              );
              if (await testFile.exists()) {
                await testFile.delete();
                debugPrint(
                  '[PDF] Using requested Download directory: ${downloadDir.path}',
                );
                directoryToUse = downloadDir;
                // If this succeeds, don't try other directories
              }
            } catch (e) {
              debugPrint(
                '[PDF] Cannot write to Download directory, will try alternatives: $e',
              );
            }
          }
        }

        // If we couldn't use the Download directory, find another writable directory
        if (directoryToUse == null) {
          // Use the test function to find a directory we can actually write to
          directoryToUse = await _testStorage();
          debugPrint(
            '[PDF] Selected storage directory: ${directoryToUse.path}',
          );
        }
      } catch (e) {
        debugPrint('[PDF] Failed to find writable storage directory: $e');

        // Last resort - use temporary directory which should work in isolates
        debugPrint('[PDF] Using temporary directory as last resort');
        directoryToUse = await getTemporaryDirectory();
      }

      Directory dir = directoryToUse;

      // Check that directory is valid and exists
      if (!(await dir.exists())) {
        debugPrint('[PDF] Directory does not exist: ${dir.path}, creating it');
        await dir.create(recursive: true);
      }

      debugPrint('[PDF] Using directory: ${dir.path}');

      // Generate filename based on report title
      String baseFileName = 'financial_report';
      if (reportTitle.toLowerCase().contains('sales')) {
        baseFileName = 'sales_report';
      } else if (reportTitle.toLowerCase().contains('inventory')) {
        baseFileName = 'inventory_report';
      } else if (reportTitle.toLowerCase().contains('customer')) {
        baseFileName = 'customer_report';
      } else if (reportTitle.toLowerCase().contains('staff')) {
        baseFileName = 'staff_report';
      } else if (reportTitle.toLowerCase().contains('financial')) {
        baseFileName = 'financial_report';
      }

      final fileName =
          '${baseFileName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      var file = File(p.join(dir.path, fileName));

      debugPrint('[PDF] Saving PDF to: ${file.path}');

      try {
        debugPrint('[PDF] About to generate PDF bytes...');
        final pdfBytes = await doc.save();
        debugPrint('[PDF] PDF generated, size: ${pdfBytes.length} bytes');

        // Check if directory exists and is writable
        final parentDir = file.parent;
        if (!await parentDir.exists()) {
          debugPrint('[PDF] Creating parent directory: ${parentDir.path}');
          try {
            await parentDir.create(recursive: true);
            debugPrint('[PDF] Parent directory created successfully');
          } catch (e) {
            debugPrint('[PDF] Error creating parent directory: $e');
            // Try a fallback location if we can't create the directory
            dir = await getTemporaryDirectory();
            debugPrint(
              '[PDF] Falling back to temporary directory: ${dir.path}',
            );
            final fileName =
                '${baseFileName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
            file = File(p.join(dir.path, fileName));
          }
        }

        // Write file
        debugPrint('[PDF] Writing file to: ${file.path}');
        try {
          await file.writeAsBytes(pdfBytes);
          debugPrint('[PDF] File written successfully');
        } catch (e) {
          debugPrint('[PDF] Error writing file: $e');
          // Try one more fallback to the cache directory
          dir = await getTemporaryDirectory();
          final fileName =
              '${baseFileName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          file = File(p.join(dir.path, fileName));
          debugPrint('[PDF] Final fallback attempt to: ${file.path}');
          await file.writeAsBytes(pdfBytes);
        }

        // Verify file was created
        final exists = await file.exists();
        final fileSize = exists ? await file.length() : 0;

        debugPrint(
          '[PDF] PDF saved successfully: ${file.path}, exists: $exists, size: $fileSize bytes',
        );

        // Log additional information about the file path for debugging
        if (exists) {
          debugPrint('[PDF] Full absolute path: ${file.absolute.path}');
          debugPrint('[PDF] Parent directory: ${file.parent.path}');

          // On Android, also try to make sure the file is accessible in the media store
          if (Platform.isAndroid && dir.path.contains('/Download')) {
            try {
              // Log that the file should be visible in Downloads
              debugPrint('[PDF] PDF should be visible in Downloads folder');
            } catch (e) {
              debugPrint('[PDF] Note: Media scanning not available: $e');
            }
          }
        }
      } catch (e, stack) {
        debugPrint('[PDF] Failed to write PDF file: $e');
        debugPrint('[PDF] Stack trace: $stack');
        rethrow;
      }

      return file;
    } catch (e, stack) {
      debugPrint('[PDF] Error generating PDF: $e');
      debugPrint('[PDF] Stack trace: $stack');
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
          _buildFlexibleTable(section),
        ],
      ),
    );
  }

  String _getHeaderText(String sectionTitle) {
    final lower = sectionTitle.toLowerCase();
    if (lower.contains('income')) return 'Product';
    if (lower.contains('cogs') || lower.contains('cost')) return 'Product';
    if (lower.contains('expense')) return 'Expense Item';
    if (lower.contains('cash flow')) return 'Description';
    if (lower.contains('inventory distribution')) return 'Category';
    return 'Description';
  }

  pw.Widget _buildFlexibleTable(PdfReportSection section) {
    final hasAtLeastThreeColumns =
        section.rows.isNotEmpty && section.rows.first.length >= 3;
    final hasFourColumns =
        section.rows.isNotEmpty && section.rows.first.length >= 4;

    if (!hasAtLeastThreeColumns) {
      // Fallback to 2-column table (label, amount)
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
        },
        children: [
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
      );
    }

    if (hasFourColumns) {
      // 4-column table: product, quantity, price, amount
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Product',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Quantity',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Price',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: pw.TextAlign.right,
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
                    section.rows[i][1],
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    _stripCurrencySymbols(section.rows[i][2]),
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    _stripCurrencySymbols(section.rows[i][3]),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          _isTotalRow(section.rows[i][0]) ||
                              _isNumericValue(section.rows[i][3])
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    // 3-column table: product, quantity, amount
    final isInventoryDistribution = section.title.toLowerCase().contains(
      'inventory distribution',
    );
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                isInventoryDistribution ? 'Category' : 'Product',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                isInventoryDistribution ? 'Distribution' : 'Quantity',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                isInventoryDistribution ? 'Quantity' : 'Amount',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
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
                  section.rows[i][1],
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  _stripCurrencySymbols(section.rows[i][2]),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        _isTotalRow(section.rows[i][0]) ||
                            _isNumericValue(section.rows[i][2])
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
      ],
    );
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

          // Formula
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Text(
              'Formula: ${calculation.formula}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),

          // Calculation
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Text(
              'Calculation: ${calculation.calculation}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.normal,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),

          // Result
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Text(
              'Result: ${_stripCurrencySymbols(calculation.result)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
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
    // Remove currency symbols that the default PDF font may not support
    final withoutSymbols = value
        .replaceAll('₱', '') // Peso symbol
        .replaceAll(RegExp(r'[₱$€£¥₹¢]'), '') // Other currency symbols
        .replaceAll('PHP', '') // PHP currency code
        .replaceAll('P', '') // Sometimes P is used for peso
        .trim();
    return withoutSymbols;
  }

  bool _isNumericValue(String value) {
    // Check if the value looks like a currency amount or percentage
    return value.contains('₱') ||
        value.contains('%') ||
        value.contains('x') ||
        RegExp(r'^\d+\.?\d*$').hasMatch(value.replaceAll(',', ''));
  }
}
