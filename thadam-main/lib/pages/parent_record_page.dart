import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'student_details_page.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────────────────────
class _T {
  static const navy      = Color(0xFF0D1B2A);
  static const navyLight = Color(0xFF1B2E42);
  static const teal      = Color(0xFF0A9396);
  static const tealLight = Color(0xFFD9F0F1);
  static const accent    = Color(0xFF94D2BD);
  static const surface   = Color(0xFFF8FAFB);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE4EAF0);
  static const textPri   = Color(0xFF0D1B2A);
  static const textSub   = Color(0xFF6B7A8D);
  static const red       = Color(0xFFE63946);
  static const orange    = Color(0xFFF4A261);
  static const green     = Color(0xFF2DC653);
}

// ─────────────────────────────────────────────────────────────
//  PDF COLOUR PALETTE  (reportlab-style PdfColor values)
// ─────────────────────────────────────────────────────────────
class _P {
  static const navy    = PdfColor.fromInt(0xFF0D1B2A);
  static const teal    = PdfColor.fromInt(0xFF0A9396);
  static const tealLt  = PdfColor.fromInt(0xFFD9F0F1);
  static const surface = PdfColor.fromInt(0xFFF8FAFB);
  static const border  = PdfColor.fromInt(0xFFE4EAF0);
  static const textPri = PdfColor.fromInt(0xFF0D1B2A);
  static const textSub = PdfColor.fromInt(0xFF6B7A8D);
  static const red     = PdfColor.fromInt(0xFFE63946);
  static const orange  = PdfColor.fromInt(0xFFF4A261);
  static const green   = PdfColor.fromInt(0xFF2DC653);
  static const amber   = PdfColor.fromInt(0xFFFFC300);
  static const white   = PdfColors.white;
}

class ParentRecordPage extends StatefulWidget {
  final String parentPhone;
  final String userRole;

  const ParentRecordPage({
    super.key,
    required this.parentPhone,
    required this.userRole,
  });

  @override
  State<ParentRecordPage> createState() => _ParentRecordPageState();
}

class _ParentRecordPageState extends State<ParentRecordPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track which student cards are generating a PDF
  final Set<String> _generatingPdf = {};

  Future<List<DocumentSnapshot>> _fetchStudentRecords() async {
    if (widget.userRole != "Parent") return [];

    final snapshot = await _firestore
        .collection('students')
        .where('parentPhone', isEqualTo: widget.parentPhone)
        .get();

    return snapshot.docs;
  }

  Future<Map<String, dynamic>?> _fetchLatestRecord(String studentId) async {
    final snap = await _firestore
        .collection('students')
        .doc(studentId)
        .collection('records')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data() as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────
  //  RATING HELPERS
  // ─────────────────────────────────────────────────────────────
  String _ratingLabel(int v) {
    switch (v) {
      case 1: return 'Below Baseline';
      case 2: return 'Baseline';
      case 3: return '25% - Beginning';
      case 4: return '50% - Improving';
      case 5: return '75% - Nearly Achieved';
      case 6: return 'Achieved';
      case 7: return 'Retained';
      default: return 'N/A';
    }
  }

  PdfColor _ratingPdfColor(int r) {
    if (r >= 6) return _P.green;
    if (r >= 4) return _P.orange;
    return _P.red;
  }

  String _starString(int rating, int max) {
    // Simple text-based stars for PDF
    return ('★' * rating) + ('☆' * (max - rating));
  }

  // ─────────────────────────────────────────────────────────────
  //  PDF GENERATION
  // ─────────────────────────────────────────────────────────────
  Future<void> _generateAndShareReport({
    required String studentId,
    required String studentName,
    required String disability,
    required String gender,
    required String age,
  }) async {
    setState(() => _generatingPdf.add(studentId));

    try {
      // 1. Fetch all records for this student
      final recordsSnap = await _firestore
          .collection('students')
          .doc(studentId)
          .collection('records')
          .orderBy('date', descending: false)
          .get();

      final allRecords = recordsSnap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      // 2. Group records by challenge
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final r in allRecords) {
        final key = r['challenge'] ?? 'Unknown';
        grouped.putIfAbsent(key, () => []).add(r);
      }

      // 3. Build PDF
      final doc = pw.Document(
        title: '$studentName - Progress Report',
        author: 'School Progress Tracker',
      );

      // Load fonts (Helvetica is built-in, no asset needed)
      final baseFont    = pw.Font.helvetica();
      final boldFont    = pw.Font.helveticaBold();
      final obliqueFont = pw.Font.helveticaOblique();

      final now = DateTime.now();
      final reportDate =
          '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/'
          '${now.year}';

      // ── Page 1: Cover / Summary ──────────────────────────────
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

                // ── Header Banner ──
                pw.Container(
                  height: 160,
                  color: _P.navy,
                  padding: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Student Progress Report',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 22,
                                  color: _P.white,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Confidential — For Parent Use Only',
                                style: pw.TextStyle(
                                  font: obliqueFont,
                                  fontSize: 11,
                                  color: PdfColor.fromInt(0xFFB2C8D6),
                                ),
                              ),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: _P.teal,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(
                              'Generated $reportDate',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 10,
                                  color: _P.white),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                      // Teal accent line
                      pw.Container(height: 3, width: 60, color: _P.teal),
                    ],
                  ),
                ),

                pw.SizedBox(height: 0),

                // ── Teal sub-bar with student name ──
                pw.Container(
                  color: _P.teal,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 36, vertical: 14),
                  child: pw.Text(
                    studentName,
                    style: pw.TextStyle(
                        font: boldFont, fontSize: 18, color: _P.white),
                  ),
                ),

                // ── Body ──
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(36),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [

                        // Student info grid
                        _pdfSectionLabel('STUDENT INFORMATION', boldFont),
                        pw.SizedBox(height: 10),
                        pw.Row(
                          children: [
                            _pdfInfoBox('Gender', gender, baseFont, boldFont),
                            pw.SizedBox(width: 12),
                            _pdfInfoBox('Age', '$age yrs', baseFont, boldFont),
                            pw.SizedBox(width: 12),
                            _pdfInfoBox('Total Areas', '${grouped.length}',
                                baseFont, boldFont),
                            pw.SizedBox(width: 12),
                            _pdfInfoBox('Total Entries',
                                '${allRecords.length}', baseFont, boldFont),
                          ],
                        ),
                        pw.SizedBox(height: 16),

                        // Disability row
                        pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: _P.tealLt,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(
                                color: _P.teal, width: 0.8),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Text('Disability / Diagnosis:  ',
                                  style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 12,
                                      color: _P.textSub)),
                              pw.Text(disability,
                                  style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 13,
                                      color: _P.teal)),
                            ],
                          ),
                        ),

                        pw.SizedBox(height: 28),

                        // Summary table — one row per challenge
                        _pdfSectionLabel('PROGRESS SUMMARY', boldFont),
                        pw.SizedBox(height: 10),

                        // Table header
                        pw.Container(
                          color: _P.navy,
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text('Challenge / Goal',
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 10,
                                        color: _P.white)),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text('Area',
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 10,
                                        color: _P.white)),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text('Entries',
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 10,
                                        color: _P.white),
                                    textAlign: pw.TextAlign.center),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text('Latest Rating',
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 10,
                                        color: _P.white),
                                    textAlign: pw.TextAlign.center),
                              ),
                            ],
                          ),
                        ),

                        // Table rows
                        ...grouped.entries.toList().asMap().entries.map((e) {
                          final idx = e.key;
                          final challenge = e.value.key;
                          final entries = e.value.value;
                          final latest = entries.last;
                          final rating = (latest['rating'] as int?) ?? 0;
                          final area = latest['areaOfSupport'] ?? '';
                          final isEven = idx % 2 == 0;

                          return pw.Container(
                            color: isEven ? _P.surface : _P.white,
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: pw.Row(
                              crossAxisAlignment:
                              pw.CrossAxisAlignment.center,
                              children: [
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Text(challenge,
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 10,
                                          color: _P.textPri)),
                                ),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Text(area,
                                      style: pw.TextStyle(
                                          font: baseFont,
                                          fontSize: 9,
                                          color: _P.textSub)),
                                ),
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Text('${entries.length}',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 10,
                                          color: _P.textPri),
                                      textAlign: pw.TextAlign.center),
                                ),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: pw.BoxDecoration(
                                      color: _ratingPdfColor(rating)
                                          .shade(0.15),
                                      borderRadius:
                                      pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      '$rating — ${_ratingLabel(rating)}',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 9,
                                          color: _ratingPdfColor(rating)),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        pw.SizedBox(height: 28),

                        // Footer note
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: _P.border, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            'This report was generated automatically from classroom '
                                'observations. For detailed notes and progress history, '
                                'please refer to the following pages.',
                            style: pw.TextStyle(
                                font: obliqueFont,
                                fontSize: 9,
                                color: _P.textSub),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Footer bar ──
                pw.Container(
                  height: 30,
                  color: _P.navy,
                  padding:
                  const pw.EdgeInsets.symmetric(horizontal: 36),
                  child: pw.Row(
                    mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('$studentName  •  Progress Report',
                          style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 8,
                              color: PdfColor.fromInt(0xFF8899AA))),
                      pw.Text('Page 1 of ${grouped.length + 1}',
                          style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 8,
                              color: PdfColor.fromInt(0xFF8899AA))),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // ── One page per challenge ───────────────────────────────
      int pageNum = 2;
      for (final entry in grouped.entries) {
        final challenge = entry.key;
        final entries  = entry.value;
        final area     = entries.last['areaOfSupport'] ?? '';
        final type     = entries.last['entryType'] ?? 'Behaviour';
        final total    = grouped.length + 1;

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [

                  // ── Compact header ──
                  pw.Container(
                    color: _P.navy,
                    padding: const pw.EdgeInsets.fromLTRB(36, 20, 36, 20),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(studentName,
                                style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 14,
                                    color: _P.white)),
                            pw.SizedBox(height: 2),
                            pw.Text('Progress Report',
                                style: pw.TextStyle(
                                    font: baseFont,
                                    fontSize: 9,
                                    color:
                                    PdfColor.fromInt(0xFF8899AA))),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: pw.BoxDecoration(
                            color: _P.teal,
                            borderRadius: pw.BorderRadius.circular(5),
                          ),
                          child: pw.Text(type,
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 10,
                                  color: _P.white)),
                        ),
                      ],
                    ),
                  ),

                  // ── Challenge title bar ──
                  pw.Container(
                    color: _P.teal,
                    padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(challenge,
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 15,
                                color: _P.white)),
                        pw.SizedBox(height: 3),
                        pw.Text(area,
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 10,
                                color: PdfColor.fromInt(0xFFD9F0F1))),
                      ],
                    ),
                  ),

                  // ── Body ──
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(36),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [

                          // Stats row
                          pw.Row(
                            children: [
                              _pdfStatChip(
                                '${entries.length}',
                                'Total Entries',
                                baseFont,
                                boldFont,
                              ),
                              pw.SizedBox(width: 12),
                              _pdfStatChip(
                                '${(entries.last['rating'] as int?) ?? 0}',
                                'Latest Rating',
                                baseFont,
                                boldFont,
                                color: _ratingPdfColor(
                                    (entries.last['rating'] as int?) ?? 0),
                              ),
                              pw.SizedBox(width: 12),
                              _pdfStatChip(
                                _ratingLabel(
                                    (entries.last['rating'] as int?) ?? 0),
                                'Status',
                                baseFont,
                                boldFont,
                              ),
                            ],
                          ),

                          pw.SizedBox(height: 20),
                          _pdfSectionLabel('OBSERVATION HISTORY', boldFont),
                          pw.SizedBox(height: 8),

                          // Column header
                          pw.Container(
                            color: PdfColor.fromInt(0xFFE8F0F5),
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 80,
                                  child: pw.Text('Date',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 9,
                                          color: _P.textPri)),
                                ),
                                pw.SizedBox(width: 60,
                                  child: pw.Text('Rating',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 9,
                                          color: _P.textPri)),
                                ),
                                pw.Expanded(
                                  child: pw.Text('Teacher Note',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 9,
                                          color: _P.textPri)),
                                ),
                                pw.SizedBox(
                                  width: 20,
                                  child: pw.Text('AI',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 9,
                                          color: _P.textSub),
                                      textAlign: pw.TextAlign.center),
                                ),
                              ],
                            ),
                          ),

                          // Entry rows (newest first for the detail page)
                          ...entries.reversed.toList().asMap().entries.map((e) {
                            final i = e.key;
                            final rec = e.value;
                            final date = rec['date'] ?? '';
                            final rating = (rec['rating'] as int?) ?? 0;
                            final note = rec['teacherNote'] ?? 'No note added';
                            final aiGenerated = rec['aiGenerated'] == true;
                            final isEven = i % 2 == 0;
                            final isFirst = i == 0; // newest = latest

                            return pw.Container(
                              color: isFirst
                                  ? _P.green.shade(0.08)
                                  : isEven
                                  ? _P.surface
                                  : _P.white,
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: pw.Row(
                                crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                                children: [
                                  pw.SizedBox(
                                    width: 80,
                                    child: pw.Column(
                                      crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(date,
                                            style: pw.TextStyle(
                                                font: boldFont,
                                                fontSize: 9,
                                                color: _P.textPri)),
                                        if (isFirst)
                                          pw.Container(
                                            margin: const pw.EdgeInsets
                                                .only(top: 3),
                                            padding:
                                            const pw.EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2),
                                            decoration: pw.BoxDecoration(
                                              color: _P.green.shade(0.18),
                                              borderRadius:
                                              pw.BorderRadius.circular(3),
                                            ),
                                            child: pw.Text('Latest',
                                                style: pw.TextStyle(
                                                    font: boldFont,
                                                    fontSize: 7,
                                                    color: _P.green)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(
                                    width: 60,
                                    child: pw.Column(
                                      crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text('$rating',
                                            style: pw.TextStyle(
                                                font: boldFont,
                                                fontSize: 13,
                                                color:
                                                _ratingPdfColor(rating))),
                                        pw.Text(
                                            _ratingLabel(rating),
                                            style: pw.TextStyle(
                                                font: baseFont,
                                                fontSize: 7,
                                                color:
                                                _ratingPdfColor(rating))),
                                      ],
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(note,
                                        style: pw.TextStyle(
                                            font: baseFont,
                                            fontSize: 9,
                                            color: _P.textSub),
                                        maxLines: 3),
                                  ),
                                  pw.SizedBox(
                                    width: 20,
                                    child: aiGenerated
                                        ? pw.Container(
                                      padding:
                                      const pw.EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical: 2),
                                      decoration: pw.BoxDecoration(
                                        color: _P.tealLt,
                                        borderRadius:
                                        pw.BorderRadius.circular(3),
                                      ),
                                      child: pw.Text('AI',
                                          style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 7,
                                              color: _P.teal),
                                          textAlign:
                                          pw.TextAlign.center),
                                    )
                                        : pw.SizedBox(),
                                  ),
                                ],
                              ),
                            );
                          }),

                          pw.Spacer(),

                          // Rating scale legend
                          pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: _P.surface,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(
                                  color: _P.border, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Rating Scale',
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 9,
                                        color: _P.textPri)),
                                pw.SizedBox(height: 4),
                                pw.Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    for (int r = 1; r <= 7; r++)
                                      pw.Text(
                                        '$r — ${_ratingLabel(r)}',
                                        style: pw.TextStyle(
                                            font: baseFont,
                                            fontSize: 8,
                                            color: _ratingPdfColor(r)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Footer ──
                  pw.Container(
                    height: 30,
                    color: _P.navy,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 36),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$studentName  •  $challenge',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColor.fromInt(0xFF8899AA))),
                        pw.Text('Page $pageNum of $total',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColor.fromInt(0xFF8899AA))),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
        pageNum++;
      }

      // 4. Share / save
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${studentName.replaceAll(' ', '_')}_Progress_Report_$reportDate.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate report: $e',
                style: const TextStyle(fontSize: 14)),
            backgroundColor: const Color(0xFFE63946),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf.remove(studentId));
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  PDF WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────
  pw.Widget _pdfSectionLabel(String text, pw.Font bold) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 14,
          color: _P.teal,
          margin: const pw.EdgeInsets.only(right: 8),
        ),
        pw.Text(text,
            style: pw.TextStyle(
                font: bold,
                fontSize: 10,
                letterSpacing: 0.8,
                color: _P.textSub)),
      ],
    );
  }

  pw.Widget _pdfInfoBox(
      String label, String value, pw.Font base, pw.Font bold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _P.surface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _P.border, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: base, fontSize: 8, color: _P.textSub)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    font: bold, fontSize: 13, color: _P.textPri)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfStatChip(String value, String label, pw.Font base,
      pw.Font bold, {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: (color ?? _P.teal).shade(0.10),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(
              color: (color ?? _P.teal).shade(0.3), width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 15,
                    color: color ?? _P.teal)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: pw.TextStyle(
                    font: base, fontSize: 8, color: _P.textSub)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          "Your Child's Progress",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchStudentRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _T.teal),
            );
          }

          if (widget.userRole != "Parent") {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _T.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          size: 54, color: _T.red),
                    ),
                    const SizedBox(height: 20),
                    const Text('Access Denied',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _T.textPri)),
                    const SizedBox(height: 10),
                    Text('Only parents can view this page.',
                        style: TextStyle(
                            fontSize: 14, color: _T.textSub, height: 1.5),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _T.tealLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.child_care_rounded,
                          size: 54, color: _T.teal),
                    ),
                    const SizedBox(height: 20),
                    const Text('No Records Found',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _T.textPri)),
                    const SizedBox(height: 10),
                    Text('No student records have been created yet.',
                        style: TextStyle(
                            fontSize: 14, color: _T.textSub, height: 1.5),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final studentData =
              students[index].data() as Map<String, dynamic>;
              final studentId = students[index].id;
              final name =
                  studentData['name'] ?? studentData['studentName'] ?? 'Unnamed';
              final disability =
                  studentData['disability'] ?? 'Not specified';
              final gender = studentData['gender'] ?? 'Not specified';
              final age = studentData['age']?.toString() ?? 'N/A';

              return _buildStudentCard(
                  context, studentId, name, disability, gender, age);
            },
          );
        },
      ),
    );
  }

  Widget _buildStudentCard(
      BuildContext context,
      String studentId,
      String name,
      String disability,
      String gender,
      String age,
      ) {
    final isGenerating = _generatingPdf.contains(studentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_T.navy, _T.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                    Border.all(color: Colors.white30, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: _T.teal.withOpacity(0.3),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _T.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 5),
                      Text('Student Record',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.75),
                              letterSpacing: 0.4)),
                    ],
                  ),
                ),

                // ── Download PDF button ──
                Tooltip(
                  message: 'Download Progress Report (PDF)',
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isGenerating
                        ? Container(
                      key: const ValueKey('loading'),
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : InkWell(
                      key: const ValueKey('button'),
                      onTap: () => _generateAndShareReport(
                        studentId: studentId,
                        studentName: name,
                        disability: disability,
                        gender: gender,
                        age: age,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white24, width: 1),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Student Information ──
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _buildInfoItem(
                            icon: Icons.male_rounded,
                            label: 'Gender',
                            value: gender)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: _buildInfoItem(
                            icon: Icons.cake_outlined,
                            label: 'Age',
                            value: age)),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _T.tealLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _T.teal.withOpacity(0.2), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.accessibility_new_rounded,
                          color: _T.teal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Disability',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _T.textSub,
                                    letterSpacing: 0.4)),
                            const SizedBox(height: 3),
                            Text(disability,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _T.teal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLatestRecord(studentId),
                  builder: (context, recordSnap) {
                    if (recordSnap.connectionState ==
                        ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _T.surface,
                          borderRadius: BorderRadius.circular(10),
                          border:
                          Border.all(color: _T.border, width: 1.2),
                        ),
                        child: const SizedBox(
                          height: 22,
                          child: CircularProgressIndicator(
                              color: _T.teal, strokeWidth: 2.5),
                        ),
                      );
                    }

                    if (recordSnap.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _T.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _T.red.withOpacity(0.2), width: 1.2),
                        ),
                        child: Text('Error loading record',
                            style: TextStyle(
                                fontSize: 13,
                                color: _T.red,
                                fontWeight: FontWeight.w600)),
                      );
                    }

                    final latest = recordSnap.data;

                    if (latest == null) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _T.surface,
                          borderRadius: BorderRadius.circular(10),
                          border:
                          Border.all(color: _T.border, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: _T.textSub, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No progress updates recorded yet.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _T.textSub,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final date = latest['date'] ?? 'Unknown date';
                    final rating = latest['rating']?.toString() ?? 'N/A';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _T.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _T.green.withOpacity(0.2), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: _T.green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Latest Update',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _T.textSub,
                                        letterSpacing: 0.4)),
                                const SizedBox(height: 3),
                                Text('On $date, rating: $rating',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _T.green)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // ── Action buttons row ──
                Row(
                  children: [
                    // View Details
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentDetailPage(
                                studentId: studentId,
                                studentName: name,
                                userRole: "Parent",
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _T.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'View Full Details & Progress',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Download PDF (secondary button)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: isGenerating
                            ? null
                            : () => _generateAndShareReport(
                          studentId: studentId,
                          studentName: name,
                          disability: disability,
                          gender: gender,
                          age: age,
                        ),
                        icon: isGenerating
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _T.teal),
                        )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          isGenerating ? 'Building...' : 'PDF',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _T.teal,
                          side: const BorderSide(color: _T.teal, width: 1.5),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _T.teal),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _T.textSub,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _T.textPri)),
        ],
      ),
    );
  }
}