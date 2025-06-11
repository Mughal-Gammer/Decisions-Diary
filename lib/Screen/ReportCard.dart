import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Uint8List? _logoBytes; // Stores the logo image bytes

  @override
  void initState() {
    super.initState();
    _loadLogo(); // Load the logo when the widget initializes
  }

  Future<void> _loadLogo() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      setState(() {
        _logoBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      print("Error loading logo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(onPressed: (Navigator.of(context).pop), icon: Icon(Icons.arrow_back,color: Colors.white,)),
        title: const Text('Decision Reports',style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
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
                : const Icon(Icons.save, color: Colors.white),
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
                : const Icon(Icons.share, color: Colors.white),
            onPressed: _isLoading || _isSaving || _isSharing ? null : _sharePdfReport,
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blueAccent,
                ),
                onPressed: _selectLast7Days,
                label: const Text('Last 7 Days'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_view_month, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blueAccent,
                ),
                onPressed: _selectLastMonth,
                label: const Text('Last Month'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Date Range:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 12),
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
              selectionColor: Colors.blueAccent,
              rangeSelectionColor: Colors.blueAccent.withOpacity(0.2),
              startRangeSelectionColor: Colors.blueAccent,
              endRangeSelectionColor: Colors.blueAccent,
              todayHighlightColor: Colors.blueAccent,
              monthCellStyle: const DateRangePickerMonthCellStyle(
                todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              yearCellStyle: const DateRangePickerYearCellStyle(
                todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
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
    final completed = _decisions.where((d) => d['finalOutcome']?.isNotEmpty == true).length;
    final pending = _decisions.length - completed;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Report Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('From:', DateFormat('MMM d, yyyy').format(startDate)),
            _buildSummaryRow('To:', DateFormat('MMM d, yyyy').format(endDate)),
            const Divider(height: 30, thickness: 1),
            _buildSummaryRow('Period:', '$days days'),
            _buildSummaryRow('Total Decisions:', _decisions.length.toString()),
            _buildSummaryRow('Completed:', '$completed', Colors.green),
            _buildSummaryRow('Pending:', '$pending', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
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
          _fetchDecisionsForRange();
        });
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
      _fetchDecisionsForRange();
    });
  }

  void _selectLastMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 29)),
        end: now,
      );
      _fetchDecisionsForRange();
    });
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
      } else {
        setState(() {
          _decisions = [];
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
    if (_selectedDateRange == null) {
      throw Exception('Please select a date range first.');
    }

    final pdf = pw.Document();
    final completed = _decisions.where((d) => d['finalOutcome']?.isNotEmpty == true).length;
    final pending = _decisions.length - completed;

    // Create a PDF logo widget if we have the logo bytes
    pw.Widget? logoWidget;
    if (_logoBytes != null) {
      logoWidget = pw.Container(
        height: 60,
        child: pw.Image(pw.MemoryImage(_logoBytes!)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Column(
              children: [
                if (logoWidget != null) logoWidget,
                pw.SizedBox(height: 10),
                pw.Text(
                  'Decision Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Divider(thickness: 1, height: 16),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Report Period: ${DateFormat('MMMM d, yyyy').format(_selectedDateRange!.start)} to ${DateFormat('MMMM d, yyyy').format(_selectedDateRange!.end)}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
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
              pw.SizedBox(height: 30),
              pw.Text(
                'Decision Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 10),
              if (_decisions.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Center(
                    child: pw.Text(
                      'No decisions found in the selected date range',
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                    ),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  context: context,
                  cellAlignment: pw.Alignment.centerLeft,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColors.blue800,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  headers: ['Date', 'Title', 'Status', 'Outcome'],
                  data: _decisions.map((decision) {
                    return [
                      DateFormat('MMM d, yyyy').format(DateTime.parse(decision['date'])),
                      decision['title'] ?? 'Untitled',
                      decision['finalOutcome']?.isNotEmpty == true
                          ? pw.Text('Completed', style: pw.TextStyle(color: PdfColors.green))
                          : pw.Text('Pending', style: pw.TextStyle(color: PdfColors.orange)),
                      decision['finalOutcome'] ?? decision['expectedOutcome'] ?? 'N/A',
                    ];
                  }).toList(),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  cellStyle: const pw.TextStyle(fontSize: 10),
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
      width: 100,
      height: 70,
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 3,
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
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
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
      final fileName = 'decision_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
      final fileName = 'decision_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Decision Report - ${DateFormat('MMM yyyy').format(DateTime.now())}',
        text: 'Attached is your decision report for the selected period.',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSharing = false);
    }
  }
}