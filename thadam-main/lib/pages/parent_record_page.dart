import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_details_page.dart';

class ParentRecordPage extends StatefulWidget {
  final String parentPhone;
  final String userRole; // Should be "Parent"

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

  Future<List<DocumentSnapshot>> _fetchStudentRecords() async {
    if (widget.userRole != "Parent") return [];

    final snapshot = await _firestore
        .collection('students')
        .where('parentPhone', isEqualTo: widget.parentPhone)
        .get();

    return snapshot.docs;
  }

  // Fetch ONLY latest record for summary display
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _fetchStudentRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (widget.userRole != "Parent") {
          return const Scaffold(
            body: Center(
              child: Text(
                "Access Denied. Only parents can view this page.",
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          );
        }

        final students = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Your Child Records'),
            backgroundColor: const Color(0xFF5A9BD8),
          ),
          body: students.isEmpty
              ? const Center(
            child: Text(
              "No student records found for this parent.",
              style: TextStyle(fontSize: 16),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final studentData =
              students[index].data() as Map<String, dynamic>;
              final studentId = students[index].id;

              final name = studentData['name'] ??
                  studentData['studentName'] ??
                  'Unnamed';

              final disability =
                  studentData['disability'] ?? 'Not available';
              final gender =
                  studentData['gender'] ?? 'Not available';
              final age =
                  studentData['age']?.toString() ?? 'Not available';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Disability: $disability"),
                      Text("Gender: $gender"),
                      Text("Age: $age"),
                      const SizedBox(height: 10),

                      // === LATEST UPDATE SUMMARY ONLY ===
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchLatestRecord(studentId),
                        builder: (context, recordSnap) {
                          if (recordSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Text(
                                "Checking latest update...");
                          }

                          if (recordSnap.hasError) {
                            return Text(
                                "Error: ${recordSnap.error}");
                          }

                          final latest = recordSnap.data;

                          if (latest == null) {
                            return const Text(
                              "No updates recorded yet.",
                              style: TextStyle(
                                  fontStyle: FontStyle.italic),
                            );
                          }

                          final date =
                              latest['date'] ?? "Unknown date";
                          final rating =
                              latest['rating']?.toString() ??
                                  "N/A";

                          return Padding(
                            padding:
                            const EdgeInsets.only(top: 8),
                            child: Text(
                              "🟢 On $date, rating was updated to $rating.",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StudentDetailPage(
                                    studentId: studentId,
                                    studentName: name,
                                    userRole: "Parent",
                                  ),
                            ),
                          );
                        },
                        child: const Text(
                            "View Full Details & Progress"),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
