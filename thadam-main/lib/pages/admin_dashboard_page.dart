// =============================================================================
//  ADMIN DASHBOARD  —  PROFESSIONAL UI  (matches DashboardPage design system)
//  pubspec.yaml:  fl_chart: ^0.68.0  |  cloud_firestore  |  firebase_auth
//                 shared_preferences  |  intl
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'login_page.dart';

// ─────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (identical to dashboard_page.dart)
// ─────────────────────────────────────────────────────────────────────
const _navy        = Color(0xFF0D1B2A);
const _teal        = Color(0xFF0A9396);
const _surface     = Color(0xFFF0F3F7);
const _card        = Color(0xFFFFFFFF);
const _border      = Color(0xFFE2E8F0);
const _borderSoft  = Color(0xFFF1F5F9);
const _textPri     = Color(0xFF0D1B2A);
const _textSub     = Color(0xFF64748B);
const _textHint    = Color(0xFF94A3B8);
const _green       = Color(0xFF059669);
const _greenLight  = Color(0xFFD1FAE5);
const _red         = Color(0xFFDC2626);
const _redLight    = Color(0xFFFEE2E2);
const _orange      = Color(0xFFD97706);
const _orangeLight = Color(0xFFFEF3C7);
const _amber       = Color(0xFFF59E0B);
const _blue        = Color(0xFF2563EB);
const _blueLight   = Color(0xFFDBEAFE);
const _purple      = Color(0xFF7C3AED);
const _purpleLight = Color(0xFFEDE9FE);

const _gradNavy = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C)],
    begin: Alignment.topLeft, end: Alignment.bottomRight);

Color _ratingColor(double v) {
  if (v >= 0.75) return _green;
  if (v >= 0.5)  return _amber;
  return _red;
}

// ─────────────────────────────────────────────────────────────────────
//  ADMIN DASHBOARD PAGE
// ─────────────────────────────────────────────────────────────────────
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final _fs = FirebaseFirestore.instance;
  late TabController _tabs;
  String _expandedRole = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy').format(DateTime.now());
    return Scaffold(
      backgroundColor: _surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: Container(
          decoration: const BoxDecoration(gradient: _gradNavy),
          child: SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 0),
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: _teal.withOpacity(0.45), width: 1.5),
                  ),
                  child: const Center(child: Text('✦',
                      style: TextStyle(color: Color(0xFF94D2BD),
                          fontSize: 18, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Management Dashboard',
                        style: TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(date, style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ],
                )),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AdminProfilePage())),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          color: Colors.white, size: 18)),
                ),
              ]),
            ),
            TabBar(
              controller: _tabs,
              indicatorColor: _teal,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Staff'),
                Tab(text: 'Students'),
              ],
            ),
          ])),
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _OverviewTab(fs: _fs),
        _StaffTab(fs: _fs, expandedRole: _expandedRole,
            onExpand: (r) => setState(
                    () => _expandedRole = r)),
        _StudentsTab(fs: _fs),
      ]),
    );
  }
}

// =============================================================================
//  TAB 1 — OVERVIEW
// =============================================================================
class _OverviewTab extends StatelessWidget {
  final FirebaseFirestore fs;
  const _OverviewTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.collection('users').snapshots(),
      builder: (_, uSnap) => StreamBuilder<QuerySnapshot>(
        stream: fs.collection('students').snapshots(),
        builder: (_, sSnap) => StreamBuilder<QuerySnapshot>(
          stream: fs.collectionGroup('records').snapshots(),
          builder: (_, rSnap) {
            final users    = uSnap.data?.docs ?? [];
            final students = sSnap.data?.docs ?? [];
            final records  = rSnap.data?.docs  ?? [];
            final teachers  = users.where((d) => d['userType'] == 'Teacher').length;
            final therapists= users.where((d) => d['userType'] == 'Therapist').length;
            final se        = users.where((d) => d['userType'] == 'Special Educator').length;
            final totalStaff = teachers + therapists + se;
            final Map<int, int> dist = {1:0,2:0,3:0,4:0,5:0};
            double rSum = 0;
            for (final r in records) {
              final rating = ((r.data() as Map)['rating'] ?? 0) as int;
              rSum += rating;
              if (dist.containsKey(rating)) dist[rating] = dist[rating]! + 1;
            }
            final avg = records.isEmpty ? 0.0 : rSum / records.length;
            final pct = avg / 5.0;

            return CustomScrollView(slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 18)),

              // banner
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: _OverviewBanner(
                    totalStaff: totalStaff, totalStudents: students.length,
                    totalRecords: records.length, avgRating: avg, pct: pct)),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),

              // KPI grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SH('Key Metrics', Icons.dashboard_rounded, _teal),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 3, shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10, mainAxisSpacing: 10,
                      childAspectRatio: 0.95,
                      children: [
                        _KT('Teachers',   teachers,         _blue,   Icons.person_rounded),
                        _KT('Therapists', therapists,       _teal,   Icons.medical_services_rounded),
                        _KT('Sp. Edu.',   se,               _orange, Icons.school_rounded),
                        _KT('Students',   students.length,  _purple, Icons.child_care_rounded),
                        _KT('Records',    records.length,   _green,  Icons.assignment_rounded),
                        _KT('All Staff',  totalStaff,       _navy,   Icons.badge_rounded),
                      ],
                    ),
                  ],
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),

              // distribution
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SH('Rating Distribution', Icons.bar_chart_rounded, _orange),
                    const SizedBox(height: 12),
                    _EC(child: Column(children: [
                      _DR('Below Baseline', 1, dist[1]!, records.length, _red),
                      _DR('Baseline',       2, dist[2]!, records.length, _orange),
                      _DR('Beginning',      3, dist[3]!, records.length, _amber),
                      _DR('Improving',      4, dist[4]!, records.length, _teal),
                      _DR('Well Managed',   5, dist[5]!, records.length, _green),
                    ])),
                  ],
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),

              // role bars
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SH('Staff Breakdown', Icons.people_alt_rounded, _blue),
                    const SizedBox(height: 12),
                    _EC(child: Column(children: [
                      _RB('Teachers',          teachers,  totalStaff, _blue),
                      const SizedBox(height: 12),
                      _RB('Therapists',        therapists,totalStaff, _teal),
                      const SizedBox(height: 12),
                      _RB('Special Educators', se,        totalStaff, _orange),
                    ])),
                  ],
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ]);
          },
        ),
      ),
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  final int totalStaff, totalStudents, totalRecords;
  final double avgRating, pct;
  const _OverviewBanner({required this.totalStaff, required this.totalStudents,
    required this.totalRecords, required this.avgRating, required this.pct});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: _gradNavy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.28),
            blurRadius: 18, offset: const Offset(0, 7))]),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SYSTEM OVERVIEW', style: TextStyle(
              color: Colors.white.withOpacity(0.45), fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 5),
          Text('$totalStudents Students  ·  $totalStaff Staff',
              style: const TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(_teal)),
          ),
          const SizedBox(height: 6),
          Text('Avg ${avgRating.toStringAsFixed(1)}/5  ·  $totalRecords records',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        ],
      )),
      const SizedBox(width: 18),
      SizedBox(width: 68, height: 68, child: Stack(alignment: Alignment.center,
        children: [
          SizedBox(width: 68, height: 68,
              child: CircularProgressIndicator(value: pct, strokeWidth: 7,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(_teal),
                  strokeCap: StrokeCap.round)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(pct*100).toStringAsFixed(0)}%', style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            Text('avg', style: TextStyle(
                color: Colors.white.withOpacity(0.45), fontSize: 9)),
          ]),
        ],
      )),
    ]),
  );
}

// =============================================================================
//  TAB 2 — STAFF
// =============================================================================
class _StaffTab extends StatelessWidget {
  final FirebaseFirestore fs;
  final String expandedRole;
  final ValueChanged<String> onExpand;
  const _StaffTab({required this.fs, required this.expandedRole,
    required this.onExpand});

  static const _roles = [
    {'role': 'Teacher',          'icon': Icons.person_rounded,           'color': _blue},
    {'role': 'Special Educator', 'icon': Icons.school_rounded,           'color': _orange},
    {'role': 'Therapist',        'icon': Icons.medical_services_rounded,  'color': _teal},
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: StreamBuilder<QuerySnapshot>(
          stream: fs.collection('users').snapshots(),
          builder: (_, snap) {
            final users = snap.data?.docs ?? [];
            return Row(children: _roles.map((r) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _RST(role: r['role'] as String, count:
              users.where((d) => d['userType'] == r['role']).length,
                  icon: r['icon'] as IconData, color: r['color'] as Color),
            ))).toList());
          },
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SH('Staff Directory', Icons.manage_accounts_rounded, _navy),
            const SizedBox(height: 12),
            ..._roles.map((r) => _SRS(
              fs: fs, role: r['role'] as String,
              icon: r['icon'] as IconData, color: r['color'] as Color,
              isExpanded: expandedRole == r['role'],
              onTap: () => onExpand(
                  expandedRole == r['role'] ? '' : r['role'] as String),
            )),
          ],
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ]);
  }
}

class _SRS extends StatelessWidget {
  final FirebaseFirestore fs;
  final String role; final IconData icon; final Color color;
  final bool isExpanded; final VoidCallback onTap;
  const _SRS({required this.fs, required this.role, required this.icon,
    required this.color, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: Padding(padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 19)),
              const SizedBox(width: 12),
              Expanded(child: Text(role, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: _textPri))),
              StreamBuilder<QuerySnapshot>(
                stream: fs.collection('users')
                    .where('userType', isEqualTo: role).snapshots(),
                builder: (_, s) {
                  final n = s.data?.docs.length ?? 0;
                  return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$n', style: TextStyle(color: color,
                          fontWeight: FontWeight.w700, fontSize: 12)));
                },
              ),
              const SizedBox(width: 8),
              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded, color: _textHint),
            ]),
          ),
        ),
        if (isExpanded)
          StreamBuilder<QuerySnapshot>(
            stream: fs.collection('users')
                .where('userType', isEqualTo: role).snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(14),
                  child: Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: _teal)));
              final staff = snap.data!.docs;
              if (staff.isEmpty) return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No $role registered.',
                      style: const TextStyle(color: _textHint, fontSize: 13)));
              return Column(children: [
                Divider(height: 1, color: _border.withOpacity(0.5)),
                ...staff.asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value.data() as Map<String, dynamic>;
                  final uid = (d['uid'] ?? e.value.id) as String;
                  return Column(children: [
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StaffDetailPage(
                              staffName: d['name'] ?? '', uid: uid,
                              role: role, color: color,
                              mobile: d['mobile'] ?? ''))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(children: [
                          CircleAvatar(radius: 19,
                              backgroundColor: color.withOpacity(0.1),
                              child: Text((d['name'] ?? 'S')[0].toUpperCase(),
                                  style: TextStyle(color: color,
                                      fontWeight: FontWeight.w700, fontSize: 15))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['name'] ?? '', style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: _textPri)),
                              Text('📞 ${d['mobile'] ?? 'No contact'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: _textHint)),
                            ],
                          )),
                          const Icon(Icons.chevron_right_rounded,
                              color: _textHint, size: 18),
                        ]),
                      ),
                    ),
                    if (i < staff.length - 1)
                      Divider(height: 1, indent: 52,
                          color: _border.withOpacity(0.4)),
                  ]);
                }),
              ]);
            },
          ),
      ]),
    );
  }
}

// =============================================================================
//  TAB 3 — STUDENTS
// =============================================================================
class _StudentsTab extends StatelessWidget {
  final FirebaseFirestore fs;
  const _StudentsTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.collection('students').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(color: _teal));
        final students = snap.data!.docs;
        if (students.isEmpty) return const _ES(icon: Icons.child_care_rounded,
            message: 'No students enrolled yet.');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          itemCount: students.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SH('All Students (${students.length})',
                  Icons.people_rounded, _purple),
            );
            final doc = students[i - 1];
            final d = doc.data() as Map<String, dynamic>;
            return _SSC(studentId: doc.id, data: d, fs: fs);
          },
        );
      },
    );
  }
}

// =============================================================================
//  STAFF DETAIL PAGE
// =============================================================================
class StaffDetailPage extends StatelessWidget {
  final String staffName, uid, role, mobile;
  final Color color;
  const StaffDetailPage({super.key, required this.staffName, required this.uid,
    required this.role, required this.color, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, staffName),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch ALL records then filter client-side — avoids uid mismatch
        // between users collection 'uid' field and the Auth UID in enteredByUid
        stream: fs.collectionGroup('records').snapshots(),
        builder: (_, recSnap) {
          if (recSnap.connectionState == ConnectionState.waiting) return const Center(
              child: CircularProgressIndicator(color: _teal));
          // ✅ Client-side filter: match by enteredByUid OR staffUid OR createdByUid
          final all = (recSnap.data?.docs ?? []).where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['enteredByUid'] == uid
                || d['staffUid'] == uid
                || d['createdByUid'] == uid;
          }).toList();
          final Set<String> sids = {};
          for (final r in all) {
            final sid = ((r.data() as Map)['studentId'] as String?);
            if (sid != null) sids.add(sid);
          }
          double rSum = 0;
          final Map<int, int> dist = {1:0,2:0,3:0,4:0,5:0};
          for (final r in all) {
            final rating = ((r.data() as Map)['rating'] ?? 0) as int;
            rSum += rating;
            if (dist.containsKey(rating)) dist[rating] = dist[rating]! + 1;
          }
          final avg = all.isEmpty ? 0.0 : rSum / all.length;
          final sorted = List<QueryDocumentSnapshot>.from(all)
            ..sort((a, b) {
              final ta = (a.data() as Map)['timestamp'];
              final tb = (b.data() as Map)['timestamp'];
              if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
              return 0;
            });
          final take = sorted.length > 12
              ? sorted.sublist(sorted.length - 12) : sorted;
          final spots = take.asMap().entries.map((e) {
            final r = ((e.value.data() as Map)['rating'] ?? 0) as int;
            return FlSpot(e.key.toDouble(), r.toDouble());
          }).toList();

          return CustomScrollView(slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // profile banner
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: _gradNavy,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _navy.withOpacity(0.25),
                        blurRadius: 16, offset: const Offset(0, 6))]),
                child: Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.25),
                      child: Text(staffName[0].toUpperCase(),
                          style: TextStyle(color: color, fontSize: 24,
                              fontWeight: FontWeight.w800))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staffName, style: const TextStyle(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(role, style: TextStyle(color: color,
                              fontSize: 11, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 4),
                      Text('📞 $mobile', style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 12)),
                    ],
                  )),
                ]),
              )),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // KPI
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: Row(children: [
                _MK('Students',   sids.length.toString(),       Icons.child_care_rounded,   _purple),
                const SizedBox(width: 10),
                _MK('Records',    all.length.toString(),         Icons.assignment_rounded,   _teal),
                const SizedBox(width: 10),
                _MK('Avg Rating', avg.toStringAsFixed(1),        Icons.star_rounded,         _ratingColor(avg / 5)),
              ])),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (all.isNotEmpty) ...[
              SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SH('Rating Distribution', Icons.bar_chart_rounded, _orange),
                    const SizedBox(height: 12),
                    _EC(child: Column(children: [
                      _DR('Below Baseline', 1, dist[1]!, all.length, _red),
                      _DR('Baseline',       2, dist[2]!, all.length, _orange),
                      _DR('Beginning',      3, dist[3]!, all.length, _amber),
                      _DR('Improving',      4, dist[4]!, all.length, _teal),
                      _DR('Well Managed',   5, dist[5]!, all.length, _green),
                    ])),
                  ],
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            if (spots.length >= 2) ...[
              SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SH('Session Trend', Icons.show_chart_rounded, _teal),
                    const SizedBox(height: 12),
                    _EC(child: SizedBox(height: 150,
                        child: _TLC(spots: spots))),
                  ],
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SH('Students (${sids.length})', Icons.people_rounded, _purple),
                  const SizedBox(height: 12),
                  if (sids.isEmpty) _EC(child: const _ES(
                      icon: Icons.child_care_outlined,
                      message: 'No student records entered yet.')),
                  ...sids.map((sid) => _SSCard(
                      studentId: sid, staffUid: uid,
                      staffColor: color, fs: fs)),
                ],
              )),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ]);
        },
      ),
    );
  }
}

// =============================================================================
//  STUDENT SUMMARY CARD  (reused in Students tab + Staff detail)
// =============================================================================
class _SSC extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> data;
  final FirebaseFirestore fs;
  const _SSC({required this.studentId, required this.data, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.collection('students').doc(studentId)
          .collection('records').snapshots(),
      builder: (_, snap) {
        final recs = snap.data?.docs ?? [];
        double avg = 0;
        if (recs.isNotEmpty) {
          int s = 0;
          for (final r in recs) s += ((r.data() as Map)['rating'] ?? 0) as int;
          avg = s / recs.length;
        }
        final pct = avg / 5.0;
        final Set<String> areas = {};
        for (final r in recs) {
          areas.add(((r.data() as Map)['areaOfSupport'] ?? 'Other') as String);
        }
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StudentPerformanceDetailPage(
                  studentId: studentId,
                  studentName: data['name'] ?? 'Student'))),
          child: _StudentCard(name: data['name'] ?? 'Student',
              age: data['age']?.toString() ?? '—',
              disability: data['disability'] ?? '—',
              pct: pct, recCount: recs.length, areas: areas,
              color: _teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => StudentPerformanceDetailPage(
                      studentId: studentId,
                      studentName: data['name'] ?? 'Student')))),
        );
      },
    );
  }
}

class _SSCard extends StatelessWidget {
  final String studentId, staffUid;
  final Color staffColor;
  final FirebaseFirestore fs;
  const _SSCard({required this.studentId, required this.staffUid,
    required this.staffColor, required this.fs});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: fs.collection('students').doc(studentId).get(),
      builder: (_, sSnap) {
        if (!sSnap.hasData) return const _SK();
        if (!sSnap.data!.exists) return const SizedBox.shrink();
        final sd = sSnap.data!.data() as Map<String, dynamic>;
        return StreamBuilder<QuerySnapshot>(
          // Fetch all records for this student, filter by uid client-side
          stream: fs.collection('students').doc(studentId)
              .collection('records').snapshots(),
          builder: (_, rSnap) {
            final allRecs = rSnap.data?.docs ?? [];
            final recs = allRecs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['enteredByUid'] == staffUid
                  || d['staffUid'] == staffUid
                  || d['createdByUid'] == staffUid;
            }).toList();
            double avg = 0;
            if (recs.isNotEmpty) {
              int s = 0;
              for (final r in recs) s += ((r.data() as Map)['rating'] ?? 0) as int;
              avg = s / recs.length;
            }
            final pct = avg / 5.0;
            final Set<String> areas = {};
            for (final r in recs) {
              areas.add(((r.data() as Map)['areaOfSupport'] ?? 'Other') as String);
            }
            return _StudentCard(
              name: sd['name'] ?? 'Student',
              age: sd['age']?.toString() ?? '—',
              disability: sd['disability'] ?? '—',
              pct: pct, recCount: recs.length,
              areas: areas, color: staffColor,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => StudentAreaProgressPage(
                      studentId: studentId,
                      studentName: sd['name'] ?? 'Student',
                      uid: staffUid))),
            );
          },
        );
      },
    );
  }
}

class _StudentCard extends StatelessWidget {
  final String name, age, disability;
  final double pct;
  final int recCount;
  final Set<String> areas;
  final Color color;
  final VoidCallback onTap;
  const _StudentCard({required this.name, required this.age,
    required this.disability, required this.pct, required this.recCount,
    required this.areas, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: _purple.withOpacity(0.1),
              child: Text(name[0].toUpperCase(), style: const TextStyle(
                  color: _purple, fontWeight: FontWeight.w700, fontSize: 15))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13, color: _textPri)),
              Text('Age $age  ·  $disability',
                  style: const TextStyle(fontSize: 11, color: _textHint)),
            ],
          )),
          Container(padding: const EdgeInsets.symmetric(
              horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: _ratingColor(pct).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${(pct*100).toStringAsFixed(0)}%',
                  style: TextStyle(color: _ratingColor(pct),
                      fontWeight: FontWeight.w700, fontSize: 11))),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: _textHint, size: 18),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 6,
                backgroundColor: Colors.grey.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(_ratingColor(pct)))),
        if (areas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 5, runSpacing: 4,
              children: areas.take(4).map((a) =>
                  _CB(label: a, color: color)).toList()),
        ],
        const SizedBox(height: 6),
        Text('$recCount records', style: const TextStyle(
            fontSize: 11, color: _textHint)),
      ]),
    ),
  );
}

// =============================================================================
//  STUDENT AREA PROGRESS PAGE
// =============================================================================
class StudentAreaProgressPage extends StatelessWidget {
  final String studentId, studentName, uid;
  const StudentAreaProgressPage({super.key, required this.studentId,
    required this.studentName, required this.uid});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBarWithAction(context, '$studentName — Progress',
          Icons.bar_chart_rounded, () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => StudentPerformanceDetailPage(
                  studentId: studentId, studentName: studentName)))),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.collection('students').doc(studentId)
            .collection('records')
            .orderBy('timestamp', descending: true).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(
              child: CircularProgressIndicator(color: _teal));
          final allDocs = snap.data?.docs ?? [];
          // ✅ Client-side filter — handles any field name variation
          final filtered = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['enteredByUid'] == uid
                || d['staffUid'] == uid
                || d['createdByUid'] == uid;
          }).toList();
          if (filtered.isEmpty) return const _ES(
              icon: Icons.assignment_outlined,
              message: 'No records by this staff for this student.');
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (final r in filtered) {
            final area = ((r.data() as Map)['areaOfSupport'] ?? 'Other') as String;
            grouped.putIfAbsent(area, () => []).add(r);
          }
          return ListView(padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final aRecs = entry.value;
              int r1=0,r2=0,r3=0,r4=0,r5=0; double avg = 0;
              for (final r in aRecs) {
                final rating = ((r.data() as Map)['rating'] ?? 0) as int;
                avg += rating;
                if (rating==1) r1++; if (rating==2) r2++;
                if (rating==3) r3++; if (rating==4) r4++; if (rating==5) r5++;
              }
              avg = avg / aRecs.length;
              final progress = avg / 5.0;
              return Container(margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border.withOpacity(0.6), width: 0.8)),
                child: Theme(
                  data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    leading: Icon(Icons.psychology_rounded,
                        color: _ratingColor(progress), size: 22),
                    title: Text(entry.key, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: _textPri)),
                    subtitle: Row(children: [
                      Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: progress,
                              minHeight: 5,
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(
                                  _ratingColor(progress))))),
                      const SizedBox(width: 8),
                      Text('${(progress*100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _ratingColor(progress))),
                    ]),
                    children: [Padding(
                      padding: const EdgeInsets.fromLTRB(14,0,14,12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _SC(star:1,count:r1), _SC(star:2,count:r2),
                                _SC(star:3,count:r3), _SC(star:4,count:r4),
                                _SC(star:5,count:r5),
                              ]),
                          const Divider(height: 16),
                          ...aRecs.map((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            final int rating = (d['rating'] ?? 0) as int;
                            final String date = d['timestamp'] is Timestamp
                                ? DateFormat('dd MMM yyyy').format(
                                (d['timestamp'] as Timestamp).toDate())
                                : d['date'] ?? '';
                            return Padding(padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Icon(Icons.circle, size: 5,
                                    color: _ratingColor(rating / 5)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(d['challenge'] ?? 'No challenge',
                                    style: const TextStyle(
                                        fontSize: 12, color: _textPri),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                _SB(rating: rating),
                                const SizedBox(width: 6),
                                Text(date, style: const TextStyle(
                                    fontSize: 10, color: _textHint)),
                              ]),
                            );
                          }),
                        ],
                      ),
                    )],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// =============================================================================
//  STUDENT PERFORMANCE DETAIL PAGE
// =============================================================================
class StudentPerformanceDetailPage extends StatelessWidget {
  final String studentId, studentName;
  const StudentPerformanceDetailPage({super.key,
    required this.studentId, required this.studentName});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, '$studentName — Performance'),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.collection('students').doc(studentId)
            .collection('records')
            .orderBy('timestamp', descending: false).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(
              child: CircularProgressIndicator(color: _teal));
          if (!snap.hasData || snap.data!.docs.isEmpty) return const _ES(
              icon: Icons.insert_chart_outlined_rounded,
              message: 'No performance records available.');
          final records = snap.data!.docs;
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          int r1=0,r2=0,r3=0,r4=0,r5=0; double rSum = 0;
          for (final doc in records) {
            final d = doc.data() as Map<String, dynamic>;
            final area = (d['areaOfSupport'] ?? 'Other') as String;
            final rating = (d['rating'] ?? 0) as int;
            rSum += rating;
            if (rating==1) r1++; if (rating==2) r2++;
            if (rating==3) r3++; if (rating==4) r4++; if (rating==5) r5++;
            grouped.putIfAbsent(area, () => []).add(d);
          }
          final avgRating = rSum / records.length;
          final overallPct = avgRating / 5.0;
          final trendDocs = records.length > 12
              ? records.sublist(records.length - 12) : records;
          final spots = trendDocs.asMap().entries.map((e) {
            final d = e.value.data() as Map<String, dynamic>;
            return FlSpot(e.key.toDouble(),
                ((d['rating'] ?? 0) as int).toDouble());
          }).toList();

          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              _MK('Records',  records.length.toString(),       Icons.assignment_rounded,    _teal),
              const SizedBox(width: 10),
              _MK('Avg',      avgRating.toStringAsFixed(1),    Icons.star_rounded,          _ratingColor(overallPct)),
              const SizedBox(width: 10),
              _MK('Progress', '${(overallPct*100).toStringAsFixed(0)}%',
                  Icons.trending_up_rounded, _ratingColor(overallPct)),
              const SizedBox(width: 10),
              _MK('Areas',    grouped.keys.length.toString(),  Icons.category_rounded,      _purple),
            ]),
            const SizedBox(height: 16),
            _EC(child: Row(children: [
              SizedBox(width: 88, height: 88,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 88, height: 88,
                      child: CircularProgressIndicator(value: overallPct,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                              _ratingColor(overallPct)),
                          strokeCap: StrokeCap.round)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${(overallPct*100).toStringAsFixed(0)}%',
                        style: TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 18, color: _ratingColor(overallPct))),
                    const Text('overall', style: TextStyle(
                        fontSize: 9, color: _textHint)),
                  ]),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SR('Avg Rating', '${avgRating.toStringAsFixed(2)} / 5.0'),
                  _SR('Total Records', records.length.toString()),
                  _SR('Support Areas', grouped.keys.length.toString()),
                  _SR('Status',
                      overallPct >= 0.75 ? 'Good Progress'
                          : overallPct >= 0.5 ? 'Average' : 'Needs Attention',
                      valueColor: _ratingColor(overallPct)),
                ],
              )),
            ])),
            const SizedBox(height: 14),
            const _SH('Rating Distribution', Icons.bar_chart_rounded, _orange),
            const SizedBox(height: 10),
            _EC(child: Column(children: [
              _DR('Below Baseline', 1, r1, records.length, _red),
              _DR('Baseline',       2, r2, records.length, _orange),
              _DR('Beginning',      3, r3, records.length, _amber),
              _DR('Improving',      4, r4, records.length, _teal),
              _DR('Well Managed',   5, r5, records.length, _green),
            ])),
            const SizedBox(height: 14),
            const _SH('Progress Trend', Icons.show_chart_rounded, _teal),
            const SizedBox(height: 10),
            _EC(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last ${spots.length} sessions',
                    style: const TextStyle(fontSize: 11, color: _textHint)),
                const SizedBox(height: 12),
                SizedBox(height: 140, child: _TLC(spots: spots)),
              ],
            )),
            const SizedBox(height: 14),
            const _SH('Area-wise Breakdown', Icons.psychology_rounded, _purple),
            const SizedBox(height: 10),
            ...grouped.entries.map((e) {
              final avg = e.value.map((d) => (d['rating'] ?? 0) as int)
                  .reduce((a, b) => a + b) / e.value.length;
              return _AET(area: e.key, records: e.value, avgRating: avg);
            }),
            if (grouped.keys.length >= 3) ...[
              const SizedBox(height: 14),
              const _SH('Area Comparison', Icons.radar_rounded, _blue),
              const SizedBox(height: 10),
              _EC(child: SizedBox(height: 220,
                  child: _ARC(grouped: grouped))),
            ],
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}

// =============================================================================
//  ADMIN PROFILE PAGE
// =============================================================================
class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, 'Profile'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: fs.collection('users').doc(uid).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator(color: _teal));
          final d = snap.data!.data() as Map<String, dynamic>;
          return Column(children: [
            Container(width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: const BoxDecoration(gradient: _gradNavy),
              child: Column(children: [
                CircleAvatar(radius: 44,
                    backgroundColor: _teal.withOpacity(0.2),
                    child: Text((d['name'] ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 36,
                            fontWeight: FontWeight.w800, color: _teal))),
                const SizedBox(height: 14),
                Text(d['name'] ?? 'Admin', style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: _teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(d['userType'] ?? '', style: const TextStyle(
                        color: _teal, fontWeight: FontWeight.w600, fontSize: 13))),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _teal, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

// =============================================================================
//  APP BAR HELPERS
// =============================================================================
PreferredSizeWidget _gradAppBar(BuildContext context, String title) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(60),
    child: Container(
      decoration: const BoxDecoration(gradient: _gradNavy),
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context)),
          Expanded(child: Text(title, style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
      )),
    ),
  );
}

PreferredSizeWidget _gradAppBarWithAction(
    BuildContext context, String title, IconData actionIcon, VoidCallback onAction) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(60),
    child: Container(
      decoration: const BoxDecoration(gradient: _gradNavy),
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context)),
          Expanded(child: Text(title, style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
          IconButton(icon: Icon(actionIcon, color: Colors.white, size: 20),
              onPressed: onAction),
        ]),
      )),
    ),
  );
}

// =============================================================================
//  SHARED UI WIDGETS  (short aliases to keep code compact)
// =============================================================================

// ElevatedCard
class _EC extends StatelessWidget {
  final Widget child; final EdgeInsets? padding;
  const _EC({required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border.withOpacity(0.5), width: 0.8),
      boxShadow: [
        BoxShadow(color: _navy.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 4)),
        BoxShadow(color: _navy.withOpacity(0.03),
            blurRadius: 3, offset: const Offset(0, 1)),
      ],
    ),
    child: child,
  );
}

// SectionHeader
class _SH extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  const _SH(this.title, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 16)),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.w700, color: _textPri)),
  ]);
}

// KPI Tile
class _KT extends StatelessWidget {
  final String title; final int value; final Color color; final IconData icon;
  const _KT(this.title, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
      boxShadow: [BoxShadow(color: _navy.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 17)),
      const SizedBox(height: 8),
      Text(value.toString(), style: TextStyle(fontSize: 20,
          fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(title, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10,
              fontWeight: FontWeight.w600, color: _textHint)),
    ]),
  );
}

// Role Summary Tile
class _RST extends StatelessWidget {
  final String role; final int count; final IconData icon; final Color color;
  const _RST({required this.role, required this.count,
    required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
      boxShadow: [BoxShadow(color: _navy.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 8),
      Text('$count', style: TextStyle(fontSize: 22,
          fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(role, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9,
              fontWeight: FontWeight.w600, color: _textHint)),
    ]),
  );
}

// Mini KPI
class _MK extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _MK(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: _card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800,
          fontSize: 14, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: _textHint),
          textAlign: TextAlign.center),
    ]),
  ));
}

// Dist Row
class _DR extends StatelessWidget {
  final String label; final int star, count, total; final Color color;
  const _DR(this.label, this.star, this.count, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$star★', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: _textPri))),
              Text('$count', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 5),
              Text('(${(pct*100).toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 10, color: _textHint)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: pct, minHeight: 6,
                    backgroundColor: color.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(color))),
          ],
        )),
      ]),
    );
  }
}

// Role Bar
class _RB extends StatelessWidget {
  final String role; final int count, total; final Color color;
  const _RB(this.role, this.count, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      SizedBox(width: 110, child: Text(role, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _textPri))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: pct, minHeight: 8,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color)))),
      const SizedBox(width: 10),
      SizedBox(width: 26, child: Text('$count', textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: color))),
    ]);
  }
}

// Stat row
class _SR extends StatelessWidget {
  final String label, value; final Color? valueColor;
  const _SR(this.label, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _textHint)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: valueColor ?? _textPri)),
    ]),
  );
}

// Chip badge
class _CB extends StatelessWidget {
  final String label; final Color color;
  const _CB({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: TextStyle(fontSize: 10,
        color: color, fontWeight: FontWeight.w600)),
  );
}

// Star count
class _SC extends StatelessWidget {
  final int star, count;
  const _SC({required this.star, required this.count});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$star★', style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.w700, color: _textPri)),
    Text('$count', style: const TextStyle(fontSize: 11, color: _textHint)),
  ]);
}

// Star badge
class _SB extends StatelessWidget {
  final int rating;
  const _SB({required this.rating});
  @override
  Widget build(BuildContext context) {
    const colors = [_red, _orange, _amber, _green, _green];
    final idx = (rating - 1).clamp(0, 4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: colors[idx].withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text('$rating★', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w700, color: colors[idx])),
    );
  }
}

// Area Expansion Tile
class _AET extends StatelessWidget {
  final String area;
  final List<Map<String, dynamic>> records;
  final double avgRating;
  const _AET({required this.area, required this.records,
    required this.avgRating});
  @override
  Widget build(BuildContext context) {
    final progress = avgRating / 5.0;
    return Container(margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border.withOpacity(0.6), width: 0.8)),
      child: Theme(data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Icon(Icons.psychology_rounded,
              color: _ratingColor(progress), size: 20),
          title: Text(area, style: const TextStyle(fontWeight: FontWeight.w600,
              fontSize: 13, color: _textPri)),
          subtitle: Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: progress, minHeight: 5,
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(_ratingColor(progress))))),
            const SizedBox(width: 8),
            Text('${(progress*100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: _ratingColor(progress))),
          ]),
          children: [Padding(padding: const EdgeInsets.fromLTRB(14,0,14,12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 12),
                ...records.take(4).map((d) {
                  final rating = (d['rating'] ?? 0) as int;
                  final date = d['timestamp'] is Timestamp
                      ? DateFormat('dd MMM').format(
                      (d['timestamp'] as Timestamp).toDate())
                      : d['date'] ?? '';
                  return Padding(padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.circle, size: 5, color: _ratingColor(rating/5)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d['challenge'] ?? 'N/A',
                          style: const TextStyle(fontSize: 11, color: _textPri),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      _SB(rating: rating),
                      const SizedBox(width: 6),
                      Text(date, style: const TextStyle(
                          fontSize: 10, color: _textHint)),
                    ]),
                  );
                }),
                if (records.length > 4)
                  Text('+${records.length - 4} more',
                      style: const TextStyle(fontSize: 11, color: _textHint)),
              ],
            ),
          )],
        ),
      ),
    );
  }
}

// Area Radar Chart
class _ARC extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> grouped;
  const _ARC({required this.grouped});
  @override
  Widget build(BuildContext context) {
    final areas = grouped.keys.toList();
    final values = areas.map((a) {
      final ratings = grouped[a]!.map((d) => (d['rating'] ?? 0) as int).toList();
      return ratings.reduce((x, y) => x + y) / ratings.length;
    }).toList();
    return RadarChart(RadarChartData(
      radarShape: RadarShape.polygon,
      dataSets: [RadarDataSet(fillColor: _teal.withOpacity(0.15),
          borderColor: _teal, borderWidth: 2, entryRadius: 4,
          dataEntries: values.map((v) => RadarEntry(value: v)).toList())],
      radarBackgroundColor: Colors.transparent,
      borderData: FlBorderData(show: false),
      radarBorderData: const BorderSide(color: Colors.transparent),
      gridBorderData: BorderSide(color: _border, width: 1),
      tickCount: 5,
      ticksTextStyle: const TextStyle(color: _textHint, fontSize: 9),
      tickBorderData: BorderSide(color: _border, width: 1),
      getTitle: (i, angle) => RadarChartTitle(text: areas[i], angle: angle),
      titleTextStyle: const TextStyle(fontSize: 11,
          fontWeight: FontWeight.w500, color: _textPri),
      titlePositionPercentageOffset: 0.18,
    ));
  }
}

// Trend Line Chart
class _TLC extends StatelessWidget {
  final List<FlSpot> spots;
  const _TLC({required this.spots});
  @override
  Widget build(BuildContext context) => LineChart(LineChartData(
    minY: 0, maxY: 6,
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => _navy,
        getTooltipItems: (ts) => ts.map((s) => LineTooltipItem(
            '${s.y.toInt()}★',
            const TextStyle(color: Colors.white, fontSize: 12))).toList(),
      ),
    ),
    gridData: FlGridData(show: true, drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: _border, strokeWidth: 0.8)),
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
          interval: 1, reservedSize: 24,
          getTitlesWidget: (v, _) => Text('${v.toInt()}',
              style: const TextStyle(fontSize: 9, color: _textHint)))),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
          reservedSize: 20,
          getTitlesWidget: (v, _) => Text('S${v.toInt()+1}',
              style: const TextStyle(fontSize: 9, color: _textHint)))),
      rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    lineBarsData: [LineChartBarData(spots: spots,
        isCurved: true, color: _teal, barWidth: 2.5,
        dotData: FlDotData(show: true,
            getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 3, color: _teal,
                strokeWidth: 2, strokeColor: Colors.white)),
        belowBarData: BarAreaData(show: true,
            color: _teal.withOpacity(0.08)))],
  ));
}

// Empty state
class _ES extends StatelessWidget {
  final IconData icon; final String message;
  const _ES({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: _textHint.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14,
              color: _textHint, fontWeight: FontWeight.w500)),
    ]),
  );
}

// Skeleton card
class _SK extends StatelessWidget {
  const _SK();
  @override
  Widget build(BuildContext context) => Container(
      height: 72, margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14)));
}

// RoleStaffPage (kept for backward compatibility)
class RoleStaffPage extends StatelessWidget {
  final String role;
  const RoleStaffPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, '$role List'),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.collection('users')
            .where('userType', isEqualTo: role).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator(color: _teal));
          final staff = snap.data!.docs;
          if (staff.isEmpty) return _ES(icon: Icons.people_outline_rounded,
              message: 'No $role registered yet.');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            itemBuilder: (_, i) {
              final d = staff[i].data() as Map<String, dynamic>;
              final uid = (d['uid'] ?? staff[i].id) as String;
              return Container(margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _border.withOpacity(0.6), width: 0.8)),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: _blue.withOpacity(0.1),
                      child: Text((d['name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: _blue,
                              fontWeight: FontWeight.w700))),
                  title: Text(d['name'] ?? '', style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _textPri)),
                  subtitle: Text('📞 ${d['mobile'] ?? 'No contact'}',
                      style: const TextStyle(color: _textHint, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: _textHint),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StaffDetailPage(
                          staffName: d['name'] ?? '', uid: uid,
                          role: role, color: _blue,
                          mobile: d['mobile'] ?? ''))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// StaffEntriesPage (kept for backward compat)
class StaffEntriesPage extends StatelessWidget {
  final String staffName, uid;
  const StaffEntriesPage({super.key,
    required this.staffName, required this.uid});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, '$staffName — Students'),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch all records, filter client-side to avoid uid mismatch
        stream: fs.collectionGroup('records').snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(
              child: CircularProgressIndicator(color: _teal));
          final allDocs = snap.data?.docs ?? [];
          // ✅ Match by any uid field that this staff's records may use
          final matched = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['enteredByUid'] == uid
                || d['staffUid'] == uid
                || d['createdByUid'] == uid;
          }).toList();
          if (matched.isEmpty) return const _ES(
              icon: Icons.assignment_outlined,
              message: 'No records entered by this staff.');
          final sids = matched
              .map((r) => ((r.data() as Map)['studentId'] as String?) ?? '')
              .where((id) => id.isNotEmpty).toSet();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sids.length,
            itemBuilder: (_, i) {
              final sid = sids.elementAt(i);
              return FutureBuilder<DocumentSnapshot>(
                future: fs.collection('students').doc(sid).get(),
                builder: (_, sSnap) {
                  if (!sSnap.hasData) return const _SK();
                  final sd = sSnap.data!.data() as Map<String, dynamic>;
                  return Container(margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _border.withOpacity(0.6), width: 0.8)),
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: _purple.withOpacity(0.1),
                          child: Text((sd['name'] ?? 'S')[0],
                              style: const TextStyle(color: _purple,
                                  fontWeight: FontWeight.w700))),
                      title: Text(sd['name'] ?? 'Student',
                          style: const TextStyle(fontWeight: FontWeight.w600,
                              color: _textPri)),
                      subtitle: Text(
                          'Age ${sd['age'] ?? '—'}  ·  ${sd['disability'] ?? '—'}',
                          style: const TextStyle(
                              fontSize: 12, color: _textHint)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: _textHint),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              StudentAreaProgressPage(
                                  studentId: sid,
                                  studentName: sd['name'] ?? 'Student',
                                  uid: uid))),
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