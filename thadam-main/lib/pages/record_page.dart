// lib/pages/record_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'student_details_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  bool ascending = true;
  String selectedStatus = "Active";
  bool _isChatbotOpen = false;

  // ---------------- PRIORITY + STATUS HANDLERS ----------------

  Future<void> _toggleStatus(String docId, String currentStatus) async {
    final newStatus = currentStatus == "Active" ? "Inactive" : "Active";
    await firestore.collection('students').doc(docId).update({
      'status': newStatus,
    });
  }

  Future<void> _togglePriority(String docId, bool isPriority) async {
    await firestore.collection('students').doc(docId).update({
      'isPriority': !isPriority,
    });
  }

  // ---------------- DELETE STUDENT ----------------

  Future<void> _deleteStudent(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Student"),
        content: const Text(
          "Are you sure you want to delete this student record?\n"
              "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      try {
        final storageRef =
        FirebaseStorage.instance.ref().child('students/$docId');
        final listResult = await storageRef.listAll();

        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (_) {}

      await firestore.collection('students').doc(docId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student deleted successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Delete failed")),
      );
    }
  }

  // ---------------- PDF GENERATION WITH CORRECT SUMMARY ----------------

  Future<void> _generateAndSharePdf(
      String studentId, Map<String, dynamic> student) async {
    try {
      await Permission.storage.request();

      final recordSnap = await firestore
          .collection('students')
          .doc(studentId)
          .collection('records')
          .orderBy('date')
          .get();

      // ===== GROUP RECORDS BY AREA OF SUPPORT =====
      Map<String, List<Map<String, dynamic>>> areaWiseRecords = {};

      // ===== CORRECT SUMMARY MAP: Area -> Challenge -> HIGHEST Rating =====
      Map<String, Map<String, int>> summaryMap = {};

      for (var doc in recordSnap.docs) {
        final d = doc.data();
        String area = d['areaOfSupport'] ?? "Other";
        String challenge = d['challenge'] ?? "Unknown";
        int rating = d['rating'] ?? 0;

        // Group by Area
        areaWiseRecords.putIfAbsent(area, () => []);
        areaWiseRecords[area]!.add(d);

        // ---- FIXED LOGIC: TAKE MAXIMUM RATING ----
        summaryMap.putIfAbsent(area, () => {});
        summaryMap[area]![challenge] =
        (summaryMap[area]![challenge] ?? 0) < rating
            ? rating
            : (summaryMap[area]![challenge] ?? rating);
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            // ===== TITLE =====
            pw.Center(
              child: pw.Text(
                "THADAM PROGRESS REPORT",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 12),

            // ===== STUDENT DETAILS =====
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "STUDENT DETAILS",
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _pdfRow('Name', student['name'] ?? ''),
                  _pdfRow('Age', student['age']?.toString() ?? ''),
                  _pdfRow('Gender', student['gender'] ?? ''),
                  _pdfRow('Disability', student['disability'] ?? ''),
                  _pdfRow('Phone Number', student['parentPhone'] ?? ''),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ================= SUMMARY REPORT =================
            pw.Text(
              "SUMMARY REPORT (Highest Rating per Challenge)",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),

            ...summaryMap.entries.map((areaEntry) {
              String area = areaEntry.key;
              Map<String, int> challenges = areaEntry.value;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "AREA OF SUPPORT: $area",
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                          children: [
                            _header("Challenge"),
                            _header("Highest Rating"),
                          ],
                        ),
                        ...challenges.entries.map((e) {
                          return pw.TableRow(children: [
                            _cell(e.key),
                            _cell(_ratingLabel(e.value)),
                          ]);
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 20),

            // ================= DETAILED PROGRESS =================
            pw.Text(
              "DETAILED PROGRESS Report (Date-wise Tracking)",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),

            ...areaWiseRecords.entries.map((entry) {
              String area = entry.key;
              List<Map<String, dynamic>> records = entry.value;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "AREA OF SUPPORT: $area",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(4),
                        2: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            _header('Date'),
                            _header('Challenge Observed'),
                            _header('Rating'),
                          ],
                        ),

                        ...records.map((d) {
                          int usedRating = d['rating'] ?? 0;

                          return pw.TableRow(children: [
                            _cell(d['date'] ?? ''),
                            _cell(d['challenge'] ?? ''),
                            _cell(_ratingLabel(usedRating)),
                          ]);
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 15),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Generated On: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${student['name']}_Thadam_Progress_Report.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("PDF Error: $e")));
    }
  }

  // ---------------- ADD STUDENT ----------------
  Future<void> _addStudentDialog() async {
    final formKey = GlobalKey<FormState>();
    String name = '',
        age = '',
        gender = '',
        disability = '',
        parentPhone = '';
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Student Profile"),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                      TextFormField(
                        decoration:
                        const InputDecoration(labelText: "Name"),
                        onChanged: (val) => name = val,
                        validator: (val) =>
                        val!.isEmpty ? 'Enter name' : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: "Age"),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => age = val,
                        validator: (val) =>
                        val!.isEmpty ? 'Enter age' : null,
                      ),
                      DropdownButtonFormField(
                        value: gender.isEmpty ? null : gender,
                        items: ['Male', 'Female', 'Other']
                            .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => gender = val!,
                        decoration:
                        const InputDecoration(labelText: "Gender"),
                        validator: (val) =>
                        val == null ? 'Select gender' : null,
                      ),
                      DropdownButtonFormField(
                        value: disability.isEmpty ? null : disability,
                        items: [
                          'Hearing Impairment',
                          'Visual Impairment',
                          'Locomotor Disability',
                          'Intellectual Disability',
                          'Autism Spectrum Disorder',
                          'Multiple Disability'
                        ]
                            .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => disability = val!,
                        decoration:
                        const InputDecoration(labelText: "Disability"),
                        validator: (val) =>
                        val == null ? 'Select disability' : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: "Parent Phone Number"),
                        keyboardType: TextInputType.phone,
                        onChanged: (val) => parentPhone = val,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter parent phone number';
                          }
                          if (!RegExp(r'^[0-9]{10}$')
                              .hasMatch(val)) {
                            return 'Enter valid 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final currentUserId = auth.currentUser!.uid;
                    await firestore.collection('students').add({
                      'name': name,
                      'age': age,
                      'gender': gender,
                      'disability': disability,
                      'parentPhone': parentPhone,
                      'createdAt': Timestamp.fromDate(selectedDate),
                      'createdBy': currentUserId,
                      'role': widget.userRole,
                      'status': 'Active',
                      'isPriority': false,
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        });
      },
    );
  }

  // ---------------- BUILD UI (UNCHANGED) ----------------
  @override
  Widget build(BuildContext context) {
    final currentUserId = auth.currentUser!.uid;

    Query query = firestore.collection('students');

    if (widget.userRole == 'parent') {
      String parentPhone =
          auth.currentUser!.email!.split('@').first;
      query = query
          .where('parentPhone', isEqualTo: parentPhone)
          .where('status', isEqualTo: 'Active');
    } else {
      query = query.where('createdBy', isEqualTo: currentUserId);

      if (widget.filter == "active") {
        query = query.where('status', isEqualTo: "Active");
      } else if (widget.filter == "priority") {
        query = query.where('isPriority', isEqualTo: true);
      } else {
        query = query.where('status', isEqualTo: selectedStatus);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Profiles"),
        backgroundColor: const Color(0xFF5A9BD8),
        actions: [
          if (widget.userRole != 'parent' &&
              widget.filter == "all")
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStatus,
                items: ['Active', 'Inactive']
                    .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null)
                    setState(() => selectedStatus = val);
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: "Sort by Name",
            onPressed: () =>
                setState(() => ascending = !ascending),
          ),
          if (widget.userRole != 'parent')
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addStudentDialog),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No student records found."));
          }

          List<DocumentSnapshot> docs =
              snapshot.data!.docs;

          docs.sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;

            final ap = ad['isPriority'] == true;
            final bp = bd['isPriority'] == true;

            if (ap && !bp) return -1;
            if (!ap && bp) return 1;

            return ascending
                ? (ad['name'] ?? '')
                .compareTo(bd['name'] ?? '')
                : (bd['name'] ?? '')
                .compareTo(ad['name'] ?? '');
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
              docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final status =
                  data['status'] ?? 'Active';
              final isPriority =
                  data['isPriority'] == true;

              return ListTile(
                leading: Icon(
                  isPriority
                      ? Icons.star
                      : Icons.circle,
                  color: isPriority
                      ? Colors.orange
                      : (status == "Active"
                      ? Colors.green
                      : Colors.grey),
                  size: 18,
                ),
                title: Text(data['name'] ?? ''),
                subtitle: Text(
                    "Age: ${data['age']} | ${data['gender']} | ${data['disability']}"),
                trailing: widget.userRole != 'parent'
                    ? PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'status') {
                      _toggleStatus(id, status);
                    } else if (val == 'priority') {
                      _togglePriority(id, isPriority);
                    } else if (val == 'share') {
                      _generateAndSharePdf(id, data);
                    } else if (val == 'delete') {
                      _deleteStudent(id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'status',
                      child: Text(status == "Active"
                          ? "Mark Inactive"
                          : "Mark Active"),
                    ),
                    PopupMenuItem(
                      value: 'priority',
                      child: Text(isPriority
                          ? "Remove Priority"
                          : "Set Priority"),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Text("Share Record"),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDetailPage(
                        studentId: id,
                        studentName: data['name'] ?? '',
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ================= PDF HELPERS =================

pw.Widget _pdfRow(String title, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(title,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 10))),
      ],
    ),
  );
}

pw.Widget _cell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );
}

pw.Widget _header(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold)),
  );
}

String _ratingLabel(int rating) {
  switch (rating) {
    case 1:
      return "1 - Severe";
    case 2:
      return "2 - High";
    case 3:
      return "3 - Moderate";
    case 4:
      return "4 - Mild";
    case 5:
      return "5 - Well Managed";
    default:
      return "Pending";
  }
}
