import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool loading = false;

  // ================= DELETE ACCOUNT =================
  Future<void> deleteAccount(String password) async {
    try {
      setState(() => loading = true);

      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;

      // ✅ Re-authenticate
      final cred =
      EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);

      // ✅ Backup user data
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      await FirebaseFirestore.instance
          .collection("archived_users")
          .doc(user.uid)
          .set({
        "profile": userDoc.data(),
        "deletedAt": DateTime.now(),
      });

      // ✅ Delete user firestore data
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .delete();

      // ✅ Delete Auth account
      await user.delete();

      // ✅ Clear saved login
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
            (route) => false,
      );
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar("Delete failed: ${e.toString()}");
    }
  }

  // ================= DELETE DIALOG =================
  void _showDeleteDialog() {
    String password = "";

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _T.red.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: _T.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const Text(
                        'Delete Account',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _T.textPri),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Warning Message ──
                const Text(
                  'This action is permanent. All your data will be archived and your account will be deleted.',
                  style: TextStyle(
                      fontSize: 13, color: _T.textSub, height: 1.5),
                ),
                const SizedBox(height: 20),

                // ── Password Field ──
                TextField(
                  obscureText: true,
                  style: const TextStyle(color: _T.textPri, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: _T.textSub, fontSize: 12),
                    hintText: 'Enter your password',
                    hintStyle:
                    TextStyle(color: _T.textSub.withOpacity(0.6), fontSize: 13),
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
                        borderSide:
                        const BorderSide(color: _T.red, width: 1.5)),
                  ),
                  onChanged: (v) => password = v,
                ),
                const SizedBox(height: 20),

                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _T.textSub,
                            side: const BorderSide(color: _T.border),
                            padding:
                            const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          deleteAccount(password);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _T.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                            const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: const Text('Delete Account',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= SNACKBAR =================
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _T.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomePage()),
                      (route) => false,
                );
              },
              tooltip: 'Logout',
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // ── Profile Header ──
                _buildProfileHeader(),

                // ── Content ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Personal Information ──
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _T.textPri,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildInfoCard(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value: widget.name,
                      ),
                      _buildInfoCard(
                        icon: Icons.cake_outlined,
                        label: 'Age',
                        value: widget.age,
                      ),
                      _buildInfoCard(
                        icon: Icons.work_outline_rounded,
                        label: 'Role',
                        value: widget.whoYouAre,
                      ),
                      _buildInfoCard(
                        icon: Icons.phone_android_rounded,
                        label: 'Mobile Number',
                        value: widget.mobile,
                      ),
                      _buildInfoCard(
                        icon: Icons.wc_rounded,
                        label: 'Gender',
                        value: widget.gender,
                      ),

                      const SizedBox(height: 32),

                      // ── Delete Account Button ──
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Help Text ──
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _T.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _T.red.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: _T.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Deletion is permanent. Your data will be archived.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _T.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Loading Overlay ──
          if (loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: _T.teal),
              ),
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // WIDGETS
  // ═════════════════════════════════════════════════════

  Widget _buildProfileHeader() {
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
      child: Column(
        children: [
          // ── Avatar ──
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: _T.teal.withOpacity(0.2),
              child: Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _T.teal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Name ──
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),

          // ── Role Badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _T.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _T.teal.withOpacity(0.3)),
            ),
            child: Text(
              widget.whoYouAre,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // ── Icon Container ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _T.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _T.teal, size: 18),
          ),
          const SizedBox(width: 14),

          // ── Text ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _T.textSub,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _T.textPri,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}