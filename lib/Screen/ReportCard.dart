import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _decisions = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decision Reports'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.save),
            onPressed: _isLoading || _isSaving || _isSharing ? null : _savePdfReport,
            tooltip: 'Save PDF',
          ),
          IconButton(
            icon: _isSharing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.share),
            onPressed: _isLoading || _isSaving || _isSharing ? null : _sharePdfReport,
            tooltip: 'Share PDF',
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
            if (_selectedDateRange != null) _buildDateRangeSummary(),
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
                onPressed: _selectLast7Days,
                child: const Text('Last 7 Days'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _selectLastMonth,
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
    final startDate = _selectedDateRange!.start;
    final endDate = _selectedDateRange!.end;
    final days = endDate.difference(startDate).inDays + 1;

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
              'Decisions: ${_decisions.length}',
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
        start: now.subtract(const Duration(days: 6)),
        end: now,
      );
    });
    _fetchDecisionsForRange();
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 29)),
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
          return {
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value),
          };
        }).toList();

        setState(() {
          _decisions = allDecisions.where((decision) {
            final date = DateTime.parse(decision['date']);
            return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
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

  Future<pw.Document> _generatePdfDocument() async {
    if (_selectedDateRange == null || _decisions.isEmpty) {
      throw Exception('No decisions found in the selected date range.');
    }

    final pdf = pw.Document();
    final completed = _decisions.where((d) => d['finalOutcome']?.isNotEmpty == true).length;
    final pending = _decisions.length - completed;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Decision Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Period: ${DateFormat('MMMM d, yyyy').format(_selectedDateRange!.start)} to ${DateFormat('MMMM d, yyyy').format(_selectedDateRange!.end)}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Total', _decisions.length.toString(), PdfColors.blue100),
                  _buildStatCard('Completed', completed.toString(), PdfColors.green100),
                  _buildStatCard('Pending', pending.toString(), PdfColors.orange100),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(thickness: 1, height: 30),
              pw.Text(
                'Decision Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
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
                    DateFormat('MMM d, yyyy').format(DateTime.parse(decision['date'])),
                    decision['title'],
                    decision['finalOutcome']?.isNotEmpty == true ? 'Completed' : 'Pending',
                    decision['finalOutcome'] ?? decision['expectedOutcome'] ?? 'N/A',
                  ];
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Container _buildStatCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 120,
      height: 70,
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
              style: pw.TextStyle(
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

  Future<void> _savePdfReport() async {
    setState(() => _isSaving = true);

    try {
      final pdf = await _generatePdfDocument();
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/decision_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdfReport() async {
    setState(() => _isSharing = true);

    try {
      final pdf = await _generatePdfDocument();
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/decision_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Decision Report - ${DateFormat('MMM yyyy').format(DateTime.now())}',
        text: 'Attached is your decision report for the selected period.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }
}