import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_page.dart';

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

class ProfilePage extends StatefulWidget {
  final String name;
  final String age;
  final String whoYouAre;
  final String mobile;
  final String gender;

  const ProfilePage({
    super.key,
    required this.name,
    required this.age,
    required this.whoYouAre,
    required this.mobile,
    required this.gender,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _fs   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool loading    = false;
  bool _uploading = false;
  String? _photoBase64;

  // ── Organisation state ──────────────────────────────────────
  String? _orgId;
  String? _orgName;
  bool    _orgMissing = false;

  // ── Bottom-sheet-local org state ────────────────────────────
  final _orgSearchController = TextEditingController();
  final _orgNewController    = TextEditingController();
  List<Map<String, String>> _orgSuggestions = [];
  bool   _orgSearching = false;
  bool   _orgLocked    = false;
  String? _sheetOrgId;
  String? _sheetOrgName;
  Timer?  _debounce;

  bool get _isAdmin     => widget.whoYouAre == 'Admin';
  bool get _isStaffRole =>
      widget.whoYouAre == 'Teacher' ||
          widget.whoYouAre == 'Special Educator' ||
          widget.whoYouAre == 'Therapist';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ─────────────────────────────────────────────────────────
  //  LOAD USER DATA
  //  FIX: For admins, org name is read from admins/{uid}
  //       (source of truth). For staff, read from users/{uid}.
  //  Both use streams so changes propagate live.
  // ─────────────────────────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<DocumentSnapshot>? _adminDocSub;

  void _loadUserData() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // ── Always stream users doc for photo + orgId ──
    _userDocSub = _fs.collection('users').doc(uid).snapshots().listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        _photoBase64 = data['photoUrl'] as String?;
        _orgId       = data['orgId']   as String?;

        // For staff: org name comes from users doc
        if (!_isAdmin) {
          // Prefer 'orgName', fall back to 'organisation'
          final fromOrgName     = data['orgName']      as String?;
          final fromOrganisation = data['organisation'] as String?;
          _orgName    = (fromOrgName?.isNotEmpty == true)
              ? fromOrgName
              : fromOrganisation;
          _orgMissing = (_orgName == null || _orgName!.isEmpty);
        }
      });
    });

    // ── For admins: also stream admins doc (source of truth for org) ──
    if (_isAdmin) {
      _adminDocSub = _fs.collection('admins').doc(uid).snapshots().listen((doc) {
        if (!doc.exists || !mounted) return;
        final data = doc.data()!;
        final adminOrg = data['organisation'] as String?;
        setState(() {
          _orgName    = (adminOrg?.isNotEmpty == true) ? adminOrg : null;
          _orgMissing = (_orgName == null || _orgName!.isEmpty);
        });
      });
    }
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    _adminDocSub?.cancel();
    _orgSearchController.dispose();
    _orgNewController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  ORG SEARCH  (sheet-only state)
  // ─────────────────────────────────────────────────────────
  StateSetter? _sheetSS;

  void _sheetUpdate(VoidCallback fn) {
    setState(fn);
    _sheetSS?.call(() {});
  }

  void _onOrgSearchChanged(String value) {
    _debounce?.cancel();
    if (value.length < 3) {
      _sheetUpdate(() {
        _orgSuggestions = [];
        _orgSearching   = false;
      });
      return;
    }
    _sheetUpdate(() => _orgSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = value.toLowerCase();
      try {
        final snap = await _fs
            .collection('organisations')
            .where('nameLower', isGreaterThanOrEqualTo: query)
            .where('nameLower', isLessThan: '$query\uf8ff')
            .limit(5)
            .get();
        if (!mounted) return;
        _sheetUpdate(() {
          _orgSuggestions = snap.docs
              .map((d) => {'id': d.id, 'name': d['name'] as String})
              .toList();
          _orgSearching = false;
        });
      } catch (_) {
        if (mounted) _sheetUpdate(() => _orgSearching = false);
      }
    });
  }

  void _selectSheetOrg(String id, String name) {
    _sheetUpdate(() {
      _sheetOrgId               = id;
      _sheetOrgName             = name;
      _orgLocked                = true;
      _orgSuggestions           = [];
      _orgSearchController.text = name;
    });
  }

  void _clearSheetOrg() {
    _sheetUpdate(() {
      _sheetOrgId   = null;
      _sheetOrgName = null;
      _orgLocked    = false;
      _orgSuggestions = [];
      _orgSearchController.clear();
    });
  }

  // ─────────────────────────────────────────────────────────
  //  SAVE ORG
  //  FIX: Admin saves to BOTH admins/{uid} AND users/{uid}
  //       + propagates to all org members.
  //       Staff saves to users/{uid} only.
  // ─────────────────────────────────────────────────────────
  Future<void> _saveOrganisation() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String? newOrgId;
    String? newOrgName;

    if (_isAdmin) {
      final name = _orgNewController.text.trim();
      if (name.isEmpty) {
        _showSnackBar('Enter your organisation name.');
        return;
      }

      if (_orgId != null && _orgId!.isNotEmpty) {
        // ── Update existing org ──
        await _fs.collection('organisations').doc(_orgId).update({
          'name'     : name,
          'nameLower': name.toLowerCase(),
        });
        newOrgId   = _orgId;
        newOrgName = name;
      } else {
        // ── Create new org — check for duplicate first ──
        final dupCheck = await _fs
            .collection('organisations')
            .where('nameLower', isEqualTo: name.toLowerCase())
            .limit(1)
            .get();

        if (dupCheck.docs.isNotEmpty) {
          newOrgId   = dupCheck.docs.first.id;
          newOrgName = dupCheck.docs.first['name'] as String;
          _showSnackBar('Organisation "$newOrgName" already exists — joined it.');
        } else {
          final orgRef = _fs.collection('organisations').doc();
          await orgRef.set({
            'name'     : name,
            'nameLower': name.toLowerCase(),
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive' : true,
          });
          newOrgId   = orgRef.id;
          newOrgName = name;
        }
      }
    } else if (_isStaffRole) {
      if (_sheetOrgId == null) {
        _showSnackBar('Please search and select your organisation.');
        return;
      }
      newOrgId   = _sheetOrgId;
      newOrgName = _sheetOrgName;
    }

    if (newOrgId == null) return;

    setState(() => loading = true);
    try {
      if (_isAdmin) {
        // ── FIX: Admin writes to admins (source of truth) + users ──
        final oldOrgName = _orgName ?? '';

        // 1. Update admins doc
        await _fs.collection('admins').doc(uid).set({
          'organisation': newOrgName,
        }, SetOptions(merge: true));

        // 2. Update admin's own users doc
        await _fs.collection('users').doc(uid).update({
          'orgId'       : newOrgId,
          'orgName'     : newOrgName,
          'organisation': newOrgName,
        });

        // 3. Propagate to all staff in this org
        if (newOrgName != null && newOrgName != oldOrgName && oldOrgName.isNotEmpty) {
          await _propagateOrgNameChange(
            orgId:      newOrgId,
            newOrgName: newOrgName,
            uid:        uid,
            oldOrgName: oldOrgName,
          );
        }
      } else {
        // ── Staff: update users doc only ──
        await _fs.collection('users').doc(uid).update({
          'orgId'       : newOrgId,
          'orgName'     : newOrgName,
          'organisation': newOrgName,
        });
      }

      // Close sheet before migration popup
      if (mounted) Navigator.pop(context);

      // ── Migrate old flat records if any ──
      await _migrateOldRecords(
        uid:     uid,
        orgId:   newOrgId,
        orgName: newOrgName ?? '',
      );

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() => loading = false);
      _showSnackBar('Failed to save: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  PROPAGATE ORG NAME CHANGE
  //  FIX: now also updates 'organisation' field (not just 'orgName')
  //       and updates users matched by either field name.
  // ─────────────────────────────────────────────────────────
  Future<void> _propagateOrgNameChange({
    required String orgId,
    required String newOrgName,
    required String uid,
    String oldOrgName = '',
  }) async {
    // 1. Update the organisations doc itself
    await _fs.collection('organisations').doc(orgId).update({
      'name'     : newOrgName,
      'nameLower': newOrgName.toLowerCase(),
    });

    // 2. Update all students under this org
    final studentsSnap = await _fs
        .collection('organisations')
        .doc(orgId)
        .collection('students')
        .get();

    for (int i = 0; i < studentsSnap.docs.length; i += 400) {
      final chunk = studentsSnap.docs.sublist(
          i, (i + 400).clamp(0, studentsSnap.docs.length));
      final batch = _fs.batch();
      for (final sDoc in chunk) {
        batch.update(sDoc.reference, {'orgName': newOrgName});

        // 3. Update all records for this student
        final recsSnap = await sDoc.reference.collection('records').get();
        for (int j = 0; j < recsSnap.docs.length; j += 400) {
          final recChunk = recsSnap.docs.sublist(
              j, (j + 400).clamp(0, recsSnap.docs.length));
          final recBatch = _fs.batch();
          for (final rDoc in recChunk) {
            recBatch.update(rDoc.reference, {
              'orgName'     : newOrgName,
              'organisation': newOrgName,
            });
          }
          await recBatch.commit();
        }
      }
      await batch.commit();
    }

    // 4. Update all users matched by 'organisation' field
    if (oldOrgName.isNotEmpty) {
      final usersSnap = await _fs
          .collection('users')
          .where('organisation', isEqualTo: oldOrgName)
          .get();
      if (usersSnap.docs.isNotEmpty) {
        for (int i = 0; i < usersSnap.docs.length; i += 400) {
          final chunk = usersSnap.docs.sublist(
              i, (i + 400).clamp(0, usersSnap.docs.length));
          final batch = _fs.batch();
          for (final uDoc in chunk) {
            batch.update(uDoc.reference, {
              'orgName'     : newOrgName,
              'organisation': newOrgName,
            });
          }
          await batch.commit();
        }
      }

      // 5. Also update users matched by 'orgName' field (belt-and-suspenders)
      final usersSnap2 = await _fs
          .collection('users')
          .where('orgName', isEqualTo: oldOrgName)
          .get();
      if (usersSnap2.docs.isNotEmpty) {
        for (int i = 0; i < usersSnap2.docs.length; i += 400) {
          final chunk = usersSnap2.docs.sublist(
              i, (i + 400).clamp(0, usersSnap2.docs.length));
          final batch = _fs.batch();
          for (final uDoc in chunk) {
            batch.update(uDoc.reference, {
              'orgName'     : newOrgName,
              'organisation': newOrgName,
            });
          }
          await batch.commit();
        }
      }
    }

    // 6. Update admin's own admins/{uid} doc
    try {
      await _fs.collection('admins').doc(uid).update({
        'organisation': newOrgName,
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  //  MIGRATE OLD FLAT RECORDS → ORG-SCOPED PATH
  // ─────────────────────────────────────────────────────────
  Future<void> _migrateOldRecords({
    required String uid,
    required String orgId,
    required String orgName,
  }) async {
    final userSnap = await _fs.collection('users').doc(uid).get();
    if (userSnap.data()?['migrationDone'] == true) return;

    final check = await _fs
        .collection('students')
        .where('createdBy', isEqualTo: uid)
        .limit(1)
        .get();
    if (check.docs.isEmpty) {
      await _fs.collection('users').doc(uid).update({'migrationDone': true});
      return;
    }

    final confirmed = await _migrationConfirmDialog(orgName: orgName);
    if (confirmed != true) return;

    setState(() => loading = true);
    _showSnackBar('Migrating records… please wait.');

    try {
      int totalMigrated = 0;
      QuerySnapshot snap;

      do {
        snap = await _fs
            .collection('students')
            .where('createdBy', isEqualTo: uid)
            .limit(100)
            .get();
        if (snap.docs.isEmpty) break;

        for (final studentDoc in snap.docs) {
          final sid   = studentDoc.id;
          final sData = studentDoc.data() as Map<String, dynamic>;

          final orgStudentRef = _fs
              .collection('organisations')
              .doc(orgId)
              .collection('students')
              .doc(sid);

          await orgStudentRef.set(
            {...sData, 'orgId': orgId, 'orgName': orgName},
            SetOptions(merge: true),
          );

          final oldRecords = await _fs
              .collection('students')
              .doc(sid)
              .collection('records')
              .get();

          if (oldRecords.docs.isNotEmpty) {
            for (int i = 0; i < oldRecords.docs.length; i += 500) {
              final chunk = oldRecords.docs.sublist(
                  i, (i + 500).clamp(0, oldRecords.docs.length));
              final batch = _fs.batch();
              for (final recDoc in chunk) {
                final newRef = _fs
                    .collection('organisations')
                    .doc(orgId)
                    .collection('students')
                    .doc(sid)
                    .collection('records')
                    .doc(recDoc.id);

                batch.set(newRef, {
                  ...recDoc.data() as Map<String, dynamic>,
                  'orgId'       : orgId,
                  'orgName'     : orgName,
                  'organisation': orgName,
                  'enteredByUid': uid,
                }, SetOptions(merge: true));

                batch.delete(recDoc.reference);
              }
              await batch.commit();
            }
          }

          await studentDoc.reference.delete();
          totalMigrated++;
        }
      } while (snap.docs.length == 100);

      await _fs.collection('users').doc(uid).update({'migrationDone': true});

      if (!mounted) return;
      setState(() => loading = false);
      _showSnackBar(
        totalMigrated > 0
            ? '✓ $totalMigrated student(s) moved to "$orgName".'
            : 'All records already up to date.',
      );
    } catch (e) {
      if (mounted) setState(() => loading = false);
      _showSnackBar('Migration failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  MIGRATION CONFIRM DIALOG
  // ─────────────────────────────────────────────────────────
  Future<bool?> _migrationConfirmDialog({required String orgName}) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _T.teal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.sync_rounded, color: _T.teal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Move Records to Organisation',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                            color: _T.textPri)),
                  ),
                ]),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: _T.textSub, height: 1.6),
                    children: [
                      const TextSpan(text: 'Your existing student records will be moved to '),
                      TextSpan(text: '"$orgName"',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: _T.textPri)),
                      const TextSpan(
                          text: '.\n\nAll data (records, ratings, notes) will be preserved. '
                              'New entries will automatically go under this organisation.'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _T.textSub,
                          side: const BorderSide(color: _T.border, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Skip',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _T.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Move Now',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────
  //  ORG EDIT BOTTOM SHEET
  // ─────────────────────────────────────────────────────────
  void _showOrgEditSheet() {
    if (_isAdmin) {
      _orgNewController.text = _orgName ?? '';
    } else {
      _clearSheetOrg();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _T.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) {
          _sheetSS = ss;

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: _T.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Organisation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: _T.textPri)),
                const SizedBox(height: 4),
                Text(
                  _isAdmin
                      ? 'Set or update your school / centre name.'
                      : 'Search and select the organisation you belong to.',
                  style: const TextStyle(fontSize: 12, color: _T.textSub),
                ),
                const SizedBox(height: 16),

                // ── Admin: free-text field ──
                if (_isAdmin)
                  TextField(
                    controller: _orgNewController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => _sheetSS?.call(() {}),
                    decoration: _orgInputDec(
                      'Organisation Name',
                      hint: 'Enter school / centre name',
                      icon: Icons.business_outlined,
                    ),
                  ),

                // ── Staff: search + suggestion list ──
                if (_isStaffRole) ...[
                  TextField(
                    controller: _orgSearchController,
                    enabled: !_orgLocked,
                    decoration: _orgInputDec(
                      'Search Organisation',
                      hint: 'Type 3+ letters to search',
                      icon: Icons.search_rounded,
                    ).copyWith(
                      fillColor: _orgLocked ? _T.tealLight : _T.surface,
                      suffixIcon: _orgLocked
                          ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: _T.textSub),
                        onPressed: _clearSheetOrg,
                      )
                          : _orgSearching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: _T.teal),
                        ),
                      )
                          : null,
                    ),
                    onChanged: _onOrgSearchChanged,
                  ),

                  if (_orgSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: _T.card,
                        border: Border.all(color: _T.border),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3))],
                      ),
                      child: Column(
                        children: _orgSuggestions.map((org) =>
                            InkWell(
                              onTap: () => _selectSheetOrg(org['id']!, org['name']!),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                child: Row(children: [
                                  const Icon(Icons.business_outlined,
                                      size: 16, color: _T.textSub),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(org['name']!,
                                      style: const TextStyle(
                                          fontSize: 13, color: _T.textPri))),
                                ]),
                              ),
                            )).toList(),
                      ),
                    ),

                  if (!_orgSearching &&
                      _orgSuggestions.isEmpty &&
                      _orgSearchController.text.length >= 3 &&
                      !_orgLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'No organisation found. Ask your admin to register first.',
                        style: TextStyle(fontSize: 11,
                            color: _T.textSub.withOpacity(0.8)),
                      ),
                    ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveOrganisation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Organisation',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => _sheetSS = null);
  }

  InputDecoration _orgInputDec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18, color: _T.textSub) : null,
        labelStyle: const TextStyle(color: _T.textSub, fontSize: 13),
        hintStyle: TextStyle(color: _T.textSub.withOpacity(0.6), fontSize: 13),
        filled: true,
        fillColor: _T.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _T.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _T.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _T.teal, width: 1.5)),
      );

  // ─────────────────────────────────────────────────────────
  //  PHOTO BOTTOM SHEET
  // ─────────────────────────────────────────────────────────
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _T.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _T.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Update Profile Photo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: _T.textPri)),
              ),
              const SizedBox(height: 12),
              _sheetTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadPhoto(ImageSource.gallery);
                },
              ),
              _sheetTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadPhoto(ImageSource.camera);
                },
              ),
              if (_photoBase64 != null)
                _sheetTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Photo',
                  color: _T.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await _removePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _T.textPri,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color == _T.red ? _T.red.withOpacity(0.08) : _T.tealLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );

  // ─────────────────────────────────────────────────────────
  //  UPLOAD / REMOVE PHOTO
  // ─────────────────────────────────────────────────────────
  Future<void> _uploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 50, maxWidth: 300);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final uid       = _auth.currentUser!.uid;
      final bytes     = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      await _fs.collection('users').doc(uid)
          .set({'photoUrl': base64Str}, SetOptions(merge: true));

      setState(() => _photoBase64 = base64Str);
      _showSnackBar('Profile photo updated!');
    } catch (e) {
      _showSnackBar('Upload failed: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    try {
      final uid = _auth.currentUser!.uid;
      await _fs.collection('users').doc(uid)
          .update({'photoUrl': FieldValue.delete()});
      setState(() => _photoBase64 = null);
      _showSnackBar('Profile photo removed.');
    } catch (e) {
      _showSnackBar('Remove failed: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  DELETE ACCOUNT
  // ─────────────────────────────────────────────────────────
  Future<void> deleteAccount(String password) async {
    try {
      setState(() => loading = true);
      final user  = _auth.currentUser!;
      final email = user.email!;
      final cred  = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);

      final userDoc = await _fs.collection('users').doc(user.uid).get();
      await _fs.collection('archived_users').doc(user.uid).set({
        'profile'  : userDoc.data(),
        'deletedAt': DateTime.now(),
      });

      await _fs.collection('users').doc(user.uid).delete();
      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
              (route) => false);
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Delete failed: $e');
    }
  }

  void _showDeleteDialog() {
    String password = '';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _T.red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: _T.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Delete Account',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: _T.textPri)),
                ),
              ]),
              const SizedBox(height: 14),
              const Text(
                'This action is permanent. All your data will be '
                    'archived and your account will be deleted.',
                style: TextStyle(fontSize: 13, color: _T.textSub, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                obscureText: true,
                style: const TextStyle(color: _T.textPri, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: _T.textSub, fontSize: 12),
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(
                      color: _T.textSub.withOpacity(0.6), fontSize: 13),
                  filled: true,
                  fillColor: _T.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _T.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _T.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _T.red, width: 1.5)),
                ),
                onChanged: (v) => password = v,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _T.textSub,
                      side: const BorderSide(color: _T.border),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    deleteAccount(password);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _T.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text('Delete Account',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _T.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text('Profile',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20),
              tooltip: 'Logout',
              onPressed: () async {
                await _auth.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                        (route) => false);
              },
            ),
          ),
        ],
      ),
      body: Stack(children: [
        SingleChildScrollView(
          child: Column(children: [
            _buildProfileHeader(),

            if (_orgMissing && (_isAdmin || _isStaffRole))
              _buildMigrationBanner(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: _T.textPri)),
                  const SizedBox(height: 14),
                  _buildInfoCard(icon: Icons.person_outline_rounded,
                      label: 'Full Name', value: widget.name),
                  _buildInfoCard(icon: Icons.cake_outlined,
                      label: 'Age', value: widget.age),
                  _buildInfoCard(icon: Icons.work_outline_rounded,
                      label: 'Role', value: widget.whoYouAre),
                  _buildInfoCard(icon: Icons.phone_android_rounded,
                      label: 'Mobile Number', value: widget.mobile),
                  _buildInfoCard(icon: Icons.wc_rounded,
                      label: 'Gender', value: widget.gender),

                  if (_isAdmin || _isStaffRole) ...[
                    const SizedBox(height: 24),
                    const Text('Organisation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                            color: _T.textPri)),
                    const SizedBox(height: 14),
                    _buildOrgCard(),
                  ],

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showDeleteDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Delete Account',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _T.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _T.red.withOpacity(0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, color: _T.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Deletion is permanent. Your data will be archived.',
                        style: TextStyle(fontSize: 12, color: _T.red,
                            fontWeight: FontWeight.w500),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ]),
        ),

        if (loading || _uploading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: _T.teal),
                const SizedBox(height: 12),
                Text(
                  _uploading ? 'Uploading photo...' : 'Migrating records…',
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  MIGRATION BANNER
  // ─────────────────────────────────────────────────────────
  Widget _buildMigrationBanner() => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _T.orange.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _T.orange.withOpacity(0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.business_outlined, color: _T.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('Organisation not set',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _T.orange)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Set your organisation so your student records are properly '
              'grouped and visible to your admin.',
          style: TextStyle(fontSize: 12, color: _T.textSub, height: 1.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _showOrgEditSheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: _T.orange,
              side: BorderSide(color: _T.orange.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Set Organisation',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────
  //  ORG CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildOrgCard() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _T.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _T.border),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: _T.tealLight, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.business_outlined, color: _T.teal, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Organisation',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: _T.textSub, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          // FIX: _orgName is kept live from stream (admins doc for admins,
          //      users doc for staff)
          Text(
            (_orgName?.isNotEmpty ?? false) ? _orgName! : 'Not set',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: (_orgName?.isNotEmpty ?? false) ? _T.textPri : _T.textSub),
          ),
          if (_orgId?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'ID: $_orgId',
                style: TextStyle(fontSize: 10, color: _T.textSub.withOpacity(0.6)),
              ),
            ),
        ],
      )),
      IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18, color: _T.textSub),
        onPressed: _showOrgEditSheet,
        tooltip: 'Edit organisation',
      ),
    ]),
  );

  // ─────────────────────────────────────────────────────────
  //  PROFILE HEADER
  //  FIX: _orgName is live from admins doc for admins
  // ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    final imageBytes = _photoBase64 != null ? base64Decode(_photoBase64!) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_T.navy, _T.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2)),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: _T.teal.withOpacity(0.2),
                  backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                  child: imageBytes == null
                      ? Text(
                    widget.name.isNotEmpty
                        ? widget.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 32,
                        fontWeight: FontWeight.w800, color: _T.teal),
                  )
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _T.teal,
                    shape: BoxShape.circle,
                    border: Border.all(color: _T.navy, width: 2)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(widget.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _T.teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _T.teal.withOpacity(0.3)),
          ),
          child: Text(widget.whoYouAre,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.white, letterSpacing: 0.3)),
        ),
        // Organisation name shown live below role badge
        if (_orgName?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.business_outlined, size: 13, color: Colors.white54),
            const SizedBox(width: 5),
            Text(_orgName!,
                style: const TextStyle(fontSize: 12, color: Colors.white70,
                    letterSpacing: 0.2)),
          ]),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  INFO CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _T.tealLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _T.teal, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: _T.textSub, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600, color: _T.textPri)),
            ],
          )),
        ]),
      );
}