// =============================================================================
//  ADMIN DASHBOARD  —  Organisation-scoped  |  Base64 photo storage
//  FIXES:
//  1. _OverviewTab: added missing students + records StreamBuilders (sSnap/rSnap)
//  2. Staff list loads correctly via merged organisation/orgName query
//  3. StaffDetailPage Entries tab filters records by enteredByUid only
//  4. All undefined variable references resolved
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'login_page.dart';

// ─────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0D1B2A);
const _teal    = Color(0xFF0A9396);
const _surface = Color(0xFFF0F3F7);
const _card    = Color(0xFFFFFFFF);
const _border  = Color(0xFFE2E8F0);
const _textPri = Color(0xFF0D1B2A);
const _textHint= Color(0xFF94A3B8);
const _green   = Color(0xFF059669);
const _red     = Color(0xFFDC2626);
const _orange  = Color(0xFFD97706);
const _amber   = Color(0xFFF59E0B);
const _blue    = Color(0xFF2563EB);
const _purple  = Color(0xFF7C3AED);

const _gradNavy = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C)],
    begin: Alignment.topLeft, end: Alignment.bottomRight);

Color _ratingColor(double v) {
  if (v >= 0.75) return _green;
  if (v >= 0.5)  return _amber;
  return _red;
}

// ─────────────────────────────────────────────────────────────────────
//  ORGANISATION HELPER
// ─────────────────────────────────────────────────────────────────────
class OrgPath {
  final String orgId;
  const OrgPath(this.orgId);

  CollectionReference<Map<String, dynamic>> students(FirebaseFirestore fs) =>
      fs.collection('organisations').doc(orgId).collection('students');

  CollectionReference<Map<String, dynamic>> records(
      FirebaseFirestore fs, String studentId) =>
      students(fs).doc(studentId).collection('records');
}

// ─────────────────────────────────────────────────────────────────────
//  MIGRATION HELPER
// ─────────────────────────────────────────────────────────────────────
Future<void> migrateUserDataToOrg({
  required FirebaseFirestore fs,
  required String uid,
  required String org,
}) async {
  final orgPath = OrgPath(org);

  final oldRecords = await fs
      .collectionGroup('records')
      .where('enteredByUid', isEqualTo: uid)
      .get();

  final WriteBatch batch = fs.batch();

  for (final doc in oldRecords.docs) {
    final data = doc.data();
    final sid  = data['studentId'] as String?;
    if (sid == null || sid.isEmpty) continue;

    final orgStudentRef = orgPath.students(fs).doc(sid);
    final oldStudentSnap = await fs.collection('students').doc(sid).get();
    if (oldStudentSnap.exists) {
      batch.set(orgStudentRef, oldStudentSnap.data()!, SetOptions(merge: true));
    }

    final newRecRef = orgPath.records(fs, sid).doc(doc.id);
    batch.set(newRecRef, {...data, 'organisation': org});
    batch.delete(doc.reference);
  }

  await batch.commit();
  await fs.collection('users').doc(uid).update({'migrationDone': true});
}

// =============================================================================
//  ORGANISATION SETUP DIALOG
// =============================================================================
class OrgSetupDialog extends StatefulWidget {
  final String uid;
  final bool isAdmin;
  final Future<void> Function(String org) onOrgSaved;

  const OrgSetupDialog({
    super.key,
    required this.uid,
    required this.isAdmin,
    required this.onOrgSaved,
  });

  @override
  State<OrgSetupDialog> createState() => _OrgSetupDialogState();
}

class _OrgSetupDialogState extends State<OrgSetupDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    final org = _ctrl.text.trim();
    if (org.isEmpty) {
      setState(() => _error = 'Please enter your organisation name.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onOrgSaved(org);
    } catch (e) {
      setState(() { _error = 'Failed: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.business_rounded, color: _teal, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Set Your Organisation',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textPri)),
            const SizedBox(height: 8),
            Text(
              widget.isAdmin
                  ? 'Enter the name of your organisation. All staff and student data will be stored under this name.'
                  : 'Enter the name of your organisation to continue. Your existing records will be transferred automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textHint, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Sunrise Special School',
                hintStyle: const TextStyle(color: _textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.apartment_rounded, color: _teal, size: 20),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _teal, width: 1.5)),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Column(children: [
                CircularProgressIndicator(color: _teal),
                SizedBox(height: 8),
                Text('Saving & migrating data…',
                    style: TextStyle(fontSize: 12, color: _textHint)),
              ])
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save & Continue',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  ORG GUARD WRAPPER
// ─────────────────────────────────────────────────────────────────────
class OrgGuard extends StatefulWidget {
  final Widget child;
  final bool isAdmin;
  const OrgGuard({super.key, required this.child, this.isAdmin = false});

  @override
  State<OrgGuard> createState() => _OrgGuardState();
}

class _OrgGuardState extends State<OrgGuard> {
  final _fs  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _checked = false;
  bool _needsOrg = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final col  = widget.isAdmin ? 'admins' : 'users';
    final snap = await _fs.collection(col).doc(_uid).get();
    final org  = (snap.data()?['organisation'] as String?) ?? '';
    if (mounted) setState(() { _needsOrg = org.isEmpty; _checked = true; });
  }

  Future<void> _handleOrgSaved(String org) async {
    final batch = _fs.batch();

    batch.set(
      _fs.collection('admins').doc(_uid),
      {'organisation': org},
      SetOptions(merge: true),
    );

    batch.set(
      _fs.collection('users').doc(_uid),
      {'organisation': org, 'orgName': org},
      SetOptions(merge: true),
    );

    await batch.commit();

    if (!widget.isAdmin) {
      await migrateUserDataToOrg(fs: _fs, uid: _uid, org: org);
    }

    if (mounted) setState(() => _needsOrg = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
          backgroundColor: _surface,
          body: Center(child: CircularProgressIndicator(color: _teal)));
    }
    return Stack(children: [
      widget.child,
      if (_needsOrg)
        Container(
          color: Colors.black.withOpacity(0.55),
          child: Center(
            child: OrgSetupDialog(
                uid: _uid,
                isAdmin: widget.isAdmin,
                onOrgSaved: _handleOrgSaved),
          ),
        ),
    ]);
  }
}

// =============================================================================
//  ADMIN DASHBOARD PAGE
// =============================================================================
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
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';

    return OrgGuard(
      isAdmin: true,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(126),
          child: Container(
            decoration: const BoxDecoration(gradient: _gradNavy),
            child: SafeArea(child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 12, 0),
                child: Row(children: [

                  // ── Management Logo + Org name from admins collection ──
                  StreamBuilder<DocumentSnapshot>(
                    stream: _fs.collection('admins').doc(uid).snapshots(),
                    builder: (_, snap) {
                      final data     = snap.data?.data() as Map<String, dynamic>?;
                      final logoB64  = data?['managementLogoUrl'] as String?;
                      final orgName  = data?['organisation'] as String? ?? '';
                      final logoBytes= logoB64 != null ? base64Decode(logoB64) : null;
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _teal.withOpacity(0.45), width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: logoBytes != null
                              ? Image.memory(logoBytes, fit: BoxFit.cover)
                              : const Center(child: Text('✦',
                              style: TextStyle(color: Color(0xFF94D2BD),
                                  fontSize: 18, fontWeight: FontWeight.w800))),
                        ),
                        if (orgName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _teal.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(orgName,
                                style: const TextStyle(color: Color(0xFF94D2BD),
                                    fontSize: 10, fontWeight: FontWeight.w700),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ]);
                    },
                  ),

                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Management Dashboard',
                          style: TextStyle(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(date, style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    ],
                  )),

                  // ── Admin profile avatar ──
                  StreamBuilder<DocumentSnapshot>(
                    stream: _fs.collection('admins').doc(uid).snapshots(),
                    builder: (_, snap) {
                      final photoB64   = (snap.data?.data()
                      as Map<String, dynamic>?)?['photoUrl'] as String?;
                      final photoBytes = photoB64 != null ? base64Decode(photoB64) : null;
                      return InkWell(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AdminProfilePage())),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: photoBytes != null
                              ? Image.memory(photoBytes, fit: BoxFit.cover)
                              : const Icon(Icons.person_outline_rounded,
                              color: Colors.white, size: 18),
                        ),
                      );
                    },
                  ),
                ]),
              ),
              PreferredSize(
                preferredSize: const Size.fromHeight(55),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: _teal,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelPadding: const EdgeInsets.only(bottom: 8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Staff'),
                    Tab(text: 'Students'),
                  ],
                ),
              ),
            ])),
          ),
        ),

        body: StreamBuilder<DocumentSnapshot>(
          stream: _fs.collection('admins').doc(uid).snapshots(),
          builder: (_, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _teal));
            }

            final data    = adminSnap.data?.data() as Map<String, dynamic>?;
            final orgName = (data?['organisation'] as String? ?? '').trim();
            final orgId   = (data?['orgId'] as String? ?? '').trim();

            if (orgName.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: _teal));
            }

            final orgPath = OrgPath(orgId.isNotEmpty ? orgId : orgName);

            return TabBarView(controller: _tabs, children: [
              _OverviewTab(fs: _fs, orgPath: orgPath, adminOrg: orgName),
              _StaffTab(
                fs: _fs,
                orgPath: orgPath,
                adminOrg: orgName,
                expandedRole: _expandedRole,
                onExpand: (r) => setState(() => _expandedRole = r),
              ),
              _StudentsTab(fs: _fs, orgPath: orgPath),
            ]);
          },
        ),
      ),
    );
  }
}

// =============================================================================
//  ADMIN PROFILE PAGE
// =============================================================================
class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});
  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  bool _uploadingPhoto = false;
  bool _uploadingLogo  = false;
  bool _savingOrg      = false;
  final _fs      = FirebaseFirestore.instance;
  final _uid     = FirebaseAuth.instance.currentUser!.uid;
  final _orgCtrl = TextEditingController();

  @override
  void dispose() { _orgCtrl.dispose(); super.dispose(); }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _uploadImage({
    required ImageSource source,
    required String firestoreField,
    required void Function(bool) setUploading,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 50, maxWidth: 300);
    if (picked == null) return;
    setUploading(true);
    try {
      final bytes     = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      await _fs.collection('admins').doc(_uid)
          .set({firestoreField: base64Str}, SetOptions(merge: true));
      _snack(firestoreField == 'photoUrl'
          ? 'Profile photo updated!' : 'Management logo updated!');
    } catch (e) {
      _snack('Upload failed: $e');
    } finally {
      setUploading(false);
    }
  }

  Future<void> _removeImage({
    required String firestoreField,
    required void Function(bool) setUploading,
  }) async {
    setUploading(true);
    try {
      await _fs.collection('admins').doc(_uid)
          .update({firestoreField: FieldValue.delete()});
      _snack('Removed successfully.');
    } catch (e) {
      _snack('Remove failed: $e');
    } finally {
      setUploading(false);
    }
  }

  Future<void> _saveOrg(String currentOrg) async {
    final newOrg = _orgCtrl.text.trim();
    if (newOrg.isEmpty) { _snack('Organisation name cannot be empty.'); return; }
    if (newOrg == currentOrg) { _snack('No changes made.'); return; }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Organisation?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
            'Changing from "$currentOrg" to "$newOrg" will update the organisation name for all staff members in this org.',
            style: const TextStyle(fontSize: 13, color: _textHint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _teal),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _savingOrg = true);
    try {
      await _fs.collection('admins').doc(_uid).set(
        {'organisation': newOrg},
        SetOptions(merge: true),
      );

      await _fs.collection('users').doc(_uid).set(
        {'organisation': newOrg, 'orgName': newOrg},
        SetOptions(merge: true),
      );

      if (currentOrg.isNotEmpty) {
        for (final field in ['organisation', 'orgName']) {
          final snap = await _fs
              .collection('users')
              .where(field, isEqualTo: currentOrg)
              .get();
          for (int i = 0; i < snap.docs.length; i += 400) {
            final chunk = snap.docs.sublist(i, (i + 400).clamp(0, snap.docs.length));
            final batch = _fs.batch();
            for (final doc in chunk) {
              batch.update(doc.reference, {'organisation': newOrg, 'orgName': newOrg});
            }
            await batch.commit();
          }
        }
      }

      _snack('Organisation updated for all members!');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _savingOrg = false);
    }
  }

  void _showProfilePhotoOptions(String? current) => _showOptions(
    title: 'Update Profile Photo', hasExisting: current != null,
    onGallery: () => _uploadImage(source: ImageSource.gallery,
        firestoreField: 'photoUrl',
        setUploading: (v) => setState(() => _uploadingPhoto = v)),
    onCamera: () => _uploadImage(source: ImageSource.camera,
        firestoreField: 'photoUrl',
        setUploading: (v) => setState(() => _uploadingPhoto = v)),
    onRemove: () => _removeImage(firestoreField: 'photoUrl',
        setUploading: (v) => setState(() => _uploadingPhoto = v)),
  );

  void _showLogoOptions(String? current) => _showOptions(
    title: 'Update Management Logo', hasExisting: current != null,
    onGallery: () => _uploadImage(source: ImageSource.gallery,
        firestoreField: 'managementLogoUrl',
        setUploading: (v) => setState(() => _uploadingLogo = v)),
    onCamera: () => _uploadImage(source: ImageSource.camera,
        firestoreField: 'managementLogoUrl',
        setUploading: (v) => setState(() => _uploadingLogo = v)),
    onRemove: () => _removeImage(firestoreField: 'managementLogoUrl',
        setUploading: (v) => setState(() => _uploadingLogo = v)),
  );

  void _showOptions({
    required String title, required bool hasExisting,
    required VoidCallback onGallery, required VoidCallback onCamera,
    required VoidCallback onRemove,
  }) {
    showModalBottomSheet(
      context: context, backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _textPri))),
            const SizedBox(height: 12),
            _sheetTile(Icons.photo_library_outlined, 'Choose from Gallery',
                _textPri, () { Navigator.pop(context); onGallery(); }),
            _sheetTile(Icons.camera_alt_outlined, 'Take a Photo',
                _textPri, () { Navigator.pop(context); onCamera(); }),
            if (hasExisting)
              _sheetTile(Icons.delete_outline_rounded, 'Remove',
                  _red, () { Navigator.pop(context); onRemove(); }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: color == _red ? _red.withOpacity(0.08)
                        : const Color(0xFFD9F0F1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), behavior: SnackBarBehavior.floating,
    backgroundColor: _navy,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ));

  @override
  Widget build(BuildContext context) {
    final isLoading = _uploadingPhoto || _uploadingLogo;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, 'Profile'),
      body: Stack(children: [
        StreamBuilder<DocumentSnapshot>(
          stream: _fs.collection('admins').doc(_uid).snapshots(),
          builder: (_, snap) {
            final data     = (snap.data?.data() as Map<String, dynamic>?) ?? {};
            final name     = data['name']  as String? ?? 'Admin';
            final email    = data['email'] as String?
                ?? FirebaseAuth.instance.currentUser?.email ?? '';
            final mobile   = data['mobile'] as String? ?? '—';
            final orgName  = data['organisation'] as String? ?? '';
            final photoB64 = data['photoUrl']          as String?;
            final logoB64  = data['managementLogoUrl'] as String?;
            final photoBytes = photoB64 != null ? base64Decode(photoB64) : null;
            final logoBytes  = logoB64  != null ? base64Decode(logoB64)  : null;

            if (_orgCtrl.text.isEmpty && orgName.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _orgCtrl.text = orgName);
            }

            return SingleChildScrollView(
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: const BoxDecoration(gradient: _gradNavy),
                  child: Column(children: [
                    GestureDetector(
                      onTap: () => _showProfilePhotoOptions(photoB64),
                      child: Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30, width: 2)),
                          child: CircleAvatar(
                            radius: 48, backgroundColor: _teal.withOpacity(0.2),
                            backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                            child: photoBytes == null
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                style: const TextStyle(fontSize: 32,
                                    fontWeight: FontWeight.w800, color: _teal))
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: _teal, shape: BoxShape.circle,
                              border: Border.all(color: _navy, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    if (orgName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: _teal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.apartment_rounded, color: _teal, size: 13),
                          const SizedBox(width: 5),
                          Text(orgName, style: const TextStyle(
                              color: _teal, fontWeight: FontWeight.w600, fontSize: 12)),
                        ]),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: _teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Admin', style: TextStyle(
                          color: _teal, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _teal, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    const _SH('Admin Information', Icons.manage_accounts_rounded, _teal),
                    const SizedBox(height: 12),
                    _infoCard(Icons.person_outline_rounded, 'Full Name', name),
                    _infoCard(Icons.email_outlined, 'Email', email),
                    _infoCard(Icons.phone_android_rounded, 'Mobile', mobile),
                    const SizedBox(height: 24),

                    const _SH('Organisation', Icons.apartment_rounded, _teal),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
                          boxShadow: [BoxShadow(color: _navy.withOpacity(0.05),
                              blurRadius: 10, offset: const Offset(0, 3))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Organisation Name',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w600, color: _textHint)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _orgCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'Enter organisation name',
                                hintStyle: const TextStyle(color: _textHint, fontSize: 13),
                                prefixIcon: const Icon(Icons.business_rounded,
                                    color: _teal, size: 18),
                                filled: true, fillColor: _surface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: _border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: _teal, width: 1.5)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _savingOrg
                              ? const SizedBox(width: 40, height: 40,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                              : ElevatedButton(
                            onPressed: () => _saveOrg(orgName),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _teal,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(56, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('Save',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.info_outline_rounded,
                              size: 13, color: _amber.withOpacity(0.8)),
                          const SizedBox(width: 5),
                          const Expanded(child: Text(
                              'Updating the name syncs it across all staff members instantly.',
                              style: TextStyle(fontSize: 11, color: _textHint))),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    const _SH('Management Logo', Icons.business_rounded, _blue),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showLogoOptions(logoB64),
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
                            boxShadow: [BoxShadow(color: _navy.withOpacity(0.05),
                                blurRadius: 10, offset: const Offset(0, 3))]),
                        child: Column(children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(color: _blue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _blue.withOpacity(0.2), width: 1.5)),
                            clipBehavior: Clip.antiAlias,
                            child: logoBytes != null
                                ? Image.memory(logoBytes, fit: BoxFit.cover)
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: _blue.withOpacity(0.5), size: 32),
                                const SizedBox(height: 6),
                                Text('Add Logo', style: TextStyle(fontSize: 11,
                                    color: _blue.withOpacity(0.6),
                                    fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(logoBytes != null ? 'Tap to change logo'
                              : 'Tap to upload management logo',
                              style: const TextStyle(fontSize: 12,
                                  color: _textHint, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          const Text('This logo appears in the dashboard header',
                              style: TextStyle(fontSize: 11, color: _textHint)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ]),
            );
          },
        ),

        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: _teal),
              const SizedBox(height: 12),
              Text(_uploadingLogo ? 'Uploading logo…' : 'Uploading photo…',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ])),
          ),
      ]),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _teal, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: _textHint, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: _textPri)),
      ])),
    ]),
  );
}

// =============================================================================
//  TAB 1 — OVERVIEW
//  FIX: Added missing StreamBuilders for students and records.
//       Original code referenced sSnap/rSnap that were never defined.
// =============================================================================
class _OverviewTab extends StatelessWidget {
  final FirebaseFirestore fs;
  final OrgPath orgPath;
  final String adminOrg;
  const _OverviewTab({required this.fs, required this.orgPath, required this.adminOrg});

  @override
  Widget build(BuildContext context) {
    // Step 1: merge users from both org field variants
    return StreamBuilder<QuerySnapshot>(
      stream: fs.collection('users').where('organisation', isEqualTo: adminOrg).snapshots(),
      builder: (_, snap1) {
        return StreamBuilder<QuerySnapshot>(
          stream: fs.collection('users').where('orgName', isEqualTo: adminOrg).snapshots(),
          builder: (_, snap2) {
            // Merge & deduplicate users
            final Map<String, QueryDocumentSnapshot> mergedUsers = {};
            for (final doc in snap1.data?.docs ?? []) mergedUsers[doc.id] = doc;
            for (final doc in snap2.data?.docs ?? []) mergedUsers[doc.id] = doc;
            final users = mergedUsers.values.toList();

            // Step 2: load students from org subcollection
            return StreamBuilder<QuerySnapshot>(
              stream: orgPath.students(fs).snapshots(),
              builder: (_, sSnap) {
                // Step 3: load all records via collectionGroup filtered by org
                return StreamBuilder<QuerySnapshot>(
                  stream: fs
                      .collectionGroup('records')
                      .where('organisation', isEqualTo: adminOrg)
                      .snapshots(),
                  builder: (_, rSnap) {
                    final students = sSnap.data?.docs ?? [];
                    final records  = rSnap.data?.docs ?? [];

                    final teachers   = users.where((d) => d['userType'] == 'Teacher').length;
                    final therapists = users.where((d) => d['userType'] == 'Therapist').length;
                    final se         = users.where((d) => d['userType'] == 'Special Educator').length;
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
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(child: _OverviewBanner(
                            orgName: adminOrg,
                            totalStaff: totalStaff,
                            totalStudents: students.length,
                            totalRecords: records.length,
                            avgRating: avg,
                            pct: pct)),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 22)),
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
                                _KT('Teachers',   teachers,        _blue,   Icons.person_rounded),
                                _KT('Therapists', therapists,      _teal,   Icons.medical_services_rounded),
                                _KT('Sp. Edu.',   se,              _orange, Icons.school_rounded),
                                _KT('Students',   students.length, _purple, Icons.child_care_rounded),
                                _KT('Records',    records.length,  _green,  Icons.assignment_rounded),
                                _KT('All Staff',  totalStaff,      _navy,   Icons.badge_rounded),
                              ],
                            ),
                          ],
                        )),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 22)),
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
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SH('Staff Breakdown', Icons.people_alt_rounded, _blue),
                            const SizedBox(height: 12),
                            _EC(child: Column(children: [
                              _RB('Teachers',          teachers,   totalStaff, _blue),
                              const SizedBox(height: 12),
                              _RB('Therapists',        therapists, totalStaff, _teal),
                              const SizedBox(height: 12),
                              _RB('Special Educators', se,         totalStaff, _orange),
                            ])),
                          ],
                        )),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    ]);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  final String orgName;
  final int totalStaff, totalStudents, totalRecords;
  final double avgRating, pct;
  const _OverviewBanner({required this.orgName, required this.totalStaff,
    required this.totalStudents, required this.totalRecords,
    required this.avgRating, required this.pct});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(gradient: _gradNavy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.28),
            blurRadius: 18, offset: const Offset(0, 7))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.apartment_rounded, color: _teal, size: 13),
          const SizedBox(width: 5),
          Text(orgName, style: const TextStyle(color: _teal,
              fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SYSTEM OVERVIEW', style: TextStyle(color: Colors.white.withOpacity(0.45),
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
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
        ])),
        const SizedBox(width: 18),
        SizedBox(width: 68, height: 68, child: Stack(alignment: Alignment.center, children: [
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
        ])),
      ]),
    ]),
  );
}

// =============================================================================
//  TAB 2 — STAFF
// =============================================================================
class _StaffTab extends StatelessWidget {
  final FirebaseFirestore fs;
  final OrgPath orgPath;
  final String adminOrg;
  final String expandedRole;
  final ValueChanged<String> onExpand;

  const _StaffTab({required this.fs, required this.orgPath,
    required this.adminOrg, required this.expandedRole, required this.onExpand});

  static const _roles = [
    {'role': 'Teacher',          'icon': Icons.person_rounded,            'color': _blue},
    {'role': 'Special Educator', 'icon': Icons.school_rounded,            'color': _orange},
    {'role': 'Therapist',        'icon': Icons.medical_services_rounded,  'color': _teal},
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: _StaffCountRow(fs: fs, adminOrg: adminOrg, roles: _roles),
        ),
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
              fs: fs,
              role: r['role'] as String,
              icon: r['icon'] as IconData,
              color: r['color'] as Color,
              adminOrg: adminOrg,
              orgPath: orgPath,
              isExpanded: expandedRole == r['role'],
              onTap: () => onExpand(expandedRole == r['role'] ? '' : r['role'] as String),
            )),
          ],
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ]);
  }
}

// ── Staff count row ──────────────────────────────────────────────────────────
class _StaffCountRow extends StatelessWidget {
  final FirebaseFirestore fs;
  final String adminOrg;
  final List<Map<String, Object>> roles;
  const _StaffCountRow({required this.fs, required this.adminOrg, required this.roles});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.collection('users').where('organisation', isEqualTo: adminOrg).snapshots(),
      builder: (_, snap1) {
        return StreamBuilder<QuerySnapshot>(
          stream: fs.collection('users').where('orgName', isEqualTo: adminOrg).snapshots(),
          builder: (_, snap2) {
            final Map<String, QueryDocumentSnapshot> merged = {};
            for (final doc in snap1.data?.docs ?? []) merged[doc.id] = doc;
            for (final doc in snap2.data?.docs ?? []) merged[doc.id] = doc;
            final users = merged.values.toList();

            return Row(children: roles.map((r) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _RST(
                role: r['role'] as String,
                count: users.where((d) => d['userType'] == r['role']).length,
                icon: r['icon'] as IconData,
                color: r['color'] as Color,
              ),
            ))).toList());
          },
        );
      },
    );
  }
}

// ── Expandable staff role section ────────────────────────────────────────────
class _SRS extends StatelessWidget {
  final FirebaseFirestore fs;
  final String role, adminOrg;
  final OrgPath orgPath;
  final IconData icon;
  final Color color;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SRS({required this.fs, required this.role, required this.icon,
    required this.color, required this.isExpanded, required this.onTap,
    required this.adminOrg, required this.orgPath});

  /// Merges staff from both org field variants, deduplicated by doc ID
  Stream<List<QueryDocumentSnapshot>> _staffStream() {
    final s1 = fs.collection('users')
        .where('userType', isEqualTo: role)
        .where('organisation', isEqualTo: adminOrg)
        .snapshots();
    final s2 = fs.collection('users')
        .where('userType', isEqualTo: role)
        .where('orgName', isEqualTo: adminOrg)
        .snapshots();

    return s1.asyncExpand((snap1) => s2.map((snap2) {
      final Map<String, QueryDocumentSnapshot> merged = {};
      for (final doc in snap1.docs) merged[doc.id] = doc;
      for (final doc in snap2.docs) merged[doc.id] = doc;
      return merged.values.toList();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 19)),
              const SizedBox(width: 12),
              Expanded(child: Text(role, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: _textPri))),
              StreamBuilder<List<QueryDocumentSnapshot>>(
                stream: _staffStream(),
                builder: (_, s) {
                  final n = s.data?.length ?? 0;
                  return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
          StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _staffStream(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _teal)));
              }
              final staff = snap.data!;
              if (staff.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('No $role registered.',
                        style: const TextStyle(color: _textHint, fontSize: 13)));
              }
              return Column(children: [
                Divider(height: 1, color: _border.withOpacity(0.5)),
                ...staff.asMap().entries.map((e) {
                  final i   = e.key;
                  final d   = e.value.data() as Map<String, dynamic>;
                  final uid = (d['uid'] ?? e.value.id) as String;
                  return Column(children: [
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StaffDetailPage(
                              staffName: d['name'] ?? '',
                              uid: uid,
                              role: role,
                              color: color,
                              mobile: d['mobile'] ?? '',
                              org: adminOrg,
                              orgPath: orgPath))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(children: [
                          // Photo avatar
                          FutureBuilder<DocumentSnapshot>(
                            future: fs.collection('users').doc(uid).get(),
                            builder: (_, uSnap) {
                              final photoB64 = (uSnap.data?.data()
                              as Map<String, dynamic>?)?['photoUrl'] as String?;
                              final photoBytes = photoB64 != null ? base64Decode(photoB64) : null;
                              return CircleAvatar(
                                radius: 19, backgroundColor: color.withOpacity(0.1),
                                backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                                child: photoBytes == null
                                    ? Text((d['name'] ?? 'S')[0].toUpperCase(),
                                    style: TextStyle(color: color,
                                        fontWeight: FontWeight.w700, fontSize: 15))
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['name'] ?? '', style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13, color: _textPri)),
                              Text('📞 ${d['mobile'] ?? 'No contact'}',
                                  style: const TextStyle(fontSize: 11, color: _textHint)),
                            ],
                          )),
                          // Entry count badge
                          _StaffRecordCountBadge(
                              uid: uid, org: adminOrg, fs: fs, color: color),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded,
                              color: _textHint, size: 18),
                        ]),
                      ),
                    ),
                    if (i < staff.length - 1)
                      Divider(height: 1, indent: 52, color: _border.withOpacity(0.4)),
                  ]);
                }),
              ]);
            },
          ),
      ]),
    );
  }
}

// ── Badge: how many records a staff member has entered ───────────────────────
class _StaffRecordCountBadge extends StatelessWidget {
  final String uid, org;
  final FirebaseFirestore fs;
  final Color color;
  const _StaffRecordCountBadge({required this.uid, required this.org,
    required this.fs, required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.collectionGroup('records')
          .where('enteredByUid', isEqualTo: uid)
          .where('organisation', isEqualTo: org)
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25))),
          child: Text('$count entries',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}

// =============================================================================
//  TAB 3 — STUDENTS
// =============================================================================
class _StudentsTab extends StatelessWidget {
  final FirebaseFirestore fs;
  final OrgPath orgPath;
  const _StudentsTab({required this.fs, required this.orgPath});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: orgPath.students(fs).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        final students = snap.data!.docs;
        if (students.isEmpty) {
          return const _ES(icon: Icons.child_care_rounded,
              message: 'No students enrolled yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          itemCount: students.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _SH('All Students (${students.length})',
                      Icons.people_rounded, _purple));
            }
            final doc = students[i - 1];
            final d   = doc.data() as Map<String, dynamic>;
            return _SSC(studentId: doc.id, data: d, fs: fs, orgPath: orgPath);
          },
        );
      },
    );
  }
}

// =============================================================================
//  STAFF DETAIL PAGE
//  FIX: Entries tab now shows ONLY records entered by this staff (enteredByUid).
//       Overview tab unchanged — shows per-student breakdowns.
// =============================================================================
class StaffDetailPage extends StatefulWidget {
  final String staffName, uid, role, mobile, org;
  final OrgPath orgPath;
  final Color color;

  const StaffDetailPage({super.key,
    required this.staffName, required this.uid, required this.role,
    required this.color, required this.mobile,
    required this.org, required this.orgPath});

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: _surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(112),
        child: Container(
          decoration: const BoxDecoration(gradient: _gradNavy),
          child: SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context)),
                Expanded(child: Text(widget.staffName, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              ]),
            ),
            TabBar(
              controller: _tabs,
              indicatorColor: _teal,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Entries'),
              ],
            ),
          ])),
        ),
      ),
      // FIX: Stream filtered strictly by this staff's uid + org
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.collectionGroup('records')
            .where('organisation', isEqualTo: widget.org)
            .where('enteredByUid', isEqualTo: widget.uid)
            .snapshots(),
        builder: (_, recSnap) {
          if (recSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          // Only this staff member's entries
          final all = recSnap.data?.docs ?? [];

          return TabBarView(
            controller: _tabs,
            children: [
              _StaffOverviewTab(
                  all: all, uid: widget.uid, org: widget.org,
                  staffName: widget.staffName, role: widget.role,
                  mobile: widget.mobile, color: widget.color,
                  orgPath: widget.orgPath),
              _StaffEntriesTab(
                  all: all, uid: widget.uid, org: widget.org,
                  color: widget.color, orgPath: widget.orgPath),
            ],
          );
        },
      ),
    );
  }
}

// ── Staff Overview Tab ────────────────────────────────────────────────────────
class _StaffOverviewTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> all;
  final String uid, org, staffName, role, mobile;
  final Color color;
  final OrgPath orgPath;

  const _StaffOverviewTab({required this.all, required this.uid,
    required this.org, required this.staffName, required this.role,
    required this.mobile, required this.color, required this.orgPath});

  @override
  Widget build(BuildContext context) {
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
    final avg    = all.isEmpty ? 0.0 : rSum / all.length;
    final sorted = List<QueryDocumentSnapshot>.from(all)
      ..sort((a, b) {
        final ta = (a.data() as Map)['timestamp'];
        final tb = (b.data() as Map)['timestamp'];
        if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
        return 0;
      });
    final take  = sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
    final spots = take.asMap().entries.map((e) {
      final r = ((e.value.data() as Map)['rating'] ?? 0) as int;
      return FlSpot(e.key.toDouble(), r.toDouble());
    }).toList();

    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(staffName, style: const TextStyle(color: Colors.white,
                  fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(role, style: TextStyle(color: color,
                        fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: _teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.apartment_rounded, color: _teal, size: 11),
                      const SizedBox(width: 4),
                      Text(org, style: const TextStyle(color: _teal,
                          fontSize: 10, fontWeight: FontWeight.w600)),
                    ])),
              ]),
              const SizedBox(height: 4),
              Text('📞 $mobile', style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 12)),
            ])),
          ]),
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: Row(children: [
          _MK('Students',   sids.length.toString(),    Icons.child_care_rounded, _purple),
          const SizedBox(width: 10),
          _MK('Records',    all.length.toString(),     Icons.assignment_rounded, _teal),
          const SizedBox(width: 10),
          _MK('Avg Rating', avg.toStringAsFixed(1),    Icons.star_rounded, _ratingColor(avg/5)),
        ])),
      ),
      if (all.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ],
      if (spots.length >= 2) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SH('Session Trend', Icons.show_chart_rounded, _teal),
              const SizedBox(height: 12),
              _EC(child: SizedBox(height: 150, child: _TLC(spots: spots))),
            ],
          )),
        ),
      ],
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _SH('Students (${sids.length})', Icons.people_rounded, _purple),
            const SizedBox(height: 12),
            if (sids.isEmpty)
              _EC(child: const _ES(icon: Icons.child_care_outlined,
                  message: 'No student records entered yet.')),
            ...sids.map((sid) => _SSCard(
                studentId: sid, staffUid: uid,
                staffColor: color, orgPath: orgPath)),
          ],
        )),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ]);
  }
}

// ── Staff Entries Tab — shows ONLY this staff member's records ────────────────
class _StaffEntriesTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> all;
  final String uid, org;
  final Color color;
  final OrgPath orgPath;

  const _StaffEntriesTab({required this.all, required this.uid,
    required this.org, required this.color, required this.orgPath});

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return const _ES(icon: Icons.assignment_outlined,
          message: 'No entries by this staff member yet.');
    }

    // Sort newest first
    final sorted = List<QueryDocumentSnapshot>.from(all)
      ..sort((a, b) {
        final ta = (a.data() as Map)['timestamp'];
        final tb = (b.data() as Map)['timestamp'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });

    // Group by student
    final Map<String, List<QueryDocumentSnapshot>> byStudent = {};
    for (final doc in sorted) {
      final d   = doc.data() as Map<String, dynamic>;
      final sid = (d['studentId'] as String?) ?? 'unknown';
      byStudent.putIfAbsent(sid, () => []).add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Summary chip
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Row(children: [
            Icon(Icons.assignment_rounded, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              '${all.length} entries across ${byStudent.length} student${byStudent.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ]),
        ),

        ...byStudent.entries.map((entry) => _StudentEntriesCard(
            studentId: entry.key,
            records: entry.value,
            orgPath: orgPath,
            color: color)),
      ],
    );
  }
}

// ── Card showing all entries for one student (within a staff's entries tab) ──
class _StudentEntriesCard extends StatelessWidget {
  final String studentId;
  final List<QueryDocumentSnapshot> records;
  final OrgPath orgPath;
  final Color color;

  const _StudentEntriesCard({required this.studentId, required this.records,
    required this.orgPath, required this.color});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    return FutureBuilder<DocumentSnapshot>(
      future: orgPath.students(fs).doc(studentId).get(),
      builder: (_, sSnap) {
        final sd         = sSnap.data?.data() as Map<String, dynamic>? ?? {};
        final name       = (sd['name'] as String?) ?? 'Unknown Student';
        final disability = (sd['disability'] as String?) ?? '';

        double avg = 0;
        for (final r in records) {
          avg += ((r.data() as Map)['rating'] ?? 0) as int;
        }
        avg = records.isEmpty ? 0 : avg / records.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
              boxShadow: [BoxShadow(color: _navy.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: CircleAvatar(
                  radius: 20, backgroundColor: _purple.withOpacity(0.1),
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: _purple,
                          fontWeight: FontWeight.w700, fontSize: 15))),
              title: Text(name, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: _textPri)),
              subtitle: Text(
                '${records.length} entr${records.length == 1 ? 'y' : 'ies'}'
                    '${disability.isNotEmpty ? '  ·  $disability' : ''}',
                style: const TextStyle(fontSize: 11, color: _textHint),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _ratingColor(avg / 5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${avg.toStringAsFixed(1)}★',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _ratingColor(avg / 5))),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, color: _textHint, size: 20),
              ]),
              children: [
                Divider(height: 1, color: _border.withOpacity(0.5)),
                ...records.map((doc) {
                  final d         = doc.data() as Map<String, dynamic>;
                  final rating    = (d['rating'] ?? 0) as int;
                  final area      = (d['areaOfSupport'] ?? 'General') as String;
                  final challenge = (d['challenge'] ?? d['note'] ?? 'No notes') as String;
                  final String dateStr = d['timestamp'] is Timestamp
                      ? DateFormat('dd MMM yyyy').format(
                      (d['timestamp'] as Timestamp).toDate())
                      : (d['date'] ?? '') as String;

                  return Container(
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                            color: _border.withOpacity(0.35), width: 0.8))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Rating badge
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              color: _ratingColor(rating / 5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text('$rating★',
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _ratingColor(rating / 5)))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(area,
                                    style: TextStyle(fontSize: 10, color: color,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const Spacer(),
                              Text(dateStr,
                                  style: const TextStyle(
                                      fontSize: 10, color: _textHint)),
                            ]),
                            const SizedBox(height: 5),
                            Text(challenge,
                                style: const TextStyle(
                                    fontSize: 12, color: _textPri, height: 1.4),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                          ],
                        )),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
//  STUDENT CARDS & PAGES
// =============================================================================
class _SSC extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> data;
  final FirebaseFirestore fs;
  final OrgPath orgPath;
  const _SSC({required this.studentId, required this.data,
    required this.fs, required this.orgPath});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: orgPath.records(fs, studentId).snapshots(),
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
        return _StudentCard(
          name: data['name'] ?? 'Student',
          age: data['age']?.toString() ?? '—',
          disability: data['disability'] ?? '—',
          pct: pct, recCount: recs.length,
          areas: areas, color: _teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StudentPerformanceDetailPage(
                  studentId: studentId,
                  studentName: data['name'] ?? 'Student',
                  orgPath: orgPath))),
        );
      },
    );
  }
}

class _SSCard extends StatelessWidget {
  final String studentId, staffUid;
  final Color staffColor;
  final OrgPath orgPath;
  const _SSCard({required this.studentId, required this.staffUid,
    required this.staffColor, required this.orgPath});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return FutureBuilder<DocumentSnapshot>(
      future: orgPath.students(fs).doc(studentId).get(),
      builder: (_, sSnap) {
        if (!sSnap.hasData) return const _SK();
        if (!sSnap.data!.exists) return const SizedBox.shrink();
        final sd = sSnap.data!.data() as Map<String, dynamic>;
        return StreamBuilder<QuerySnapshot>(
          stream: orgPath.records(fs, studentId).snapshots(),
          builder: (_, rSnap) {
            final allRecs = rSnap.data?.docs ?? [];
            final recs = allRecs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['enteredByUid'] == staffUid ||
                  d['staffUid'] == staffUid ||
                  d['createdByUid'] == staffUid;
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
                      uid: staffUid,
                      orgPath: orgPath))),
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
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: _purple.withOpacity(0.1),
              child: Text(name[0].toUpperCase(),
                  style: const TextStyle(color: _purple,
                      fontWeight: FontWeight.w700, fontSize: 15))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: _textPri)),
            Text('Age $age  ·  $disability',
                style: const TextStyle(fontSize: 11, color: _textHint)),
          ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: _ratingColor(pct).withOpacity(0.1),
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
              children: areas.take(4).map((a) => _CB(label: a, color: color)).toList()),
        ],
        const SizedBox(height: 6),
        Text('$recCount records', style: const TextStyle(fontSize: 11, color: _textHint)),
      ]),
    ),
  );
}

// =============================================================================
//  STUDENT AREA PROGRESS PAGE
// =============================================================================
class StudentAreaProgressPage extends StatelessWidget {
  final String studentId, studentName, uid;
  final OrgPath orgPath;
  const StudentAreaProgressPage({super.key,
    required this.studentId, required this.studentName,
    required this.uid, required this.orgPath});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBarWithAction(context, '$studentName — Progress',
          Icons.bar_chart_rounded, () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => StudentPerformanceDetailPage(
                  studentId: studentId,
                  studentName: studentName,
                  orgPath: orgPath)))),
      body: StreamBuilder<QuerySnapshot>(
        stream: orgPath.records(fs, studentId)
            .orderBy('timestamp', descending: true).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          final allDocs = snap.data?.docs ?? [];
          final filtered = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['enteredByUid'] == uid ||
                d['staffUid'] == uid ||
                d['createdByUid'] == uid;
          }).toList();
          if (filtered.isEmpty) {
            return const _ES(icon: Icons.assignment_outlined,
                message: 'No records by this staff for this student.');
          }
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (final r in filtered) {
            final area = ((r.data() as Map)['areaOfSupport'] ?? 'Other') as String;
            grouped.putIfAbsent(area, () => []).add(r);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final aRecs = entry.value;
              int r1=0,r2=0,r3=0,r4=0,r5=0; double avg = 0;
              for (final r in aRecs) {
                final rating = ((r.data() as Map)['rating'] ?? 0) as int;
                avg += rating;
                if (rating==1) r1++;
                if (rating==2) r2++;
                if (rating==3) r3++;
                if (rating==4) r4++;
                if (rating==5) r5++;
              }
              avg = avg / aRecs.length;
              final progress = avg / 5.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border.withOpacity(0.6), width: 0.8)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Icon(Icons.psychology_rounded,
                        color: _ratingColor(progress), size: 22),
                    title: Text(entry.key, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: _textPri)),
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
                    children: [Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Divider(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          _SC(star:1, count:r1), _SC(star:2, count:r2),
                          _SC(star:3, count:r3), _SC(star:4, count:r4), _SC(star:5, count:r5),
                        ]),
                        const Divider(height: 16),
                        ...aRecs.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final int rating = (d['rating'] ?? 0) as int;
                          final String date = d['timestamp'] is Timestamp
                              ? DateFormat('dd MMM yyyy').format(
                              (d['timestamp'] as Timestamp).toDate())
                              : d['date'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Icon(Icons.circle, size: 5, color: _ratingColor(rating / 5)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(d['challenge'] ?? 'No challenge',
                                  style: const TextStyle(fontSize: 12, color: _textPri),
                                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              _SB(rating: rating),
                              const SizedBox(width: 6),
                              Text(date, style: const TextStyle(
                                  fontSize: 10, color: _textHint)),
                            ]),
                          );
                        }),
                      ]),
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
  final OrgPath orgPath;
  const StudentPerformanceDetailPage({super.key,
    required this.studentId, required this.studentName, required this.orgPath});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: _surface,
      appBar: _gradAppBar(context, '$studentName — Performance'),
      body: StreamBuilder<QuerySnapshot>(
        stream: orgPath.records(fs, studentId)
            .orderBy('timestamp', descending: false).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const _ES(icon: Icons.insert_chart_outlined_rounded,
                message: 'No performance records available.');
          }
          final records = snap.data!.docs;
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          int r1=0,r2=0,r3=0,r4=0,r5=0; double rSum = 0;
          for (final doc in records) {
            final d      = doc.data() as Map<String, dynamic>;
            final area   = (d['areaOfSupport'] ?? 'Other') as String;
            final rating = (d['rating'] ?? 0) as int;
            rSum += rating;
            if (rating==1) r1++;
            if (rating==2) r2++;
            if (rating==3) r3++;
            if (rating==4) r4++;
            if (rating==5) r5++;
            grouped.putIfAbsent(area, () => []).add(d);
          }
          final avgRating  = rSum / records.length;
          final overallPct = avgRating / 5.0;
          final trendDocs  = records.length > 12
              ? records.sublist(records.length - 12) : records;
          final spots = trendDocs.asMap().entries.map((e) {
            final d = e.value.data() as Map<String, dynamic>;
            return FlSpot(e.key.toDouble(), ((d['rating'] ?? 0) as int).toDouble());
          }).toList();

          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              _MK('Records', records.length.toString(), Icons.assignment_rounded, _teal),
              const SizedBox(width: 10),
              _MK('Avg', avgRating.toStringAsFixed(1), Icons.star_rounded,
                  _ratingColor(overallPct)),
              const SizedBox(width: 10),
              _MK('Progress', '${(overallPct*100).toStringAsFixed(0)}%',
                  Icons.trending_up_rounded, _ratingColor(overallPct)),
              const SizedBox(width: 10),
              _MK('Areas', grouped.keys.length.toString(),
                  Icons.category_rounded, _purple),
            ]),
            const SizedBox(height: 16),
            _EC(child: Row(children: [
              SizedBox(width: 88, height: 88, child: Stack(alignment: Alignment.center,
                  children: [
                    SizedBox(width: 88, height: 88,
                        child: CircularProgressIndicator(value: overallPct, strokeWidth: 8,
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(_ratingColor(overallPct)),
                            strokeCap: StrokeCap.round)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(overallPct*100).toStringAsFixed(0)}%',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
                              color: _ratingColor(overallPct))),
                      const Text('overall',
                          style: TextStyle(fontSize: 9, color: _textHint)),
                    ]),
                  ])),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SR('Avg Rating', '${avgRating.toStringAsFixed(2)} / 5.0'),
                    _SR('Total Records', records.length.toString()),
                    _SR('Support Areas', grouped.keys.length.toString()),
                    _SR('Status',
                        overallPct >= 0.75 ? 'Good Progress'
                            : overallPct >= 0.5 ? 'Average' : 'Needs Attention',
                        valueColor: _ratingColor(overallPct)),
                  ])),
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
            _EC(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Last ${spots.length} sessions',
                  style: const TextStyle(fontSize: 11, color: _textHint)),
              const SizedBox(height: 12),
              SizedBox(height: 140, child: _TLC(spots: spots)),
            ])),
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
              _EC(child: SizedBox(height: 220, child: _ARC(grouped: grouped))),
            ],
            const SizedBox(height: 24),
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

PreferredSizeWidget _gradAppBarWithAction(BuildContext context, String title,
    IconData actionIcon, VoidCallback onAction) {
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
//  SHARED UI WIDGETS
// =============================================================================
class _EC extends StatelessWidget {
  final Widget child; final EdgeInsets? padding;
  const _EC({required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(color: _navy.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: _navy.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1)),
        ]),
    child: child,
  );
}

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
    Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: _textPri)),
  ]);
}

class _KT extends StatelessWidget {
  final String title; final int value; final Color color; final IconData icon;
  const _KT(this.title, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))]),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 17)),
      const SizedBox(height: 8),
      Text(value.toString(), style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(title, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: _textHint)),
    ]),
  );
}

class _RST extends StatelessWidget {
  final String role; final int count; final IconData icon; final Color color;
  const _RST({required this.role, required this.count,
    required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.6), width: 0.8),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 8),
      Text('$count', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(role, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
              color: _textHint)),
    ]),
  );
}

class _MK extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _MK(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withOpacity(0.6), width: 0.8)),
    child: Column(children: [
      Icon(icon, color: color, size: 19), const SizedBox(height: 5),
      Text(value, style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: _textHint),
          textAlign: TextAlign.center),
    ]),
  ));
}

class _DR extends StatelessWidget {
  final String label; final int star, count, total; final Color color;
  const _DR(this.label, this.star, this.count, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('$star★',
              style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w800, color: color)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _textPri))),
          Text('$count', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 5),
          Text('(${(pct*100).toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 10, color: _textHint)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 6,
                backgroundColor: color.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(color))),
      ])),
    ]));
  }
}

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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
    ]);
  }
}

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

class _CB extends StatelessWidget {
  final String label; final Color color;
  const _CB({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: TextStyle(
        fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

class _SC extends StatelessWidget {
  final int star, count; const _SC({required this.star, required this.count});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$star★', style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: _textPri)),
    Text('$count', style: const TextStyle(fontSize: 11, color: _textHint)),
  ]);
}

class _SB extends StatelessWidget {
  final int rating; const _SB({required this.rating});
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

class _AET extends StatelessWidget {
  final String area;
  final List<Map<String, dynamic>> records;
  final double avgRating;
  const _AET({required this.area, required this.records, required this.avgRating});
  @override
  Widget build(BuildContext context) {
    final progress = avgRating / 5.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border.withOpacity(0.6), width: 0.8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Icon(Icons.psychology_rounded,
              color: _ratingColor(progress), size: 20),
          title: Text(area, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: _textPri)),
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
          children: [Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(height: 12),
              ...records.take(4).map((d) {
                final rating = (d['rating'] ?? 0) as int;
                final date = d['timestamp'] is Timestamp
                    ? DateFormat('dd MMM').format(
                    (d['timestamp'] as Timestamp).toDate())
                    : d['date'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.circle, size: 5, color: _ratingColor(rating / 5)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d['challenge'] ?? 'N/A',
                        style: const TextStyle(fontSize: 11, color: _textPri),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    _SB(rating: rating),
                    const SizedBox(width: 6),
                    Text(date, style: const TextStyle(fontSize: 10, color: _textHint)),
                  ]),
                );
              }),
              if (records.length > 4)
                Text('+${records.length - 4} more',
                    style: const TextStyle(fontSize: 11, color: _textHint)),
            ]),
          )],
        ),
      ),
    );
  }
}

class _ARC extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> grouped;
  const _ARC({required this.grouped});
  @override
  Widget build(BuildContext context) {
    final areas  = grouped.keys.toList();
    final values = areas.map((a) {
      final ratings = grouped[a]!.map((d) => (d['rating'] ?? 0) as int).toList();
      return ratings.reduce((x, y) => x + y) / ratings.length;
    }).toList();
    return RadarChart(RadarChartData(
      radarShape: RadarShape.polygon,
      dataSets: [RadarDataSet(
          fillColor: _teal.withOpacity(0.15),
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
      titleTextStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: _textPri),
      titlePositionPercentageOffset: 0.18,
    ));
  }
}

class _TLC extends StatelessWidget {
  final List<FlSpot> spots;
  const _TLC({required this.spots});
  @override
  Widget build(BuildContext context) => LineChart(LineChartData(
    minY: 0, maxY: 6,
    lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => _navy,
        getTooltipItems: (ts) => ts.map((s) => LineTooltipItem('${s.y.toInt()}★',
            const TextStyle(color: Colors.white, fontSize: 12))).toList())),
    gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1,
        getDrawingHorizontalLine: (_) => FlLine(color: _border, strokeWidth: 0.8)),
    titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            interval: 1, reservedSize: 24,
            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                style: const TextStyle(fontSize: 9, color: _textHint)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) => Text('S${v.toInt()+1}',
                style: const TextStyle(fontSize: 9, color: _textHint)))),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
    borderData: FlBorderData(show: false),
    lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, color: _teal, barWidth: 2.5,
        dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) =>
            FlDotCirclePainter(radius: 3, color: _teal,
                strokeWidth: 2, strokeColor: Colors.white)),
        belowBarData: BarAreaData(show: true,
            color: _teal.withOpacity(0.08)))],
  ));
}

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
          style: const TextStyle(fontSize: 14, color: _textHint,
              fontWeight: FontWeight.w500)),
    ]),
  );
}

class _SK extends StatelessWidget {
  const _SK();
  @override
  Widget build(BuildContext context) => Container(
    height: 72, margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: _border.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14)),
  );
}