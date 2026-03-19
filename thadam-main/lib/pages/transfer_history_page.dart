// lib/pages/transfer_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TransferHistoryPage extends StatelessWidget {
  const TransferHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transferred Records"),
        backgroundColor: const Color(0xFF5A9BD8),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('transfer_history')
            .where('fromUser', isEqualTo: userId)
            .orderBy('date', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No transferred records yet.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
              docs[index].data() as Map<String, dynamic>;

              final studentName =
                  data['studentName'] ?? "Student";
              final toUserName =
                  data['toUserName'] ?? "User";
              final date =
              (data['date'] as Timestamp?)?.toDate();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(
                    vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.swap_horiz,
                    color: Colors.blue,
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Transferred to $toUserName\n"
                        "Date: ${date != null ? DateFormat('dd MMM yyyy').format(date) : ''}",
                  ),

                  onTap: () {
                    _showTransferDetails(context, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ================= DETAILS POPUP =================

  void _showTransferDetails(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final studentName =
        data['studentName'] ?? "Student";
    final toUserName =
        data['toUserName'] ?? "User";
    final date =
    (data['date'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Transfer Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _row("Student", studentName),
            _row("Transferred To", toUserName),
            _row(
              "Date",
              date != null
                  ? DateFormat('dd MMM yyyy')
                  .format(date)
                  : "",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$title:",
              style: const TextStyle(
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}