import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

import 'profile_page.dart';
import 'record_page.dart';
import 'notify_page.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (matches admin_dashboard_page.dart exactly)
// ─────────────────────────────────────────────────────────────
class _T {
  static const navy      = Color(0xFF0D1B2A);
  static const navyMid   = Color(0xFF1B2E42);
  static const teal      = Color(0xFF0A9396);
  static const tealLight = Color(0xFFD9F0F1);
  static const accent    = Color(0xFF94D2BD);
  static const surface   = Color(0xFFF4F6F9);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE4EAF0);
  static const textPri   = Color(0xFF0D1B2A);
  static const textSub   = Color(0xFF6B7A8D);
  static const red       = Color(0xFFE63946);
  static const orange    = Color(0xFFF4A261);
  static const green     = Color(0xFF2DC653);
  static const amber     = Color(0xFFFFC300);
  static const blue      = Color(0xFF3A78C2);
  static const purple    = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────────────────────
//  DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────
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
  final auth      = FirebaseAuth.instance;

  int _selectedIndex = 0;

  int totalStudents    = 0;
  int activeStudents   = 0;
  int priorityStudents = 0;
  int needsAttention   = 0;

  Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  bool loading = true;
  StreamSubscription? _studentSub;

  // ── init / dispose ────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    loading = false;
    _listenDashboardData();
  }

  @override
  void dispose() {
    _studentSub?.cancel();
    super.dispose();
  }

  // ── realtime listener ─────────────────────────────────────
  void _listenDashboardData() {
    final user = auth.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    _studentSub = firestore
        .collection('students')
        .where('createdBy', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) async {
      int total    = snap.docs.length;
      int active   = 0;
      int priority = 0;
      int attention = 0;
      Map<int, int> tempDist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var doc in snap.docs) {
        final d = doc.data();
        if (d['status'] == 'Active') active++;
        if (d['isPriority'] == true) priority++;

        final latestSnap = await firestore
            .collection('students')
            .doc(doc.id)
            .collection('records')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (latestSnap.docs.isNotEmpty) {
          final ld = latestSnap.docs.first.data() as Map<String, dynamic>;
          final int latestRating = (ld['rating'] ?? 5) as int;
          final String latestDate = ld['date'] ?? '';

          await firestore.collection('students').doc(doc.id).update({
            'latestRating':     latestRating,
            'latestRatingDate': latestDate,
          });

          tempDist[latestRating] = (tempDist[latestRating] ?? 0) + 1;
          if (latestRating <= 3) attention++;
        }
      }

      if (!mounted) return;
      setState(() {
        totalStudents    = total;
        activeStudents   = active;
        priorityStudents = priority;
        needsAttention   = attention;
        ratingDistribution = tempDist;
        loading          = false;
      });
    });
  }

  // ── weekly average ratings ────────────────────────────────
  Future<Map<String, double>> _getWeeklyAverageRatings() async {
    final user = auth.currentUser;
    if (user == null) return {};

    Map<String, List<int>> dailyRatings = {};
    final today = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      dailyRatings[DateFormat('yyyy-MM-dd').format(day)] = [];
    }

    final studentsSnap = await firestore
        .collection('students')
        .where('createdBy', isEqualTo: user.uid)
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
        final date   = d['date'] as String;
        final rating = (d['rating'] ?? 0) as int;
        if (dailyRatings.containsKey(date)) {
          dailyRatings[date]!.add(rating);
        }
      }
    }

    return dailyRatings.map((date, ratings) => MapEntry(
      date,
      ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length,
    ));
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final currentDay = DateFormat('EEEE').format(DateTime.now());
    final dateStr    = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: _T.surface,
      appBar: _buildAppBar(currentDay, dateStr),
      body: _selectedIndex == 0
          ? _homeDashboard()
          : _notificationsPlaceholder(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── app bar ───────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(String day, String date) {
    return AppBar(
      backgroundColor: _T.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Row(children: [
        // avatar
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _T.teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: _T.teal,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${widget.name.split(' ').first}!',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Happy $day  •  $date',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ]),
      actions: [
        // role badge
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _T.teal.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _T.teal.withOpacity(0.35)),
          ),
          child: Text(
            widget.whoYouAre,
            style: const TextStyle(
              color: _T.teal,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── bottom nav ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        border: Border(top: BorderSide(color: _T.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: _T.navy.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.transparent,
        selectedItemColor: _T.teal,
        unselectedItemColor: _T.textSub.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
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

  // ═══════════════════════════════════════════════════════════
  //  HOME DASHBOARD
  // ═══════════════════════════════════════════════════════════
  Widget _homeDashboard() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _T.teal));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [

        // ── STAT CARDS ──────────────────────────────────────
        _sectionLabel('My Students', Icons.group_rounded),
        const SizedBox(height: 10),
        Row(children: [
          _StatCard(
            label: 'Total',
            value: totalStudents,
            icon: Icons.group_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF3A78C2), Color(0xFF2563A8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            onTap: () => _pushRecords('all'),
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Active',
            value: activeStudents,
            icon: Icons.check_circle_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF2DC653), Color(0xFF1FA040)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            onTap: () => _pushRecords('active'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard(
            label: 'Priority',
            value: priorityStudents,
            icon: Icons.star_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFF4A261), Color(0xFFE08040)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            onTap: () => _pushRecords('priority'),
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Attention',
            value: needsAttention,
            icon: Icons.warning_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFE63946), Color(0xFFBF2D33)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            onTap: _openNeedsAttentionList,
          ),
        ]),

        const SizedBox(height: 26),

        // ── PROGRESS SUMMARY ─────────────────────────────────
        _sectionLabel('Progress Summary', Icons.bar_chart_rounded),
        const SizedBox(height: 10),
        _progressSummaryCard(),

        const SizedBox(height: 26),

        // ── WEEKLY CHART ─────────────────────────────────────
        _sectionLabel('Weekly Performance Trend', Icons.trending_up_rounded),
        const SizedBox(height: 10),
        _weeklyChartCard(),

        const SizedBox(height: 26),

        // ── RATING DISTRIBUTION ──────────────────────────────
        _sectionLabel('Rating Distribution', Icons.pie_chart_rounded),
        const SizedBox(height: 10),
        _ratingDistributionCard(),

        const SizedBox(height: 26),

        // ── QUICK ACTIONS ────────────────────────────────────
        _sectionLabel('Quick Actions', Icons.bolt_rounded),
        const SizedBox(height: 10),
        _quickActionsCard(),

        const SizedBox(height: 10),
      ],
    );
  }

  // ── section label ─────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: _T.teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _T.teal, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _T.textPri,
        ),
      ),
    ]);
  }

  // ── progress summary card ─────────────────────────────────
  Widget _progressSummaryCard() {
    final total = ratingDistribution.values.reduce((a, b) => a + b);
    final goodCount = (ratingDistribution[4] ?? 0) + (ratingDistribution[5] ?? 0);
    final atRisk    = (ratingDistribution[1] ?? 0) + (ratingDistribution[2] ?? 0);
    final goodPct   = total == 0 ? 0.0 : goodCount / total;
    final atRiskPct = total == 0 ? 0.0 : atRisk / total;

    return _Card(
      child: Column(children: [
        // top row — 3 mini summary tiles
        Row(children: [
          _SummaryTile(
            label: 'Well\nManaged',
            value: goodCount,
            color: _T.green,
            icon: Icons.trending_up_rounded,
          ),
          _vertDivider(),
          _SummaryTile(
            label: 'In\nProgress',
            value: ratingDistribution[3] ?? 0,
            color: _T.amber,
            icon: Icons.sync_rounded,
          ),
          _vertDivider(),
          _SummaryTile(
            label: 'Needs\nAttention',
            value: atRisk,
            color: _T.red,
            icon: Icons.warning_rounded,
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(height: 1, color: _T.border),
        const SizedBox(height: 14),
        // progress bars
        _progressBarRow('Well Managed', goodPct, _T.green),
        const SizedBox(height: 8),
        _progressBarRow('Needs Attention', atRiskPct, _T.red),
      ]),
    );
  }

  Widget _vertDivider() => Container(
    width: 1, height: 48, color: _T.border.withOpacity(0.7),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );

  Widget _progressBarRow(String label, double pct, Color color) {
    return Row(children: [
      SizedBox(
        width: 110,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _T.textSub)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: Colors.grey.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 36,
        child: Text(
          '${(pct * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ]);
  }

  // ── weekly chart card ─────────────────────────────────────
  Widget _weeklyChartCard() {
    return FutureBuilder<Map<String, double>>(
      future: _getWeeklyAverageRatings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _Card(
            child: SizedBox(
              height: 220,
              child: const Center(
                  child: CircularProgressIndicator(
                      color: _T.teal, strokeWidth: 2)),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _Card(
            child: const SizedBox(
              height: 80,
              child: Center(
                child: Text('No chart data available',
                    style: TextStyle(color: _T.textSub, fontSize: 13)),
              ),
            ),
          );
        }

        return _Card(child: _buildBarChart(snapshot.data!));
      },
    );
  }

  Widget _buildBarChart(Map<String, double> data) {
    final dates  = data.keys.toList()..sort();
    final values = dates.map((d) => data[d]!).toList();

    // legend
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // mini legend
        Row(children: [
          _legendDot(_T.green, 'Good (≥4)'),
          const SizedBox(width: 14),
          _legendDot(_T.orange, 'Mid (2–4)'),
          const SizedBox(width: 14),
          _legendDot(_T.red, 'Low (<2)'),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 6,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _T.navy,
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    '${rod.toY.toStringAsFixed(1)}★',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      const labels = {
                        1: 'Below', 2: 'Base', 3: 'Begin',
                        4: 'Good',  5: 'Well',
                      };
                      final label = labels[value.toInt()];
                      if (label == null) return const SizedBox.shrink();
                      return Text(label,
                          style: const TextStyle(
                              fontSize: 8, color: _T.textSub));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, _) {
                      final i = value.toInt();
                      if (i < 0 || i >= dates.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MM/dd')
                              .format(DateTime.parse(dates[i])),
                          style: const TextStyle(
                              fontSize: 9, color: _T.textSub),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: _T.border.withOpacity(0.4), strokeWidth: 0.8),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(values.length, (i) {
                final v = values[i];
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: v,
                    width: 22,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                    color: _getBarColor(v),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 6,
                      color: _T.border.withOpacity(0.15),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(fontSize: 10, color: _T.textSub)),
    ]);
  }

  Color _getBarColor(double value) {
    if (value == 0) return _T.border;
    if (value < 2)  return _T.red;
    if (value < 4)  return _T.orange;
    return _T.green;
  }

  // ── rating distribution card ──────────────────────────────
  Widget _ratingDistributionCard() {
    final rows = [
      ('Below Baseline (1)', ratingDistribution[1]!, _T.red),
      ('Baseline (2)',        ratingDistribution[2]!, _T.orange),
      ('Beginning (3)',       ratingDistribution[3]!, _T.amber),
      ('Improving (4)',       ratingDistribution[4]!, _T.teal),
      ('Well Managed (5)',    ratingDistribution[5]!, _T.green),
    ];

    final maxCount = ratingDistribution.values.reduce((a, b) => a > b ? a : b);

    return _Card(
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i     = entry.key;
          final label = entry.value.$1;
          final count = entry.value.$2;
          final color = entry.value.$3;
          final pct   = maxCount == 0 ? 0.0 : count / maxCount;

          return Column(children: [
            if (i > 0) const SizedBox(height: 12),
            Row(children: [
              // color dot + label
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _T.textPri)),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 7,
                backgroundColor: color.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  // ── quick actions card ────────────────────────────────────
  Widget _quickActionsCard() {
    final actions = [
      (
      icon: Icons.assignment_rounded,
      color: _T.teal,
      bg: _T.tealLight,
      title: 'View All Student Records',
      sub: 'Browse and manage all student observations',
      onTap: () => _pushRecords('all'),
      ),
      (
      icon: Icons.star_rounded,
      color: _T.orange,
      bg: const Color(0xFFFEF3E2),
      title: 'Priority Students',
      sub: 'View students marked as high priority',
      onTap: () => _pushRecords('priority'),
      ),
      (
      icon: Icons.warning_rounded,
      color: _T.red,
      bg: const Color(0xFFFEECEE),
      title: 'Needs Attention',
      sub: 'Students with rating ≤ 3',
      onTap: _openNeedsAttentionList,
      ),
    ];

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: actions.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Column(children: [
            if (i > 0)
              const Divider(height: 1, indent: 54, color: _T.border),
            InkWell(
              onTap: a.onTap,
              borderRadius: BorderRadius.circular(
                  i == 0 ? 14 : (i == actions.length - 1 ? 14 : 0)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: a.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(a.icon, color: a.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _T.textPri)),
                        const SizedBox(height: 2),
                        Text(a.sub,
                            style: const TextStyle(
                                fontSize: 11, color: _T.textSub)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: _T.textSub, size: 13),
                ]),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  // ── notifications placeholder ─────────────────────────────
  Widget _notificationsPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _T.teal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                size: 36, color: _T.teal.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _T.textSub)),
          const SizedBox(height: 6),
          const Text('You\'re all caught up!',
              style: TextStyle(fontSize: 13, color: _T.textSub)),
        ],
      ),
    );
  }

  // ── navigation ────────────────────────────────────────────
  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const NotifyPage()));
    } else if (index == 2) {
      _pushRecords('all');
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePage(
            name: widget.name, age: widget.age,
            mobile: widget.mobile, gender: widget.gender,
            whoYouAre: widget.whoYouAre,
          ),
        ),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  void _pushRecords(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordPage(userRole: widget.whoYouAre, filter: filter),
      ),
    );
  }

  void _openNeedsAttentionList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NeedsAttentionListPage()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED CARD WIDGET
// ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: _T.navy.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STAT CARD  (gradient pill with icon + value)
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // icon chip
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(height: 14),
              // value
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              // label + arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (onTap != null)
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white70,
                          size: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUMMARY TILE  (used inside progress summary card)
// ─────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(height: 7),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _T.textSub,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  NEEDS ATTENTION LIST PAGE  (redesigned to match new UI)
// ═══════════════════════════════════════════════════════════════
class NeedsAttentionListPage extends StatelessWidget {
  NeedsAttentionListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final user      = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _T.surface,
        appBar: AppBar(
          title: const Text('Needs Attention'),
          backgroundColor: _T.navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        title: const Text('Needs Attention',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .where('createdBy', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // ── loading ──
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _T.teal));
          }

          // ── error ──
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: _T.red.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('Error loading students',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _T.textPri)),
                  const SizedBox(height: 4),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: _T.textSub)),
                ]),
              ),
            );
          }

          final all = snapshot.data?.docs ?? [];
          final atRisk = all.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return ((d['latestRating'] ?? 5) as int) <= 3;
          }).toList();

          // ── empty ──
          if (atRisk.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _T.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.done_all_rounded,
                      size: 36, color: _T.green.withOpacity(0.7)),
                ),
                const SizedBox(height: 14),
                const Text('All students are doing well!',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _T.textSub)),
              ]),
            );
          }

          // ── header + list ──
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: atRisk.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _T.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _T.red.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_rounded,
                            color: _T.red, size: 14),
                        const SizedBox(width: 5),
                        Text('${atRisk.length} students need attention',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _T.red)),
                      ]),
                    ),
                  ]),
                );
              }

              final d = atRisk[i - 1].data() as Map<String, dynamic>;
              final rating = (d['latestRating'] ?? 0) as int;
              final isLow  = rating <= 1;
              final color  = isLow ? _T.red : _T.orange;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _T.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _T.border),
                  boxShadow: [
                    BoxShadow(
                      color: _T.navy.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        // avatar
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              (d['name'] ?? 'S')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // name + date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['name'] ?? 'Student',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _T.textPri)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 11, color: _T.textSub),
                                const SizedBox(width: 4),
                                Text(
                                    'Last: ${d['latestRatingDate'] ?? 'N/A'}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _T.textSub)),
                              ]),
                            ],
                          ),
                        ),
                        // rating badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$rating★',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLow ? 'Critical' : 'At Risk',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: color),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: _T.textSub, size: 13),
                      ]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}