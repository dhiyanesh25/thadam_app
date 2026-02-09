// ======================= FINAL PROFESSIONAL MANAGEMENT DASHBOARD =======================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String expandedRole = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text("Management Dashboard"),
        backgroundColor: const Color(0xFF3A78C2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminProfilePage()),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _keyMetricsGrid(),
          const SizedBox(height: 16),
          const Text(
            "Staff Overview",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _expandableStaffSection("Teacher", Icons.person),
          _expandableStaffSection("Special Educator", Icons.school),
          _expandableStaffSection("Therapist", Icons.medical_services),
        ],
      ),
    );
  }

  Widget _keyMetricsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        int teachers =
            users.where((d) => d['userType'] == 'Teacher').length;
        int therapists =
            users.where((d) => d['userType'] == 'Therapist').length;
        int se =
            users.where((d) => d['userType'] == 'Special Educator').length;

        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('students').snapshots(),
          builder: (context, studentSnap) {
            int totalStudents =
            studentSnap.hasData ? studentSnap.data!.docs.length : 0;

            return StreamBuilder<QuerySnapshot>(
              stream: firestore.collectionGroup('records').snapshots(),
              builder: (context, recordSnap) {
                int totalRecords =
                recordSnap.hasData ? recordSnap.data!.docs.length : 0;

                return GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    _metricCard(
                      "Teachers",
                      teachers,
                      Colors.blue,
                      Icons.person,
                      onTap: () => _openRolePage(context, "Teacher"),
                    ),
                    _metricCard(
                      "Therapists",
                      therapists,
                      Colors.green,
                      Icons.medical_services,
                      onTap: () => _openRolePage(context, "Therapist"),
                    ),
                    _metricCard(
                      "Special Educators",
                      se,
                      Colors.orange,
                      Icons.school,
                      onTap: () =>
                          _openRolePage(context, "Special Educator"),
                    ),
                    _metricCard(
                      "Total Students",
                      totalStudents,
                      Colors.purple,
                      Icons.child_care,
                    ),
                    _metricCard(
                      "Total Records",
                      totalRecords,
                      Colors.teal,
                      Icons.assignment,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _openRolePage(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleStaffPage(role: role),
      ),
    );
  }

  Widget _expandableStaffSection(String role, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Colors.blue),
            title: Text(
              role,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(
              expandedRole == role
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            onTap: () {
              setState(() {
                expandedRole = expandedRole == role ? "" : role;
              });
            },
          ),
          if (expandedRole == role)
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('users')
                  .where('userType', isEqualTo: role)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final staff = snapshot.data!.docs;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Total $role: ${staff.length}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: staff.length,
                      itemBuilder: (context, index) {
                        final data =
                        staff[index].data() as Map<String, dynamic>;

                        final String uid = data['uid'];

                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(data['name'] ?? ''),
                          subtitle:
                          Text("📞 ${data['mobile'] ?? 'No contact'}"),
                          trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffEntriesPage(
                                  staffName: data['name'] ?? '',
                                  uid: uid,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _metricCard(
      String title, int value, Color color, IconData icon,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= ROLE STAFF PAGE ================= */

class RoleStaffPage extends StatelessWidget {
  final String role;

  const RoleStaffPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("$role List"),
        backgroundColor: const Color(0xFF3A78C2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .where('userType', isEqualTo: role)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final staff = snapshot.data!.docs;

          return ListView.builder(
            itemCount: staff.length,
            itemBuilder: (context, index) {
              final data = staff[index].data() as Map<String, dynamic>;
              final String uid = data['uid'];

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(data['name'] ?? ''),
                  subtitle:
                  Text("📞 ${data['mobile'] ?? 'No contact available'}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffEntriesPage(
                          staffName: data['name'] ?? '',
                          uid: uid,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* ================= STAFF ENTRIES PAGE (NO whereIn — NO LIMIT) ================= */

class StaffEntriesPage extends StatelessWidget {
  final String staffName;
  final String uid;

  const StaffEntriesPage({
    super.key,
    required this.staffName,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("$staffName - Students"),
        backgroundColor: const Color(0xFF3A78C2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collectionGroup('records')
            .where('enteredByUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, recordSnap) {
          if (recordSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!recordSnap.hasData || recordSnap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No records entered by this staff.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final records = recordSnap.data!.docs;

          final Set<String> studentIds = records
              .map((r) =>
          (r.data() as Map<String, dynamic>)['studentId'] as String)
              .toSet();

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: studentIds.length,
            itemBuilder: (context, index) {
              final String studentId = studentIds.elementAt(index);

              return FutureBuilder<DocumentSnapshot>(
                future:
                firestore.collection('students').doc(studentId).get(),
                builder: (context, studentSnap) {
                  if (!studentSnap.hasData) {
                    return const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()));
                  }

                  final studentData =
                  studentSnap.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading:
                      const Icon(Icons.child_care, color: Colors.blue),
                      title: Text(
                        studentData['name'] ?? 'Student',
                        style:
                        const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Age: ${studentData['age'] ?? ''} | "
                            "Disability: ${studentData['disability'] ?? ''}",
                      ),
                      trailing:
                      const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentAreaProgressPage(
                              studentId: studentId,
                              studentName:
                              studentData['name'] ?? 'Student',
                              uid: uid,
                            ),
                          ),
                        );
                      },
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

/* ================= STUDENT AREA PROGRESS PAGE ================= */

class StudentAreaProgressPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String uid;

  const StudentAreaProgressPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName - Records & Progress"),
        backgroundColor: const Color(0xFF3A78C2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .doc(studentId)
            .collection('records')
            .where('enteredByUid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No records entered by this staff for this student.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final records = snapshot.data!.docs;

          Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (var r in records) {
            final d = r.data() as Map<String, dynamic>;
            String area = d['areaOfSupport'] ?? "Other";
            grouped.putIfAbsent(area, () => []).add(r);
          }

          return ListView(
            padding: const EdgeInsets.all(10),
            children: grouped.entries.map((entry) {
              String area = entry.key;
              List<QueryDocumentSnapshot> areaRecords = entry.value;

              int r1 = 0, r2 = 0, r3 = 0, r4 = 0, r5 = 0;
              double avg = 0;

              for (var r in areaRecords) {
                final d = r.data() as Map<String, dynamic>;
                int rating = (d['rating'] ?? 0);
                avg += rating;

                if (rating == 1) r1++;
                if (rating == 2) r2++;
                if (rating == 3) r3++;
                if (rating == 4) r4++;
                if (rating == 5) r5++;
              }

              avg = avg / areaRecords.length;
              double progress = avg / 5.0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ExpansionTile(
                  leading:
                  const Icon(Icons.psychology, color: Colors.indigo),
                  title: Text(area,
                      style:
                      const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                  Text("Total entries: ${areaRecords.length}"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Progress",
                              style:
                              TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 8),
                          Text(
                              "1★:$r1  2★:$r2  3★:$r3  4★:$r4  5★:$r5"),
                          const Divider(),
                        ],
                      ),
                    ),
                    ...areaRecords.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.assignment,
                            color: Colors.teal),
                        title: Text(d['challenge'] ?? "No challenge"),
                        subtitle:
                        Text("Rating: ${d['rating'] ?? 'N/A'} ★"),
                        trailing: Text(
                          d['timestamp'] is Timestamp
                              ? DateFormat('dd-MM-yyyy')
                              .format((d['timestamp'] as Timestamp)
                              .toDate())
                              : d['date'] ?? "",
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/* ================= ADMIN PROFILE PAGE ================= */

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF3A78C2),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                color: const Color(0xFF3A78C2),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person,
                          size: 50, color: Colors.blue),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['name'] ?? 'Admin',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      data['userType'] ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _logout(context),
                      child: const Text("Logout"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
