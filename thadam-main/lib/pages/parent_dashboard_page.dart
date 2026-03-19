import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import 'parent_record_page.dart';
import 'profile_page.dart';

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

class ParentDashboardPage extends StatefulWidget {
  final String name;
  final String age;
  final String mobile;
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
  String? _expandedGraphStudentId;

  @override
  void initState() {
    super.initState();
    if (widget.whoYouAre != 'Parent') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        _showSnackBar('Access denied: Only parents can view this page');
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _T.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
      setState(() => _selectedIndex = index);
    }
  }

  Stream<QuerySnapshot> _childrenStream() {
    return _firestore
        .collection('students')
        .where('parentPhone', isEqualTo: widget.mobile)
        .snapshots();
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

  Widget _buildChallengeGraph(
      String studentId,
      String challenge,
      List<QueryDocumentSnapshot> docs,
      ) {
    List<BarChartGroupData> barGroups = [];
    List<String> xLabels = [];

    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      double rating = (data['rating'] ?? 0).toDouble();
      String date = data['date'] ?? "";

      String formattedDate;
      try {
        formattedDate = DateFormat('MMM dd').format(DateTime.parse(date));
      } catch (_) {
        formattedDate = date;
      }

      xLabels.add(formattedDate);
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rating,
              width: 16,
              color: _T.teal,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$challenge Progress',
            style: const TextStyle(
              fontSize: 17, // was 13
              fontWeight: FontWeight.w700,
              color: _T.textPri,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: 5,
                minY: 0,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 14, // was 10
                            color: _T.textSub,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= xLabels.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            xLabels[index],
                            style: const TextStyle(
                              fontSize: 13, // was 9
                              color: _T.textSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _T.border.withOpacity(0.5),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: _T.border, width: 1),
                    left: BorderSide(color: _T.border, width: 1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Date → Rating ↑',
            style: TextStyle(
              fontSize: 14, // was 10
              color: _T.textSub,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllGraphsForStudent(String studentId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('students')
          .doc(studentId)
          .collection('records')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No progress data available',
              style: TextStyle(
                fontSize: 16, // was 12
                color: _T.textSub,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        Map<String, List<QueryDocumentSnapshot>> groupedByChallenge = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          String challenge = data['challenge'] ?? 'Other';

          if (!groupedByChallenge.containsKey(challenge)) {
            groupedByChallenge[challenge] = [];
          }
          groupedByChallenge[challenge]!.add(doc);
        }

        return Column(
          children: groupedByChallenge.entries.map((entry) {
            return _buildChallengeGraph(studentId, entry.key, entry.value);
          }).toList(),
        );
      },
    );
  }

  Widget _childSummaryCard(String studentId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed';
    final disability = data['disability'] ?? 'Not specified';
    final age = data['age']?.toString() ?? 'N/A';
    bool isExpanded = _expandedGraphStudentId == studentId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
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
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_T.navy, _T.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _T.teal.withOpacity(0.3),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18, // was 14
                      fontWeight: FontWeight.w800,
                      color: _T.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18, // was 14
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Child',
                        style: TextStyle(
                          fontSize: 14, // was 10
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disability',
                            style: TextStyle(
                              fontSize: 14, // was 10
                              fontWeight: FontWeight.w600,
                              color: _T.textSub,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            disability,
                            style: const TextStyle(
                              fontSize: 16, // was 12
                              fontWeight: FontWeight.w600,
                              color: _T.textPri,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Age',
                            style: TextStyle(
                              fontSize: 14, // was 10
                              fontWeight: FontWeight.w600,
                              color: _T.textSub,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            age,
                            style: const TextStyle(
                              fontSize: 16, // was 12
                              fontWeight: FontWeight.w600,
                              color: _T.textPri,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Latest Update
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLatestRecord(studentId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _T.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const SizedBox(
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _T.teal,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    final latest = snap.data;
                    if (latest == null) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _T.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _T.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: _T.textSub,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No updates recorded yet',
                                style: TextStyle(
                                  fontSize: 16, // was 12
                                  color: _T.textSub,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final date = latest['date'] ?? 'Unknown date';
                    final rating = latest['rating']?.toString() ?? 'N/A';
                    final note =
                        latest['teacherNote'] ?? 'No teacher note available';

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _T.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _T.green.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: _T.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Latest Update',
                                style: TextStyle(
                                  fontSize: 14, // was 10
                                  fontWeight: FontWeight.w600,
                                  color: _T.textSub,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'On $date • Rating: $rating',
                            style: const TextStyle(
                              fontSize: 16, // was 12
                              fontWeight: FontWeight.w600,
                              color: _T.green,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Teacher: $note',
                            style: TextStyle(
                              fontSize: 15, // was 11
                              color: _T.textSub,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _expandedGraphStudentId =
                            isExpanded ? null : studentId;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _T.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isExpanded ? 'Hide Graphs' : 'View Graphs',
                          style: const TextStyle(
                            fontSize: 16, // was 12
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _T.teal,
                          side: const BorderSide(color: _T.teal, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'View Records',
                          style: TextStyle(
                            fontSize: 16, // was 12
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (isExpanded) ...[
                  const SizedBox(height: 14),
                  _buildAllGraphsForStudent(studentId),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifications() {
    return StreamBuilder<QuerySnapshot>(
      stream: _childrenStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _T.tealLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      size: 48,
                      color: _T.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Notifications',
                    style: TextStyle(
                      fontSize: 20, // was 16
                      fontWeight: FontWeight.w700,
                      color: _T.textPri,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updates will appear here when available',
                    style: TextStyle(
                      fontSize: 17, // was 13
                      color: _T.textSub,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final studentId = doc.id;
            final name = data['name'] ?? 'Child';

            return FutureBuilder<Map<String, dynamic>?>(
              future: _fetchLatestRecord(studentId),
              builder: (context, snap) {
                String message = 'No updates yet';
                if (snap.data != null) {
                  final latest = snap.data!;
                  final date = latest['date'] ?? 'Unknown date';
                  final rating = latest['rating']?.toString() ?? 'N/A';
                  final enteredBy = latest['enteredByName'] ?? 'Staff';
                  message =
                  '$name rated $rating on $date by $enteredBy';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _T.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _T.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _T.tealLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          size: 16,
                          color: _T.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$name - Progress Update',
                              style: const TextStyle(
                                fontSize: 16, // was 12
                                fontWeight: FontWeight.w700,
                                color: _T.textPri,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 15, // was 11
                                color: _T.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentDay = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Text(
          'Hi ${widget.name}, Happy $currentDay!',
          style: const TextStyle(
            fontSize: 20, // was 16
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _selectedIndex == 0
          ? StreamBuilder<QuerySnapshot>(
        stream: _childrenStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _T.teal),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _T.tealLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.child_care_rounded,
                        size: 48,
                        color: _T.teal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Children Found',
                      style: TextStyle(
                        fontSize: 20, // was 16
                        fontWeight: FontWeight.w700,
                        color: _T.textPri,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No children linked to this parent account.',
                      style: TextStyle(
                        fontSize: 17, // was 13
                        color: _T.textSub,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            children: [
              const Text(
                "Your Child's Dashboard",
                style: TextStyle(
                  fontSize: 20, // was 16
                  fontWeight: FontWeight.w700,
                  color: _T.textPri,
                ),
              ),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _childSummaryCard(doc.id, data);
              }).toList(),
            ],
          );
        },
      )
          : _selectedIndex == 1
          ? _buildNotifications()
          : const SizedBox(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: _T.card,
        selectedItemColor: _T.teal,
        unselectedItemColor: _T.textSub,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'Notify',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}