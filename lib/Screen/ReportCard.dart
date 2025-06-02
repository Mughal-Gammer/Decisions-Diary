import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/Model class new.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  DateTimeRange? _selectedDateRange;
  List<Decision> _decisions = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decision Reports'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                :  Icon(Icons.picture_as_pdf),
                    onPressed: _isLoading ? null : _generatePdfReport,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickSelectionButtons(),
            const SizedBox(height: 20),
            _buildDateRangePicker(),
            const SizedBox(height: 20),
            if (_selectedDateRange != null) ...[
              _buildDateRangeSummary(),

            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSelectionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Select:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectLast7Days(),
                child: const Text('Last 7 Days'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectLastMonth(),
                child: const Text('Last Month'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Date Range:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SfDateRangePicker(
              selectionMode: DateRangePickerSelectionMode.range,
              onSelectionChanged: _onSelectionChanged,
              initialSelectedRange: _selectedDateRange != null
                  ? PickerDateRange(
                _selectedDateRange!.start,
                _selectedDateRange!.end,
              )
                  : null,
              maxDate: DateTime.now(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSummary() {
    if (_selectedDateRange == null) return const SizedBox();

    final startDate = _selectedDateRange!.start;
    final endDate = _selectedDateRange!.end;
    final days = endDate.difference(startDate).inDays + 1;
    final decisionCount = _decisions.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'From: ${DateFormat('MMM d, yyyy').format(startDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'To: ${DateFormat('MMM d, yyyy').format(endDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Period: $days days',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Decisions: $decisionCount',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }


  void _onSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value is PickerDateRange) {
      final range = args.value as PickerDateRange;
      if (range.startDate != null && range.endDate != null) {
        setState(() {
          _selectedDateRange = DateTimeRange(
            start: range.startDate!,
            end: range.endDate!,
          );
        });
        _fetchDecisionsForRange();
      }
    }
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: now.subtract(const Duration(days: (7-1) * 1 )),
        end: now,
      );
    });
    _fetchDecisionsForRange();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: now.subtract(const Duration(days: (30-1) * 1 )),
        end: now,
      );
    });
    _fetchDecisionsForRange();
  }

  Future<void> _fetchDecisionsForRange() async {
    if (_selectedDateRange == null) return;

    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _dbRef.child('users/${user.uid}/decisions').get();
      if (snapshot.exists) {
        final decisionsMap = snapshot.value as Map<dynamic, dynamic>;
        final allDecisions = decisionsMap.entries.map((entry) {
          return Decision.fromMap(
            Map<String, dynamic>.from(entry.value),
            entry.key,
          );
        }).toList();

        setState(() {
          _decisions = allDecisions.where((decision) {
            return decision.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                decision.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching decisions: $e')),
      );
    }
  }

  Future<void> _generatePdfReport() async {
    if (_selectedDateRange == null || _decisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No decisions found in the selected date range.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdf = pw.Document();

      // 1. Cover Page with better styling
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [

                pw.Center(
                  child: pw.Text(
                    'Decision Report',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Period: ${DateFormat('MMMM d, yyyy').format(_selectedDateRange!.start)} to ${DateFormat('MMMM d, yyyy').format(_selectedDateRange!.end)}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Total Decisions: ${_decisions.length}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),

              ],
            );

          },
        ),
      );

      // 2. Summary Page with improved layout
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            final completed = _decisions.where((d) => d.finalOutcome?.isNotEmpty == true).length;
            final pending = _decisions.length - completed;

            return
              pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Report Summary',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Total Decisions', _decisions.length.toString(), PdfColors.blue100),
                    _buildStatCard('Completed', completed.toString(), PdfColors.green100),
                    _buildStatCard('Pending', pending.toString(), PdfColors.orange100),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Date Range: ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Days Covered: ${_selectedDateRange!.end.difference(_selectedDateRange!.start).inDays + 1}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            );
          },
        ),
      );

      // 3. Detailed Decisions List with proper table formatting
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Decision Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              headers: ['Date', 'Title', 'Status', 'Outcome'],
              data: _decisions.map((decision) {
                return [
                  DateFormat('MMM d, yyyy').format(decision.date),
                  decision.title,
                  decision.finalOutcome?.isNotEmpty == true ? 'Completed' : 'Pending',
                  decision.finalOutcome ?? decision.expectedOutcome ?? 'N/A',
                ];
              }).toList(),
            ),
          ],
        ),
      );

      // Save to a temporary file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/decision_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share the PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Decision Report - ${DateFormat('MMM yyyy').format(DateTime.now())}',
        text: 'Attached is your decision report for the selected period.',
      );

      // Try printing if sharing succeeds
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) => pdf.save(),
        );
      } catch (e) {
        debugPrint('Printing failed: $e');
        // Fallback to just opening the file
        await OpenFile.open(file.path);
      }

    } catch (e, stack) {
      debugPrint('Error generating PDF: $e');
      debugPrint('Stack trace: $stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  pw.Container _buildStatCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      height: 80,
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 2,

          ),
        ],
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              title,
              style:  pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ],
        ),
      ),
    );
  }









}