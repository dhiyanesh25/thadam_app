import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

import 'profile_page.dart';
import 'record_page.dart';
import 'notify_page.dart';

class DashboardPage extends StatefulWidget {
  final String name;
  final String age;
  final String mobile;
  final String gender;
  final String whoYouAre;

  const DashboardPage({
    super.key,
    required this.name,
    required this.age,
    required this.mobile,
    required this.gender,
    required this.whoYouAre,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  int _selectedIndex = 0;

  int totalStudents = 0;
  int activeStudents = 0;
  int priorityStudents = 0;
  int needsAttention = 0;

  Map<int, int> ratingDistribution = {
    1: 0,
    2: 0,
    3: 0,
    4: 0,
    5: 0,
  };

  bool loading = true;
  StreamSubscription? _studentSub;

  @override
  void initState() {
    super.initState();
    loading = false; // ✅ Show UI immediately
    _listenDashboardData();
  }

  @override
  void dispose() {
    _studentSub?.cancel();
    super.dispose();
  }

  // ================= REALTIME LISTENER (SAFE) =================
  void _listenDashboardData() {
    final user = auth.currentUser;
    if (user == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    final uid = user.uid;

    _studentSub = firestore
        .collection('students')
        .where('createdBy', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      int total = snap.docs.length;
      int active = 0;
      int priority = 0;
      int attention = 0;

      Map<int, int> tempDist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var doc in snap.docs) {
        final d = doc.data();

        if (d['status'] == 'Active') active++;
        if (d['isPriority'] == true) priority++;

        final latestRecSnap = await firestore
            .collection('students')
            .doc(doc.id)
            .collection('records')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (latestRecSnap.docs.isNotEmpty) {
          final latestData =
          latestRecSnap.docs.first.data() as Map<String, dynamic>;

          int latestRating = latestData['rating'] ?? 5;
          String latestDate = latestData['date'];

          await firestore.collection('students').doc(doc.id).update({
            'latestRating': latestRating,
            'latestRatingDate': latestDate,
          });

          tempDist[latestRating] =
              (tempDist[latestRating] ?? 0) + 1;

          if (latestRating <= 3) {
            attention++;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        totalStudents = total;
        activeStudents = active;
        priorityStudents = priority;
        needsAttention = attention;
        ratingDistribution = tempDist;
        loading = false;
      });
    });
  }

  // ================== WEEKLY AVERAGE DATA (SAFE) ==================
  Future<Map<String, double>> _getWeeklyAverageRatings() async {
    final user = auth.currentUser;
    if (user == null) return {};

    final uid = user.uid;
    Map<String, List<int>> dailyRatings = {};

    DateTime today = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime day = today.subtract(Duration(days: i));
      String formattedDate = DateFormat('yyyy-MM-dd').format(day);
      dailyRatings[formattedDate] = [];
    }

    final studentsSnap = await firestore
        .collection('students')
        .where('createdBy', isEqualTo: uid)
        .get();

    for (var student in studentsSnap.docs) {
      final recSnap = await firestore
          .collection('students')
          .doc(student.id)
          .collection('records')
          .where('date', whereIn: dailyRatings.keys.toList())
          .get();

      for (var rec in recSnap.docs) {
        final d = rec.data();
        String date = d['date'];
        int rating = d['rating'] ?? 0;

        if (dailyRatings.containsKey(date)) {
          dailyRatings[date]!.add(rating);
        }
      }
    }

    Map<String, double> avgRatings = {};

    dailyRatings.forEach((date, ratings) {
      if (ratings.isNotEmpty) {
        avgRatings[date] =
            ratings.reduce((a, b) => a + b) / ratings.length.toDouble();
      } else {
        avgRatings[date] = 0;
      }
    });

    return avgRatings;
  }

  // ================== BAR CHART ==================
  Widget _ratingBarChart(Map<String, double> data) {
    List<String> dates = data.keys.toList()..sort();
    List<double> values = dates.map((d) => data[d]!).toList();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 5,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 1:
                      return const Text("Severe",
                          style: TextStyle(fontSize: 10));
                    case 2:
                      return const Text("High",
                          style: TextStyle(fontSize: 10));
                    case 3:
                      return const Text("Moderate",
                          style: TextStyle(fontSize: 10));
                    case 4:
                      return const Text("Mild",
                          style: TextStyle(fontSize: 10));
                    case 5:
                      return const Text("Well Managed",
                          style: TextStyle(fontSize: 10));
                    default:
                      return const Text("");
                  }
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < dates.length) {
                    return Text(
                      DateFormat('dd/MM')
                          .format(DateTime.parse(dates[index])),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          barGroups: List.generate(
            values.length,
                (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================== RATING DISTRIBUTION VISUAL ==================
  Widget _ratingDistributionVisual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Current Rating Distribution",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _distRow("Severe (1)", ratingDistribution[1]!, Colors.red),
                _distRow("High (2)", ratingDistribution[2]!, Colors.orange),
                _distRow(
                    "Moderate (3)", ratingDistribution[3]!, Colors.amber),
                _distRow(
                    "Mild (4)", ratingDistribution[4]!, Colors.greenAccent),
                _distRow(
                    "Well Managed (5)", ratingDistribution[5]!, Colors.green),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _distRow(String label, int count, Color color) {
    int maxCount =
    ratingDistribution.values.reduce((a, b) => a > b ? a : b);
    double widthFactor = maxCount == 0 ? 0 : count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 5,
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ================== NAVIGATION ==================
  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotifyPage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecordPage(
            userRole: widget.whoYouAre,
            filter: "all",
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

  void _openNeedsAttentionList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NeedsAttentionListPage(),
      ),
    );
  }

  Widget _statCard(String title, int value, Color color, IconData icon,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(height: 6),
              Text(title,
                  style:
                  const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeDashboard() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _statCard(
              "Total Students",
              totalStudents,
              Colors.blue,
              Icons.group,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordPage(
                      userRole: widget.whoYouAre,
                      filter: "all",
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _statCard(
              "Active",
              activeStudents,
              Colors.green,
              Icons.check_circle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordPage(
                      userRole: widget.whoYouAre,
                      filter: "active",
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard(
              "Priority",
              priorityStudents,
              Colors.orange,
              Icons.star,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecordPage(
                      userRole: widget.whoYouAre,
                      filter: "priority",
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _statCard(
              "Needs Attention",
              needsAttention,
              Colors.red,
              Icons.warning,
              onTap: _openNeedsAttentionList,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Weekly Performance Trend",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, double>>(
          future: _getWeeklyAverageRatings(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Text("Loading chart..."));
            }

            if (snapshot.hasError) {
              return Center(child: Text("Chart Error: ${snapshot.error}"));
            }

            if (!snapshot.hasData) {
              return const Center(child: Text("No chart data"));
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ratingBarChart(snapshot.data!),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _ratingDistributionVisual(),
        const SizedBox(height: 20),
        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.assignment),
          title: const Text("View Student Records"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordPage(
                  userRole: widget.whoYouAre,
                  filter: "all",
                ),
              ),
            );
          },
        ),
      ],
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
          ? _homeDashboard()
          : const Center(
        child: Text(
          "Notifications will appear here.",
          style: TextStyle(fontSize: 18),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Notify'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Records'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ================== NEEDS ATTENTION LIST PAGE ==================
class NeedsAttentionListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Needs Attention Students"),
        backgroundColor: const Color(0xFF5A9BD8),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .where('createdBy', isEqualTo: uid)
            .where('latestRating', isLessThanOrEqualTo: 3)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No students need attention",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.red),
                  title: Text(d['name'] ?? "Student"),
                  subtitle: Text(
                    "Latest Rating: ${d['latestRating']}  •  "
                        "Date: ${d['latestRatingDate']}",
                  ),
                  trailing:
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
