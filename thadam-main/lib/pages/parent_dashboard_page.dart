import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'parent_record_page.dart';
import 'profile_page.dart';
import 'student_details_page.dart';

class ParentDashboardPage extends StatefulWidget {
  final String name;
  final String age;
  final String mobile; // Used to link students
  final String gender;
  final String whoYouAre;

  const ParentDashboardPage({
    super.key,
    required this.name,
    required this.age,
    required this.mobile,
    required this.gender,
    required this.whoYouAre,
  });

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    if (widget.whoYouAre != 'Parent') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: Only parents can view this page'),
          ),
        );
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParentRecordPage(
            parentPhone: widget.mobile,
            userRole: widget.whoYouAre,
          ),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(
            name: widget.name,
            age: widget.age,
            mobile: widget.mobile,
            gender: widget.gender,
            whoYouAre: widget.whoYouAre,
          ),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Fetch all children linked to this parent
  Stream<QuerySnapshot> _childrenStream() {
    return _firestore
        .collection('students')
        .where('parentPhone', isEqualTo: widget.mobile)
        .snapshots();
  }

  // Fetch latest record for a child
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

  Widget _childSummaryCard(String studentId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed';
    final disability = data['disability'] ?? 'Not available';
    final age = data['age']?.toString() ?? 'N/A';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.child_care, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // BASIC INFO
            Row(
              children: [
                Expanded(child: Text("Disability: $disability")),
                Text("Age: $age"),
              ],
            ),

            const SizedBox(height: 12),

            // LATEST UPDATE
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchLatestRecord(studentId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Text("Checking latest update...");
                }

                final latest = snap.data;
                if (latest == null) {
                  return const Text(
                    "No updates recorded yet.",
                    style: TextStyle(fontStyle: FontStyle.italic),
                  );
                }

                final date = latest['date'] ?? "Unknown date";
                final rating = latest['rating']?.toString() ?? "N/A";

                return Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "On $date, rating was updated to $rating.",
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // PROGRESS PREVIEW LABEL
            const Text(
              "Progress Preview",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),

            // STATUS BAR PREVIEW
            FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('students')
                  .doc(studentId)
                  .collection('records')
                  .orderBy('timestamp', descending: false)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 24,
                    child: LinearProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text("No progress yet");
                }

                final ratings = docs
                    .map((e) =>
                (e.data() as Map<String, dynamic>)['rating'] ?? 0)
                    .toList();

                double avg =
                    ratings.reduce((a, b) => a + b) / ratings.length;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentDetailPage(
                          studentId: studentId,
                          studentName: name,
                          userRole: "Parent",
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: avg / 5,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Recent: ${ratings.take(4).join(" → ")}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // ACTION BUTTONS (FIXED WHITE TEXT)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white, // ✅ WHITE TEXT
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDetailPage(
                            studentId: studentId,
                            studentName: name,
                            userRole: "Parent",
                          ),
                        ),
                      );
                    },
                    child: const Text("View Graphs"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParentRecordPage(
                            parentPhone: widget.mobile,
                            userRole: widget.whoYouAre,
                          ),
                        ),
                      );
                    },
                    child: const Text("View Records"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentDay = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text("Hi ${widget.name}, Happy $currentDay!"),
        backgroundColor: const Color(0xFF5A9BD8),
        centerTitle: true,
      ),
      body: _selectedIndex == 0
          ? StreamBuilder<QuerySnapshot>(
        stream: _childrenStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No children linked to this parent.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Your Child Dashboard",
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data =
                doc.data() as Map<String, dynamic>;
                return _childSummaryCard(doc.id, data);
              }).toList(),
            ],
          );
        },
      )
          : const Center(
        child: Text(
          "Notifications will appear here.",
          style: TextStyle(fontSize: 18),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF5A9BD8),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Notify'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Records'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
