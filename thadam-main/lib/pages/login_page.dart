import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_page.dart';
import 'dashboard_page.dart';
import 'parent_dashboard_page.dart';
import 'admin_dashboard_page.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────────────────────
class _T {
  static const navy      = Color(0xFF0D1B2A);
  static const navyLight = Color(0xFF1B2E42);
  static const teal      = Color(0xFF0A9396);
  static const surface   = Color(0xFFF8FAFB);
  static const border    = Color(0xFFE4EAF0);
  static const textPri   = Color(0xFF0D1B2A);
  static const textSub   = Color(0xFF6B7A8D);
  static const error     = Color(0xFFE63946);
}

// ─────────────────────────────────────────────────────────────
//  LOGIN PAGE
// ─────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  /// Call from ProfilePage / AdminProfilePage BEFORE FirebaseAuth.signOut()
  static Future<void> clearOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey            = GlobalKey<FormState>();
  final _mobileCtrl         = TextEditingController();
  final _passwordCtrl       = TextEditingController();

  bool _obscure    = true;
  bool _isLoading  = false;
  bool _rememberMe = false;

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadCheckbox();
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCheckbox() async {
    final prefs = await SharedPreferences.getInstance();
    // Restore checkbox only — NEVER pre-fill text fields
    if (mounted) {
      setState(() => _rememberMe = prefs.getBool('remember_me') ?? false);
    }
  }

  // ── Persist / clear session ──────────────────────────────────
  Future<void> _saveSession(
      String mobile, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool  ('remember_me',   true);
      await prefs.setString('saved_mobile',  mobile);
      await prefs.setString('userType',      userData['userType'] ?? '');
      await prefs.setString('name',          userData['name']     ?? '');
      await prefs.setString('age',           userData['age']?.toString() ?? '');
      await prefs.setString('gender',        userData['gender']   ?? '');
      await prefs.setString('uid',
          userData['uid'] ?? _auth.currentUser?.uid ?? '');
    } else {
      // Wipe everything — SplashGate will always show WelcomePage next launch
      await prefs.clear();
    }
  }

  // ── Login ────────────────────────────────────────────────────
  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final mobile   = _mobileCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      // 1. Resolve email from mobile number
      final query = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _snack('No account found for this mobile number.');
        setState(() => _isLoading = false);
        return;
      }

      final userData = query.docs.first.data();
      final email    = (userData['email'] as String?) ?? '';

      if (email.isEmpty) {
        _snack('Account email missing. Please contact support.');
        setState(() => _isLoading = false);
        return;
      }

      // 2. Firebase sign-in
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // 3. Save or clear session based on Remember Me
      await _saveSession(mobile, userData);

      if (!mounted) return;

      // 4. Route by role
      _navigateByRole(userData, mobile);

    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found'     => 'No account found. Please register.',
        'wrong-password'     => 'Incorrect password. Try again.',
        'invalid-credential' => 'Incorrect password. Try again.',
        'invalid-email'      => 'Invalid email format.',
        'too-many-requests'  => 'Too many attempts. Try again later.',
        _                    => 'Login failed. Please check your credentials.',
      };
      _snack(msg);
      setState(() => _isLoading = false);
    } catch (_) {
      _snack('Unexpected error. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(Map<String, dynamic> data, String mobile) {
    final name     = data['name']     ?? 'User';
    final age      = data['age']?.toString() ?? '';
    final gender   = data['gender']   ?? '';
    final userType = data['userType'] ?? 'Teacher';

    Widget page;
    if (userType == 'Admin') {
      page = const AdminDashboardPage();
    } else if (userType == 'Parent') {
      page = ParentDashboardPage(
          name: name, age: age,
          mobile: mobile, gender: gender, whoYouAre: userType);
    } else {
      page = DashboardPage(
          name: name, age: age,
          mobile: mobile, gender: gender, whoYouAre: userType);
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  // ── Forgot Password sheet ────────────────────────────────────
  void _showForgotPassword() {
    final emailCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          bool sending = false;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: _T.border,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: _T.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.lock_reset_rounded,
                            color: _T.teal, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reset Password',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: _T.textPri)),
                          SizedBox(height: 2),
                          Text('Enter your registered email address',
                              style: TextStyle(
                                  fontSize: 12, color: _T.textSub)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _fieldLabel('Registered Email'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: _fieldTextStyle(),
                      decoration: _buildDecoration(
                          hint: 'example@gmail.com',
                          icon: Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your registered email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    StatefulBuilder(
                      builder: (_, setSend) => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: sending
                              ? null
                              : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSend(() => sending = true);
                            final email = emailCtrl.text.trim();
                            try {
                              final q = await _firestore
                                  .collection('users')
                                  .where('email', isEqualTo: email)
                                  .limit(1)
                                  .get();
                              if (q.docs.isEmpty) {
                                setSend(() => sending = false);
                                _snack('No account found for this email.');
                                return;
                              }
                              await _auth.sendPasswordResetEmail(
                                  email: email);
                              if (ctx.mounted) Navigator.pop(ctx);
                              // Mask email in confirmation
                              final parts = email.split('@');
                              final vis   = parts[0].substring(
                                  0,
                                  (parts[0].length / 2)
                                      .ceil()
                                      .clamp(1, parts[0].length));
                              _snack(
                                  '✅ Reset link sent to $vis***@${parts[1]}');
                            } on FirebaseAuthException {
                              setSend(() => sending = false);
                              _snack('Failed to send reset email. Try again.');
                            } catch (_) {
                              setSend(() => sending = false);
                              _snack('Unexpected error. Try again.');
                            }
                          },
                          style: _elevatedBtnStyle(),
                          child: sending
                              ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                              : const Text('Send Reset Link',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Snackbar ─────────────────────────────────────────────────
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white)),
      backgroundColor: _T.navy,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Widget helpers ───────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _T.textPri,
          letterSpacing: 0.5));

  TextStyle _fieldTextStyle() => const TextStyle(
      fontSize: 15, color: _T.textPri, fontWeight: FontWeight.w500);

  InputDecoration _buildDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: _T.textSub),
        prefixIcon: Icon(icon, color: _T.teal, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _T.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _T.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _T.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _T.teal, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _T.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _T.error, width: 2)),
      );

  ButtonStyle _elevatedBtnStyle() => ElevatedButton.styleFrom(
    backgroundColor: _T.teal,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
    disabledBackgroundColor: _T.teal.withOpacity(0.5),
  );

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [

            // ── Header ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 52, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_T.navy, _T.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _T.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 52, color: _T.teal),
                ),
                const SizedBox(height: 20),
                const Text('Welcome Back',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Sign in to your account to continue',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70),
                    textAlign: TextAlign.center),
              ]),
            ),

            // ── Form ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Mobile Number ─────────────────────────
                    _fieldLabel('Mobile Number'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: _fieldTextStyle(),
                      decoration: _buildDecoration(
                          hint: '10-digit mobile number',
                          icon: Icons.phone_android_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your mobile number';
                        }
                        if (v.length != 10) {
                          return 'Must be exactly 10 digits';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Password ──────────────────────────────
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        _fieldLabel('Password'),
                        GestureDetector(
                          onTap: _showForgotPassword,
                          child: const Text('Forgot Password?',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _T.teal)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      autofillHints: const [],
                      enableSuggestions: false,
                      autocorrect: false,
                      style: _fieldTextStyle(),
                      decoration: _buildDecoration(
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: _T.textSub, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Remember Me ───────────────────────────
                    Row(children: [
                      SizedBox(
                        width: 24, height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          activeColor: _T.teal,
                          side: const BorderSide(
                              color: _T.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _rememberMe = !_rememberMe),
                        child: const Text('Remember me',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _T.textPri)),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _rememberMe
                              ? 'Stay signed in ✓'
                              : 'Sign in each time',
                          key: ValueKey(_rememberMe),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _rememberMe
                                  ? _T.teal
                                  : _T.textSub.withOpacity(0.6)),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Sign In Button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: _elevatedBtnStyle(),
                        child: _isLoading
                            ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                            : const Text('Sign In',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Divider ───────────────────────────────
                    Row(children: [
                      const Expanded(
                          child: Divider(
                              color: _T.border, height: 1, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _T.textSub.withOpacity(0.7))),
                      ),
                      const Expanded(
                          child: Divider(
                              color: _T.border, height: 1, thickness: 1)),
                    ]),

                    const SizedBox(height: 24),

                    // ── Register Link ─────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage()),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account?  ",
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _T.textSub),
                            children: [
                              TextSpan(
                                text: 'Create Account',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _T.teal),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

          ]),
        ),
      ),
    );
  }
}