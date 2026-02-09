import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotifyPage extends StatelessWidget {
  const NotifyPage({super.key});

  Future<List<Widget>> _buildNotifications() async {
    final firestore = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    List<Widget> notifications = [];

    final studentsSnap = await firestore
        .collection('students')
        .where('createdBy', isEqualTo: uid)
        .get();

    for (var student in studentsSnap.docs) {
      final studentId = student.id;
      final studentData = student.data();
      final studentName = studentData['name'] ?? "Student";

      final recSnap = await firestore
          .collection('students')
          .doc(studentId)
          .collection('records')
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();

      // Skip if less than 2 records (not enough data to compare)
      if (recSnap.docs.length < 2) continue;

      final latest = recSnap.docs[0].data() as Map<String, dynamic>;
      final previous = recSnap.docs[1].data() as Map<String, dynamic>;

      int latestRating = latest['rating'] ?? 5;
      int prevRating = previous['rating'] ?? 5;
      String latestDate = latest['date'] ?? "";

      // 🔴 ALERT: stuck in 1-3 consecutively
      if (latestRating <= 3 && prevRating <= 3) {
        notifications.add(
          Card(
            color: Colors.red.shade50,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text(
                "Attention Required",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "$studentName has been rated ${latestRating} for consecutive entries (last on $latestDate). Please review.",
              ),
            ),
          ),
        );
      }

      // 🟢 CONGRATS: improved to 5
      if (latestRating == 5 && prevRating != 5) {
        notifications.add(
          Card(
            color: Colors.green.shade50,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.celebration, color: Colors.green),
              title: const Text(
                "Great Progress!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Congratulations! $studentName has improved to 5 stars on $latestDate 🎉",
              ),
            ),
          ),
        );
      }
    }

    if (notifications.isEmpty) {
      notifications.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No new notifications today.",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: const Color(0xFF5A9BD8),
      ),
      body: FutureBuilder<List<Widget>>(
        future: _buildNotifications(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: snapshot.data!,
          );
        },
      ),
    );
  }
}
