// pdf_report_service.dart
// Drop-in replacement — call PdfReportService.generate(...) from any page.
//
// pubspec.yaml dependencies needed:
//   pdf: ^3.11.0
//   printing: ^5.13.0

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart' show Color;

// ─────────────────────────────────────────────────────────────
//  COLOUR PALETTE  (mirrors the app _T tokens)
// ─────────────────────────────────────────────────────────────
class _C {
  static const navy       = PdfColor.fromInt(0xFF0D1B2A);
  static const navyMid    = PdfColor.fromInt(0xFF1B2E42);
  static const navyLight  = PdfColor.fromInt(0xFF243D55);
  static const teal       = PdfColor.fromInt(0xFF0A9396);
  static const tealDark   = PdfColor.fromInt(0xFF077377);
  static const tealLight  = PdfColor.fromInt(0xFFD9F0F1);
  static const tealPale   = PdfColor.fromInt(0xFFEEF8F9);
  static const accent     = PdfColor.fromInt(0xFF94D2BD);
  static const surface    = PdfColor.fromInt(0xFFF8FAFB);
  static const surfaceAlt = PdfColor.fromInt(0xFFF0F4F7);
  static const border     = PdfColor.fromInt(0xFFE4EAF0);
  static const textPri    = PdfColor.fromInt(0xFF0D1B2A);
  static const textSub    = PdfColor.fromInt(0xFF6B7A8D);
  static const textMuted  = PdfColor.fromInt(0xFF9AAABB);
  static const white      = PdfColors.white;
  static const red        = PdfColor.fromInt(0xFFE63946);
  static const redLight   = PdfColor.fromInt(0xFFFDECED);
  static const orange     = PdfColor.fromInt(0xFFF4A261);
  static const orangeLight= PdfColor.fromInt(0xFFFEF3EC);
  static const green      = PdfColor.fromInt(0xFF2DC653);
  static const greenLight = PdfColor.fromInt(0xFFE8FAEd);
  static const amber      = PdfColor.fromInt(0xFFFFC300);
}

// ─────────────────────────────────────────────────────────────
//  RATING HELPERS
// ─────────────────────────────────────────────────────────────
String _ratingLabel(int v) {
  switch (v) {
    case 1: return 'Below Baseline';
    case 2: return 'Baseline';
    case 3: return 'Beginning (25%)';
    case 4: return 'Improving (50%)';
    case 5: return 'Nearly Achieved (75%)';
    case 6: return 'Achieved';
    case 7: return 'Retained';
    default: return 'N/A';
  }
}

PdfColor _ratingBg(int r) {
  if (r >= 6) return _C.greenLight;
  if (r >= 4) return _C.orangeLight;
  return _C.redLight;
}

PdfColor _ratingFg(int r) {
  if (r >= 6) return _C.green;
  if (r >= 4) return _C.orange;
  return _C.red;
}

// Draw a filled progress bar 1-7
pw.Widget _ratingBar(int rating, pw.Font bold, pw.Font base) {
  const total = 7;
  final fraction = rating / total;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Container(
            width: 24,
            height: 24,
            decoration: pw.BoxDecoration(
              color: _ratingBg(rating),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              '$rating',
              style: pw.TextStyle(
                  font: bold, fontSize: 11, color: _ratingFg(rating)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              _ratingLabel(rating),
              style: pw.TextStyle(
                  font: bold, fontSize: 9, color: _ratingFg(rating)),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 5),
      pw.LayoutBuilder(
        builder: (ctx, constraints) {
          final totalWidth = constraints?.maxWidth ?? 400.0;
          final filledWidth = totalWidth * fraction;
          return pw.Stack(
            children: [
              pw.Container(
                width: totalWidth,
                height: 5,
                decoration: pw.BoxDecoration(
                  color: _C.border,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
              pw.Container(
                width: filledWidth,
                height: 5,
                decoration: pw.BoxDecoration(
                  color: _ratingFg(rating),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
//  SECTION HEADING
// ─────────────────────────────────────────────────────────────
pw.Widget _sectionHeading(String text, pw.Font bold) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 4,
          height: 16,
          decoration: pw.BoxDecoration(
            color: _C.teal,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          text,
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            color: _C.navy,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  STUDENT INFO PILL
// ─────────────────────────────────────────────────────────────
pw.Widget _infoPill(String label, String value, pw.Font base, pw.Font bold) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _C.surface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _C.border, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: base, fontSize: 8, color: _C.textSub, letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(font: bold, fontSize: 12, color: _C.textPri)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  TABLE HEADER ROW
// ─────────────────────────────────────────────────────────────
pw.Widget _tableHeader(List<pw.Widget> cells) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      color: _C.navy,
      borderRadius: pw.BorderRadius.only(
        topLeft: pw.Radius.circular(6),
        topRight: pw.Radius.circular(6),
      ),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: pw.Row(children: cells),
  );
}

// ─────────────────────────────────────────────────────────────
//  TABLE CELL TEXT — header style
// ─────────────────────────────────────────────────────────────
pw.Widget _th(String t, pw.Font bold, {int flex = 1, pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Expanded(
    flex: flex,
    child: pw.Text(t,
        style: pw.TextStyle(font: bold, fontSize: 9, color: _C.white,
            letterSpacing: 0.4),
        textAlign: align),
  );
}

// ─────────────────────────────────────────────────────────────
//  TABLE CELL TEXT — body style
// ─────────────────────────────────────────────────────────────
pw.Widget _td(String t, pw.Font font, {int flex = 1, PdfColor? color,
  pw.TextAlign align = pw.TextAlign.left, int maxLines = 3}) {
  return pw.Expanded(
    flex: flex,
    child: pw.Text(t,
        maxLines: maxLines,
        style: pw.TextStyle(
            font: font, fontSize: 9, color: color ?? _C.textPri),
        textAlign: align),
  );
}

// ─────────────────────────────────────────────────────────────
//  MAIN SERVICE
// ─────────────────────────────────────────────────────────────
class PdfReportService {
  /// Call this from any page. Pass all student Firestore records.
  static Future<void> generate({
    required String studentName,
    required String studentId,
    required String disability,
    required String gender,
    required String age,
    required String phone,
    required String schoolName,
    required List<Map<String, dynamic>> allRecords,
  }) async {
    final baseFont    = pw.Font.helvetica();
    final boldFont    = pw.Font.helveticaBold();
    final obliqueFont = pw.Font.helveticaOblique();

    final now = DateTime.now();
    final reportDate =
        '${now.day.toString().padLeft(2, '0')} '
        '${_monthName(now.month)} ${now.year}';

    final initials = studentName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    // Group records by area -> challenge
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (final r in allRecords) {
      final area      = r['areaOfSupport'] ?? 'General';
      final challenge = r['challenge']     ?? 'Unknown';
      grouped.putIfAbsent(area, () => {})[challenge] ??= [];
      grouped[area]![challenge]!.add(r);
    }

    // Sort entries within each challenge by date ascending
    for (final areaMap in grouped.values) {
      for (final list in areaMap.values) {
        list.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
      }
    }

    final doc = pw.Document(
      title: '$studentName - Progress Report',
      author: schoolName,
    );

    // ─────────────────────────────────────────────────────────
    //  PAGE 1 — COVER + SUMMARY
    // ─────────────────────────────────────────────────────────
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [

            // ── Hero banner ──────────────────────────────────
            pw.Container(
              height: 200,
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [_C.navy, _C.navyMid, _C.navyLight],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
              ),
              child: pw.Stack(
                children: [
                  // Decorative teal arc top-right
                  pw.Positioned(
                    top: -40,
                    right: -40,
                    child: pw.Container(
                      width: 160,
                      height: 160,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        color: _C.teal.shade(0.15),
                      ),
                    ),
                  ),
                  pw.Positioned(
                    top: 10,
                    right: 10,
                    child: pw.Container(
                      width: 90,
                      height: 90,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        color: _C.teal.shade(0.10),
                      ),
                    ),
                  ),

                  // Content
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(40, 30, 40, 24),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // School name + date pill
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  schoolName.toUpperCase(),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 10,
                                    color: _C.accent,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Student Progress Report',
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 22,
                                    color: _C.white,
                                  ),
                                ),
                              ],
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: _C.teal,
                                borderRadius: pw.BorderRadius.circular(20),
                              ),
                              child: pw.Text(
                                'Generated: $reportDate',
                                style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 9,
                                    color: _C.white),
                              ),
                            ),
                          ],
                        ),

                        pw.SizedBox(height: 20),

                        // Student avatar + name row
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            // Avatar circle
                            pw.Container(
                              width: 58,
                              height: 58,
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: _C.teal,
                                border: pw.Border.all(
                                    color: _C.accent, width: 2.5),
                              ),
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                initials,
                                style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 20,
                                    color: _C.white),
                              ),
                            ),
                            pw.SizedBox(width: 16),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  studentName,
                                  style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 18,
                                      color: _C.white),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: pw.BoxDecoration(
                                    color: _C.teal.shade(0.3),
                                    borderRadius:
                                    pw.BorderRadius.circular(4),
                                  ),
                                  child: pw.Text(
                                    disability,
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 9,
                                        color: _C.tealLight),
                                  ),
                                ),
                              ],
                            ),
                            pw.Spacer(),
                            // Confidential badge
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                    color: _C.red, width: 1),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'CONFIDENTIAL',
                                style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 8,
                                    color: _C.red,
                                    letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Teal divider ─────────────────────────────────
            pw.Container(height: 4, color: _C.teal),

            // ── Body ─────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(40, 28, 40, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    // Student details card
                    _sectionHeading('STUDENT DETAILS', boldFont),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: _C.surface,
                        borderRadius: pw.BorderRadius.circular(10),
                        border: pw.Border.all(color: _C.border, width: 0.8),
                      ),
                      padding: const pw.EdgeInsets.all(16),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            children: [
                              _infoPill('NAME', studentName, baseFont, boldFont),
                              pw.SizedBox(width: 10),
                              _infoPill('AGE', '$age yrs', baseFont, boldFont),
                              pw.SizedBox(width: 10),
                              _infoPill('GENDER', gender, baseFont, boldFont),
                              pw.SizedBox(width: 10),
                              _infoPill('CONTACT', phone, baseFont, boldFont),
                            ],
                          ),
                          pw.SizedBox(height: 10),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: _C.tealPale,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(
                                  color: _C.teal.shade(0.3), width: 0.8),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const pw.BoxDecoration(
                                    color: _C.teal,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 10),
                                pw.Text('Disability / Diagnosis:  ',
                                    style: pw.TextStyle(
                                        font: baseFont,
                                        fontSize: 10,
                                        color: _C.textSub)),
                                pw.Text(disability,
                                    style: pw.TextStyle(
                                        font: boldFont,
                                        fontSize: 11,
                                        color: _C.teal)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 22),

                    // Stats row
                    _sectionHeading('OVERVIEW STATISTICS', boldFont),
                    pw.Row(
                      children: [
                        _statCard(
                          '${allRecords.length}',
                          'Total Observations',
                          _C.teal,
                          baseFont,
                          boldFont,
                        ),
                        pw.SizedBox(width: 10),
                        _statCard(
                          '${grouped.keys.length}',
                          'Support Areas',
                          _C.navyMid,
                          baseFont,
                          boldFont,
                        ),
                        pw.SizedBox(width: 10),
                        _statCard(
                          '${grouped.values.fold<int>(0, (sum, m) => sum + m.keys.length)}',
                          'Challenges Tracked',
                          _C.tealDark,
                          baseFont,
                          boldFont,
                        ),
                        pw.SizedBox(width: 10),
                        _statCard(
                          _latestDate(allRecords),
                          'Last Updated',
                          _C.navy,
                          baseFont,
                          boldFont,
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 22),

                    // Summary table
                    _sectionHeading('CHALLENGE SUMMARY — HIGHEST RATING PER GOAL', boldFont),
                    _tableHeader([
                      _th('Area of Support', boldFont, flex: 3),
                      _th('Challenge / Goal', boldFont, flex: 3),
                      _th('Entries', boldFont, flex: 1, align: pw.TextAlign.center),
                      _th('Highest Rating', boldFont, flex: 3),
                    ]),

                    ...() {
                      final rows = <pw.Widget>[];
                      int rowIdx = 0;
                      for (final areaEntry in grouped.entries) {
                        for (final challengeEntry in areaEntry.value.entries) {
                          final ratingList = challengeEntry.value
                              .map((r) => (r['rating'] as int?) ?? 0)
                              .toList();
                          final highest = ratingList.isEmpty
                              ? 0
                              : ratingList.reduce((a, b) => a > b ? a : b);
                          final isEven = rowIdx % 2 == 0;

                          rows.add(
                            pw.Container(
                              color: isEven ? _C.surface : _C.white,
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  _td(areaEntry.key, baseFont,
                                      flex: 3, color: _C.textSub),
                                  _td(challengeEntry.key, boldFont, flex: 3),
                                  _td('${challengeEntry.value.length}', boldFont,
                                      flex: 1,
                                      color: _C.teal,
                                      align: pw.TextAlign.center),
                                  pw.Expanded(
                                    flex: 3,
                                    child: pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: pw.BoxDecoration(
                                        color: _ratingBg(highest),
                                        borderRadius:
                                        pw.BorderRadius.circular(4),
                                      ),
                                      child: pw.Row(
                                        mainAxisSize: pw.MainAxisSize.min,
                                        children: [
                                          pw.Container(
                                            width: 18,
                                            height: 18,
                                            decoration: pw.BoxDecoration(
                                              color: _ratingFg(highest),
                                              borderRadius:
                                              pw.BorderRadius.circular(3),
                                            ),
                                            alignment: pw.Alignment.center,
                                            child: pw.Text('$highest',
                                                style: pw.TextStyle(
                                                    font: boldFont,
                                                    fontSize: 9,
                                                    color: _C.white)),
                                          ),
                                          pw.SizedBox(width: 6),
                                          pw.Flexible(
                                            child: pw.Text(
                                              _ratingLabel(highest),
                                              style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 8,
                                                  color: _ratingFg(highest)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          rowIdx++;
                        }
                      }
                      // Bottom border
                      rows.add(pw.Container(
                        height: 0.8,
                        color: _C.border,
                      ));
                      return rows;
                    }(),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────
            _pageFooter(studentName, '1', '${grouped.keys.length + 1}',
                baseFont, boldFont),
          ],
        ),
      ),
    );

    // ─────────────────────────────────────────────────────────
    //  ONE PAGE PER AREA (detailed observations)
    // ─────────────────────────────────────────────────────────
    int pageNum = 2;
    final totalPages = grouped.keys.length + 1;

    for (final areaEntry in grouped.entries) {
      final area = areaEntry.key;
      final challenges = areaEntry.value;

      // Gather all entries for progress trend
      final allAreaEntries = challenges.values.expand((e) => e).toList();
      allAreaEntries
          .sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [

              // ── Compact header ──────────────────────────────
              pw.Container(
                height: 70,
                color: _C.navy,
                padding: const pw.EdgeInsets.fromLTRB(40, 16, 40, 14),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(studentName,
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 14,
                                color: _C.white)),
                        pw.SizedBox(height: 2),
                        pw.Text('Progress Report  -  $schoolName',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 9,
                                color: _C.textMuted)),
                      ],
                    ),
                    pw.Spacer(),
                    // Area badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: _C.teal,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        area,
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 10, color: _C.white),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Container(height: 3, color: _C.teal),

              // ── Body ────────────────────────────────────────
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(40, 24, 40, 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [

                      // Area info bar
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: _C.tealPale,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                              color: _C.teal.shade(0.3), width: 0.8),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const pw.BoxDecoration(
                                          color: _C.teal,
                                          shape: pw.BoxShape.circle)),
                                  pw.SizedBox(width: 8),
                                  pw.Text('Area of Support:  ',
                                      style: pw.TextStyle(
                                          font: baseFont,
                                          fontSize: 10,
                                          color: _C.textSub)),
                                  pw.Text(area,
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 11,
                                          color: _C.teal)),
                                ],
                              ),
                            ),
                            pw.Text(
                              '${challenges.keys.length} challenge${challenges.keys.length == 1 ? '' : 's'}  -  ${allAreaEntries.length} observation${allAreaEntries.length == 1 ? '' : 's'}',
                              style: pw.TextStyle(
                                  font: baseFont,
                                  fontSize: 9,
                                  color: _C.textSub),
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 20),

                      // One block per challenge
                      ...challenges.entries.map((challengeEntry) {
                        final challenge = challengeEntry.key;
                        final entries = challengeEntry.value;
                        // Sorted oldest->newest already
                        final latest = entries.last;
                        final latestRating =
                            (latest['rating'] as int?) ?? 0;
                        final highestRating = entries
                            .map((r) => (r['rating'] as int?) ?? 0)
                            .reduce((a, b) => a > b ? a : b);

                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Challenge title bar
                            pw.Container(
                              decoration: const pw.BoxDecoration(
                                color: _C.navyMid,
                                borderRadius: pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(8),
                                  topRight: pw.Radius.circular(8),
                                ),
                              ),
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: pw.Row(
                                crossAxisAlignment:
                                pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Expanded(
                                    child: pw.Text(
                                      challenge,
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 12,
                                          color: _C.white),
                                    ),
                                  ),
                                  // Latest rating badge
                                  pw.Container(
                                    margin: const pw.EdgeInsets.only(left: 8),
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: pw.BoxDecoration(
                                      color: _ratingBg(latestRating),
                                      borderRadius:
                                      pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Row(
                                      mainAxisSize: pw.MainAxisSize.min,
                                      children: [
                                        pw.Text('Latest: ',
                                            style: pw.TextStyle(
                                                font: baseFont,
                                                fontSize: 8,
                                                color: _C.textSub)),
                                        pw.Text(
                                          '$latestRating - ${_ratingLabel(latestRating)}',
                                          style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 9,
                                              color: _ratingFg(latestRating)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Progress bar row
                            pw.Container(
                              color: _C.surface,
                              padding: const pw.EdgeInsets.fromLTRB(
                                  14, 12, 14, 12),
                              child: pw.Row(
                                children: [
                                  pw.Expanded(
                                    child: _ratingBar(
                                        latestRating, boldFont, baseFont),
                                  ),
                                  pw.SizedBox(width: 20),
                                  pw.Column(
                                    crossAxisAlignment:
                                    pw.CrossAxisAlignment.end,
                                    children: [
                                      pw.Text('Best achieved:',
                                          style: pw.TextStyle(
                                              font: baseFont,
                                              fontSize: 8,
                                              color: _C.textMuted)),
                                      pw.SizedBox(height: 3),
                                      pw.Container(
                                        padding:
                                        const pw.EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: pw.BoxDecoration(
                                          color: _ratingBg(highestRating),
                                          borderRadius:
                                          pw.BorderRadius.circular(4),
                                        ),
                                        child: pw.Text(
                                          '$highestRating - ${_ratingLabel(highestRating)}',
                                          style: pw.TextStyle(
                                              font: boldFont,
                                              fontSize: 9,
                                              color:
                                              _ratingFg(highestRating)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Observation table header
                            pw.Container(
                              color: PdfColor.fromInt(0xFF1F3A50),
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              child: pw.Row(
                                children: [
                                  pw.SizedBox(
                                    width: 72,
                                    child: pw.Text('DATE',
                                        style: pw.TextStyle(
                                            font: boldFont,
                                            fontSize: 8,
                                            color: _C.accent,
                                            letterSpacing: 0.5)),
                                  ),
                                  pw.SizedBox(
                                    width: 86,
                                    child: pw.Text('RATING',
                                        style: pw.TextStyle(
                                            font: boldFont,
                                            fontSize: 8,
                                            color: _C.accent,
                                            letterSpacing: 0.5)),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text('TEACHER NOTE',
                                        style: pw.TextStyle(
                                            font: boldFont,
                                            fontSize: 8,
                                            color: _C.accent,
                                            letterSpacing: 0.5)),
                                  ),
                                  pw.SizedBox(
                                    width: 22,
                                    child: pw.Text('AI',
                                        style: pw.TextStyle(
                                            font: boldFont,
                                            fontSize: 8,
                                            color: _C.accent,
                                            letterSpacing: 0.5),
                                        textAlign: pw.TextAlign.center),
                                  ),
                                ],
                              ),
                            ),

                            // Observation rows (newest first)
                            ...entries.reversed.toList().asMap().entries.map((e) {
                              final i = e.key;
                              final rec = e.value;
                              final date = rec['date'] ?? '';
                              final r = (rec['rating'] as int?) ?? 0;
                              final note = rec['teacherNote'] ?? 'No note';
                              final ai = rec['aiGenerated'] == true;
                              final isFirst = i == 0;
                              final isEven = i % 2 == 0;

                              return pw.Container(
                                decoration: pw.BoxDecoration(
                                  color: isFirst
                                      ? _C.greenLight
                                      : isEven
                                      ? _C.surface
                                      : _C.white,
                                  border: pw.Border(
                                    bottom: pw.BorderSide(
                                        color: _C.border, width: 0.5),
                                  ),
                                ),
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                child: pw.Row(
                                  crossAxisAlignment:
                                  pw.CrossAxisAlignment.center,
                                  children: [
                                    // Date + latest badge
                                    pw.SizedBox(
                                      width: 72,
                                      child: pw.Column(
                                        crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(date,
                                              style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 9,
                                                  color: _C.textPri)),
                                          if (isFirst)
                                            pw.Container(
                                              margin: const pw.EdgeInsets
                                                  .only(top: 3),
                                              padding:
                                              const pw.EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2),
                                              decoration: pw.BoxDecoration(
                                                color: _C.green
                                                    .shade(0.18),
                                                borderRadius:
                                                pw.BorderRadius.circular(
                                                    3),
                                              ),
                                              child: pw.Text('LATEST',
                                                  style: pw.TextStyle(
                                                      font: boldFont,
                                                      fontSize: 6,
                                                      color: _C.green,
                                                      letterSpacing:
                                                      0.5)),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Rating chip
                                    pw.SizedBox(
                                      width: 86,
                                      child: pw.Container(
                                        padding:
                                        const pw.EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                        decoration: pw.BoxDecoration(
                                          color: _ratingBg(r),
                                          borderRadius:
                                          pw.BorderRadius.circular(4),
                                        ),
                                        child: pw.Row(
                                          mainAxisSize: pw.MainAxisSize.min,
                                          children: [
                                            pw.Container(
                                              width: 16,
                                              height: 16,
                                              decoration: pw.BoxDecoration(
                                                color: _ratingFg(r),
                                                borderRadius:
                                                pw.BorderRadius.circular(
                                                    3),
                                              ),
                                              alignment:
                                              pw.Alignment.center,
                                              child: pw.Text('$r',
                                                  style: pw.TextStyle(
                                                      font: boldFont,
                                                      fontSize: 8,
                                                      color: _C.white)),
                                            ),
                                            pw.SizedBox(width: 5),
                                            pw.Flexible(
                                              child: pw.Text(
                                                _ratingLabel(r),
                                                style: pw.TextStyle(
                                                    font: boldFont,
                                                    fontSize: 7,
                                                    color: _ratingFg(r)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Note
                                    pw.Expanded(
                                      child: pw.Text(note,
                                          style: pw.TextStyle(
                                              font: baseFont,
                                              fontSize: 9,
                                              color: _C.textSub,
                                              lineSpacing: 1.5),
                                          maxLines: 3),
                                    ),

                                    // AI badge
                                    pw.SizedBox(
                                      width: 22,
                                      child: ai
                                          ? pw.Center(
                                        child: pw.Container(
                                          padding:
                                          const pw.EdgeInsets.symmetric(
                                              horizontal: 3,
                                              vertical: 2),
                                          decoration: pw.BoxDecoration(
                                            color: _C.tealLight,
                                            borderRadius:
                                            pw.BorderRadius.circular(
                                                3),
                                          ),
                                          child: pw.Text('AI',
                                              style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 7,
                                                  color: _C.teal),
                                              textAlign:
                                              pw.TextAlign.center),
                                        ),
                                      )
                                          : pw.SizedBox(),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            pw.SizedBox(height: 16),
                          ],
                        );
                      }),

                      pw.Spacer(),

                      // Rating scale legend
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: _C.surface,
                          borderRadius: pw.BorderRadius.circular(6),
                          border:
                          pw.Border.all(color: _C.border, width: 0.8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('RATING SCALE',
                                style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 8,
                                    color: _C.textSub,
                                    letterSpacing: 0.6)),
                            pw.SizedBox(height: 5),
                            pw.Row(
                              children: [
                                for (int r = 1; r <= 7; r++) ...[
                                  pw.Expanded(
                                    child: pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 4),
                                      decoration: pw.BoxDecoration(
                                        color: _ratingBg(r),
                                        borderRadius:
                                        pw.BorderRadius.circular(4),
                                      ),
                                      child: pw.Column(
                                        children: [
                                          pw.Text('$r',
                                              style: pw.TextStyle(
                                                  font: boldFont,
                                                  fontSize: 9,
                                                  color: _ratingFg(r)),
                                              textAlign: pw.TextAlign.center),
                                          pw.Text(
                                            _ratingLabelShort(r),
                                            style: pw.TextStyle(
                                                font: baseFont,
                                                fontSize: 6,
                                                color: _ratingFg(r)),
                                            textAlign: pw.TextAlign.center,
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (r < 7) pw.SizedBox(width: 4),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _pageFooter(studentName, '$pageNum', '$totalPages',
                  baseFont, boldFont),
            ],
          ),
        ),
      );
      pageNum++;
    }

    // Share
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
      '${studentName.replaceAll(' ', '_')}_Progress_Report.pdf',
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _statCard(String value, String label, PdfColor accent,
      pw.Font base, pw.Font bold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [accent, accent.shade(0.7)],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    font: bold, fontSize: 20, color: _C.white)),
            pw.SizedBox(height: 3),
            pw.Text(label,
                style: pw.TextStyle(
                    font: base,
                    fontSize: 8,
                    color: _C.white.shade(0.8),
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pageFooter(String studentName, String current,
      String total, pw.Font base, pw.Font bold) {
    return pw.Container(
      height: 36,
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_C.navy, _C.navyMid],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 40),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                  width: 6, height: 6,
                  decoration: const pw.BoxDecoration(
                      color: _C.teal, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 8),
              pw.Text('$studentName  |  Progress Report',
                  style: pw.TextStyle(
                      font: base,
                      fontSize: 8,
                      color: _C.textMuted)),
            ],
          ),
          pw.Text('Page $current of $total',
              style: pw.TextStyle(
                  font: bold, fontSize: 8, color: _C.textMuted)),
        ],
      ),
    );
  }

  static String _latestDate(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return 'N/A';
    final dates = records
        .map((r) => r['date']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toList()
      ..sort();
    return dates.isEmpty ? 'N/A' : dates.last;
  }

  static String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }
}

String _ratingLabelShort(int v) {
  switch (v) {
    case 1: return 'Below\nBaseline';
    case 2: return 'Baseline';
    case 3: return 'Beginning\n25%';
    case 4: return 'Improving\n50%';
    case 5: return 'Nearly\n75%';
    case 6: return 'Achieved';
    case 7: return 'Retained';
    default: return '';
  }
}