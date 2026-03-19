// lib/pages/record_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'student_details_page.dart';
import 'pdf_report_service.dart';                    // ← NEW
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (matches student_detail_page.dart)
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
  static const amber     = Color(0xFFFFC300);

  static InputDecoration inputDec(String label,
      {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: textSub)
            : null,
        labelStyle: const TextStyle(color: textSub, fontSize: 14),
        hintStyle: TextStyle(color: textSub.withOpacity(0.6), fontSize: 14),
        filled: true,
        fillColor: surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border, width: 1.2)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border, width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: teal, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: red, width: 1.2)),
      );
}

// ─────────────────────────────────────────────────────────────
//  SHARED CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────
Future<bool?> _confirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _T.red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: _T.red, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _T.textPri))),
              ]),
              const SizedBox(height: 16),
              Text(body,
                  style: const TextStyle(
                      fontSize: 14, color: _T.textSub, height: 1.6)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _T.textSub,
                          side: const BorderSide(color: _T.border, width: 1.2),
                          padding:
                          const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    )),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: danger ? _T.red : _T.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                          const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: Text(confirmLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    )),
              ]),
            ],
          ),
        ),
      ),
    );

// ─────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 6),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: _T.textSub)),
  );
}

// ─────────────────────────────────────────────────────────────
//  DISABILITY CHIP
// ─────────────────────────────────────────────────────────────
class _DisabilityChip extends StatelessWidget {
  final String label;
  const _DisabilityChip(this.label);

  static (Color, Color) _color(String l) {
    if (l.contains('Autism'))       return (const Color(0xFFEDE9FE), const Color(0xFF6D28D9));
    if (l.contains('Intellectual')) return (const Color(0xFFE0F2FE), const Color(0xFF0369A1));
    if (l.contains('Hearing'))      return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
    if (l.contains('Visual'))       return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    if (l.contains('Locomotor'))    return (const Color(0xFFFFE4E6), const Color(0xFFBE123C));
    if (l.contains('Multiple'))     return (const Color(0xFFF3F4F6), const Color(0xFF374151));
    return (_T.tealLight, _T.teal);
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _color(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: isActive
              ? _T.green.withOpacity(0.12)
              : _T.textSub.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive
                  ? _T.green.withOpacity(0.35)
                  : _T.textSub.withOpacity(0.20),
              width: 1.2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: isActive ? _T.green : _T.textSub,
                shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? _T.green : _T.textSub)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RECORD PAGE
// ─────────────────────────────────────────────────────────────
class RecordPage extends StatefulWidget {
  final String userRole;
  final String filter;

  const RecordPage({
    super.key,
    required this.userRole,
    this.filter = "all",
  });

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final _fs   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool   _ascending      = true;
  String _selectedStatus = "Active";
  String _searchQuery    = "";
  final  _searchCtrl     = TextEditingController();

  // Track which student cards are generating a PDF
  final Set<String> _generatingPdf = {};

  // ── Toggle helpers ───────────────────────────────────────────
  Future<void> _toggleStatus(String id, String current) =>
      _fs.collection('students').doc(id).update(
          {'status': current == 'Active' ? 'Inactive' : 'Active'});

  Future<void> _togglePriority(String id, bool current) =>
      _fs.collection('students').doc(id).update({'isPriority': !current});

  // ── Delete ───────────────────────────────────────────────────
  Future<void> _deleteStudent(String id) async {
    final ok = await _confirmDialog(
      context: context,
      title: 'Delete Student',
      body: 'Are you sure you want to permanently delete this student record?\nThis action cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok != true) return;

    try {
      try {
        final ref = FirebaseStorage.instance.ref().child('students/$id');
        final list = await ref.listAll();
        for (final item in list.items) await item.delete();
      } catch (_) {}

      await _fs.collection('students').doc(id).delete();
      if (!mounted) return;
      _snack('Student deleted successfully');
    } catch (e) {
      _snack('Delete failed');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 14)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _T.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  // ─────────────────────────────────────────────────────────────
  //  PDF  — now delegates to PdfReportService
  // ─────────────────────────────────────────────────────────────
  Future<void> _generatePdf(
      String studentId, Map<String, dynamic> student) async {
    if (_generatingPdf.contains(studentId)) return;
    setState(() => _generatingPdf.add(studentId));

    try {
      await Permission.storage.request();

      // Fetch all records ordered by date
      final snap = await _fs
          .collection('students')
          .doc(studentId)
          .collection('records')
          .orderBy('date')
          .get();

      final records = snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      await PdfReportService.generate(
        studentName: student['name']        ?? 'Unknown',
        studentId:   studentId,
        disability:  student['disability']  ?? 'Not specified',
        gender:      student['gender']      ?? 'Not specified',
        age:         student['age']?.toString() ?? 'N/A',
        phone:       student['parentPhone'] ?? '',
        schoolName:  'Thadam',              // ← change to your school name
        allRecords:  records,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('PDF Error: $e');
    } finally {
      if (mounted) setState(() => _generatingPdf.remove(studentId));
    }
  }

  // ── Transfer ─────────────────────────────────────────────────
  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Future<void> _showTransferDialog(
      String studentId, Map<String, dynamic> student) async {
    String selectedRole = 'Therapist';
    String? selectedUserId;
    String? selectedUserName;
    List<QueryDocumentSnapshot> users = [];

    Future<void> loadUsers(String role) async {
      final snap = await _fs
          .collection('users')
          .where('userType', isEqualTo: role)
          .get();
      users = snap.docs;
    }

    await loadUsers(selectedRole);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(builder: (ctx, setD) {
          return Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
                decoration: const BoxDecoration(
                    color: _T.navy,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.swap_horiz_rounded,
                      color: _T.accent, size: 26),
                  const SizedBox(width: 12),
                  const Text('Transfer Student',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close,
                          color: Colors.white54, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                ]),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: _T.tealLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _T.teal.withOpacity(0.3), width: 1.2)),
                        child: Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 18, color: _T.teal),
                          const SizedBox(width: 10),
                          Text(student['name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _T.teal)),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      const _SectionLabel('TRANSFER TO ROLE'),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: _T.inputDec('Role'),
                        items: ['Therapist', 'Teacher', 'Special Educator']
                            .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(_cap(r),
                                style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (val) async {
                          selectedRole   = val!;
                          selectedUserId = null;
                          await loadUsers(selectedRole);
                          setD(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      const _SectionLabel('SELECT USER'),
                      DropdownButtonFormField<String>(
                        hint: const Text('Choose a user',
                            style: TextStyle(fontSize: 14)),
                        value: selectedUserId,
                        decoration: _T.inputDec('User'),
                        items: users.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                              value: d['uid'],
                              child: Text(d['name'] ?? 'User',
                                  style: const TextStyle(fontSize: 14)));
                        }).toList(),
                        onChanged: (val) {
                          selectedUserId = val;
                          final doc = users.firstWhere(
                                  (d) => (d.data() as Map)['uid'] == val);
                          selectedUserName = (doc.data() as Map)['name'];
                          setD(() {});
                        },
                      ),
                    ]),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                    color: _T.surface,
                    border: const Border(
                        top: BorderSide(color: _T.border, width: 1.2)),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20))),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _T.textSub,
                            side: const BorderSide(
                                color: _T.border, width: 1.2),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz_rounded,
                            size: 20),
                        label: const Text('Transfer',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: selectedUserId != null
                                ? _T.teal
                                : _T.textSub.withOpacity(0.3),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: selectedUserId == null
                            ? null
                            : () async {
                          await _transferStudent(studentId, student,
                              selectedUserId!, selectedUserName!);
                          if (!mounted) return;
                          Navigator.pop(ctx);
                        },
                      )),
                ]),
              ),
            ]),
          );
        }),
      ),
    );
  }

  Future<void> _transferStudent(String studentId,
      Map<String, dynamic> student, String toId, String toName) async {
    final fromId = _auth.currentUser!.uid;
    if (fromId == toId) {
      _snack('Cannot transfer to yourself');
      return;
    }
    try {
      final oldRef = _fs.collection('students').doc(studentId);
      final records = await oldRef.collection('records').get();

      final newRef = await _fs.collection('students').add({
        ...student,
        'createdBy':        toId,
        'transferredFrom':  fromId,
        'transferredDate':  Timestamp.now(),
      });

      for (var r in records.docs) {
        await newRef.collection('records').add(r.data());
      }

      await _fs.collection('transfer_history').add({
        'studentName':  student['name'],
        'studentOldId': studentId,
        'studentNewId': newRef.id,
        'fromUser':     fromId,
        'toUser':       toId,
        'toUserName':   toName,
        'date':         Timestamp.now(),
      });

      for (var r in records.docs) await r.reference.delete();
      await oldRef.delete();

      if (!mounted) return;
      _snack('Student transferred successfully');
    } catch (e) {
      _snack('Transfer failed: $e');
    }
  }

  // ── Add Student Dialog ────────────────────────────────────────
  Future<void> _addStudentDialog() async {
    final formKey = GlobalKey<FormState>();
    String name = '', age = '', gender = '', disability = '',
        parentPhone = '';
    DateTime selDate = DateTime.now();

    const disabilityOptions = [
      'Hearing Impairment', 'Visual Impairment', 'Locomotor Disability',
      'Intellectual Disability', 'Autism Spectrum Disorder',
      'Multiple Disability',
    ];

    List<String> multipleSelected = [];
    bool showMultiple = false;

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(builder: (ctx, setD) {
          return Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
                decoration: const BoxDecoration(
                    color: _T.navy,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded,
                      color: _T.accent, size: 26),
                  const SizedBox(width: 12),
                  const Text('Add Student Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close,
                          color: Colors.white54, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                ]),
              ),

              // ── Body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('DATE OF ENROLMENT'),
                          InkWell(
                            onTap: () async {
                              final p = await showDatePicker(
                                context: ctx,
                                initialDate: selDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (c, child) => Theme(
                                    data: ThemeData.light().copyWith(
                                        colorScheme:
                                        const ColorScheme.light(
                                            primary: _T.teal)),
                                    child: child!),
                              );
                              if (p != null) setD(() => selDate = p);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                  color: _T.surface,
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _T.border, width: 1.2)),
                              child: Row(children: [
                                const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                    color: _T.teal),
                                const SizedBox(width: 12),
                                Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(selDate),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const Spacer(),
                                const Icon(Icons.chevron_right,
                                    size: 20, color: _T.textSub),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 18),
                          const _SectionLabel('STUDENT DETAILS'),
                          TextFormField(
                            decoration: _T.inputDec('Full Name',
                                icon: Icons.badge_outlined),
                            style: const TextStyle(fontSize: 14),
                            onChanged: (v) => name = v,
                            validator: (v) =>
                            v!.isEmpty ? 'Enter name' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            decoration: _T.inputDec('Age',
                                icon: Icons.cake_outlined),
                            style: const TextStyle(fontSize: 14),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => age = v,
                            validator: (v) =>
                            v!.isEmpty ? 'Enter age' : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: gender.isEmpty ? null : gender,
                            decoration: _T.inputDec('Gender'),
                            items: ['Male', 'Female', 'Other']
                                .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e,
                                    style: const TextStyle(
                                        fontSize: 14))))
                                .toList(),
                            onChanged: (v) =>
                                setD(() => gender = v!),
                            validator: (v) =>
                            v == null ? 'Select gender' : null,
                          ),
                          const SizedBox(height: 14),

                          const _SectionLabel('DISABILITY'),
                          DropdownButtonFormField<String>(
                            value: disability.isEmpty ? null : disability,
                            decoration: _T.inputDec('Type'),
                            items: disabilityOptions
                                .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e,
                                    style: const TextStyle(
                                        fontSize: 14))))
                                .toList(),
                            onChanged: (v) {
                              disability   = v!;
                              showMultiple = v == 'Multiple Disability';
                              if (!showMultiple) multipleSelected.clear();
                              setD(() {});
                            },
                            validator: (v) =>
                            v == null ? 'Select disability' : null,
                          ),

                          if (showMultiple) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: _T.surface,
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _T.border, width: 1.2)),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('Select all that apply',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _T.textSub,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  ...disabilityOptions
                                      .where((e) =>
                                  e != 'Multiple Disability')
                                      .map((e) => CheckboxListTile(
                                    dense: true,
                                    title: Text(e,
                                        style: const TextStyle(
                                            fontSize: 14)),
                                    value: multipleSelected
                                        .contains(e),
                                    activeColor: _T.teal,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (v) => setD(() {
                                      v == true
                                          ? multipleSelected.add(e)
                                          : multipleSelected.remove(e);
                                    }),
                                  )),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),
                          const _SectionLabel('CONTACT'),
                          TextFormField(
                            decoration: _T.inputDec(
                                'Parent Phone Number',
                                icon: Icons.phone_outlined),
                            style: const TextStyle(fontSize: 14),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) => parentPhone = v,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter phone number';
                              }
                              if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) {
                                return 'Enter valid 10-digit number';
                              }
                              return null;
                            },
                          ),
                        ]),
                  ),
                ),
              ),

              // ── Footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                    color: _T.surface,
                    border: const Border(
                        top: BorderSide(color: _T.border, width: 1.2)),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20))),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _T.textSub,
                            side: const BorderSide(
                                color: _T.border, width: 1.2),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10))),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded,
                            size: 20),
                        label: const Text('Add Student',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _T.teal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10))),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          await _fs.collection('students').add({
                            'name':        name,
                            'age':         age,
                            'gender':      gender,
                            'disability':  showMultiple
                                ? multipleSelected.join(', ')
                                : disability,
                            'parentPhone': parentPhone,
                            'createdAt':   Timestamp.fromDate(selDate),
                            'createdBy':   _auth.currentUser!.uid,
                            'role':        widget.userRole,
                            'status':      'Active',
                            'isPriority':  false,
                          });
                          if (!mounted) return;
                          Navigator.pop(ctx);
                        },
                      )),
                ]),
              ),
            ]),
          );
        }),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser!.uid;

    Query query = _fs.collection('students');

    if (widget.userRole == 'parent') {
      final phone = _auth.currentUser!.email!.split('@').first;
      query = query
          .where('parentPhone', isEqualTo: phone)
          .where('status', isEqualTo: 'Active');
    } else {
      query = query.where('createdBy', isEqualTo: userId);
      if (widget.filter == 'active') {
        query = query.where('status', isEqualTo: 'Active');
      } else if (widget.filter == 'priority') {
        query = query.where('isPriority', isEqualTo: true);
      } else {
        query = query.where('status', isEqualTo: _selectedStatus);
      }
    }

    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student Profiles',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text(
                widget.filter == 'priority'
                    ? 'Priority students'
                    : widget.filter == 'active'
                    ? 'Active students'
                    : '${_selectedStatus.toLowerCase()} students',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white54)),
          ],
        ),
        actions: [
          // Status filter dropdown
          if (widget.userRole != 'parent' && widget.filter == 'all')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    dropdownColor: _T.navyLight,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    icon: const Icon(Icons.expand_more,
                        color: Colors.white70, size: 20),
                    items: ['Active', 'Inactive']
                        .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedStatus = v);
                    },
                  ),
                ),
              ),
            ),

          // Sort button
          IconButton(
            icon: Icon(
                _ascending
                    ? Icons.sort_by_alpha_rounded
                    : Icons.sort_rounded,
                size: 22),
            tooltip: 'Sort by name',
            onPressed: () => setState(() => _ascending = !_ascending),
          ),

          // Add student
          if (widget.userRole != 'parent')
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _addStudentDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _T.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ),
        ],
      ),

      body: Column(children: [

        // ── Search bar ──────────────────────────────────────────
        Container(
          color: _T.navy,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search students…',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.white54, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // ── Student list ────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: _T.teal));
              }

              var docs = snap.data!.docs;

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded,
                            size: 60,
                            color: _T.textSub.withOpacity(0.35)),
                        const SizedBox(height: 14),
                        const Text('No students found',
                            style: TextStyle(
                                color: _T.textSub,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ]),
                );
              }

              // Sort: priority first, then name
              docs.sort((a, b) {
                final ad = a.data() as Map<String, dynamic>;
                final bd = b.data() as Map<String, dynamic>;
                final ap = ad['isPriority'] == true;
                final bp = bd['isPriority'] == true;
                if (ap && !bp) return -1;
                if (!ap && bp) return 1;
                return _ascending
                    ? (ad['name'] ?? '').compareTo(bd['name'] ?? '')
                    : (bd['name'] ?? '').compareTo(ad['name'] ?? '');
              });

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final doc  = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final id         = doc.id;
                  final status     = data['status'] ?? 'Active';
                  final isPriority = data['isPriority'] == true;

                  return _StudentCard(
                    name:        data['name'] ?? '',
                    age:         data['age']?.toString() ?? '',
                    gender:      data['gender'] ?? '',
                    disability:  data['disability'] ?? '',
                    status:      status,
                    isPriority:  isPriority,
                    isParent:    widget.userRole == 'parent',
                    isGeneratingPdf: _generatingPdf.contains(id),  // ← NEW
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudentDetailPage(
                                studentId:   id,
                                studentName: data['name'] ?? '',
                                userRole:    widget.userRole))),
                    onStatus:    () => _toggleStatus(id, status),
                    onPriority:  () => _togglePriority(id, isPriority),
                    onShare:     () => _generatePdf(id, data),
                    onTransfer:  () => _showTransferDialog(id, data),
                    onDelete:    () => _deleteStudent(id),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STUDENT CARD WIDGET
// ─────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final String name, age, gender, disability, status;
  final bool isPriority, isParent, isGeneratingPdf;
  final VoidCallback onTap, onStatus, onPriority, onShare,
      onTransfer, onDelete;

  const _StudentCard({
    required this.name,
    required this.age,
    required this.gender,
    required this.disability,
    required this.status,
    required this.isPriority,
    required this.isParent,
    required this.isGeneratingPdf,
    required this.onTap,
    required this.onStatus,
    required this.onPriority,
    required this.onShare,
    required this.onTransfer,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _T.card,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPriority
                  ? _T.amber.withOpacity(0.45)
                  : _T.border,
              width: isPriority ? 1.5 : 1.2,
            ),
          ),
          child: Column(children: [

            // ── Top row ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPriority
                        ? _T.amber.withOpacity(0.15)
                        : _T.tealLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isPriority ? _T.amber : _T.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + chips
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _T.textPri)),
                          ),
                          if (isPriority) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: _T.amber.withOpacity(0.15),
                                  borderRadius:
                                  BorderRadius.circular(4)),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 11, color: _T.amber),
                                    SizedBox(width: 4),
                                    Text('Priority',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: _T.amber)),
                                  ]),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text('$age yrs · $gender',
                            style: const TextStyle(
                                fontSize: 13,
                                color: _T.textSub,
                                fontWeight: FontWeight.w500)),
                      ]),
                ),

                // Menu — show spinner on the PDF item while generating
                if (!isParent)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: _T.textSub),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onSelected: (v) {
                      switch (v) {
                        case 'status':   onStatus();   break;
                        case 'priority': onPriority(); break;
                        case 'share':    onShare();    break;
                        case 'transfer': onTransfer(); break;
                        case 'delete':   onDelete();   break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'status',
                          child: Row(children: [
                            Icon(
                                status == 'Active'
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                                size: 18,
                                color: _T.textSub),
                            const SizedBox(width: 10),
                            Text(
                                'Mark ${status == 'Active' ? 'Inactive' : 'Active'}',
                                style: const TextStyle(fontSize: 14)),
                          ])),
                      PopupMenuItem(
                          value: 'priority',
                          child: Row(children: [
                            Icon(
                                isPriority
                                    ? Icons.star_border_rounded
                                    : Icons.star_rounded,
                                size: 18,
                                color: _T.amber),
                            const SizedBox(width: 10),
                            Text(
                                isPriority
                                    ? 'Remove Priority'
                                    : 'Set Priority',
                                style: const TextStyle(fontSize: 14)),
                          ])),
                      const PopupMenuDivider(),
                      // ── Share Report — live spinner while building ──
                      PopupMenuItem(
                          value: 'share',
                          child: Row(children: [
                            isGeneratingPdf
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _T.teal),
                            )
                                : const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: _T.teal),
                            const SizedBox(width: 10),
                            Text(
                                isGeneratingPdf
                                    ? 'Building report…'
                                    : 'Share Report',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isGeneratingPdf
                                        ? _T.textSub
                                        : _T.textPri)),
                          ])),
                      const PopupMenuItem(
                          value: 'transfer',
                          child: Row(children: [
                            Icon(Icons.swap_horiz_rounded,
                                size: 18, color: _T.teal),
                            SizedBox(width: 10),
                            Text('Transfer Student',
                                style: TextStyle(fontSize: 14)),
                          ])),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: _T.red),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(
                                    color: _T.red, fontSize: 14)),
                          ])),
                    ],
                  ),
              ]),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: _T.border),

            // ── Bottom row ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: disability
                        .split(',')
                        .map((d) => _DisabilityChip(d.trim()))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 12),
                // Show a tiny PDF spinner on the card itself too
                if (isGeneratingPdf) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _T.teal),
                  ),
                  const SizedBox(width: 8),
                ],
                _StatusBadge(status),
              ]),
            ),

            // ── Tap hint ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 12),
              child: Row(children: const [
                Spacer(),
                Text('View progress →',
                    style: TextStyle(
                        fontSize: 12,
                        color: _T.teal,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}