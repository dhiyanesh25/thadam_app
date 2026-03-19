import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_page.dart';
import 'dashboard_page.dart';
import 'parent_dashboard_page.dart';
import 'admin_dashboard_page.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (unchanged from your original)
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
  static const error     = Color(0xFFE63946);
}

// ─────────────────────────────────────────────────────────────
//  LOGIN PAGE
// ─────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  // ── Call this on every logout ──────────────────────────────
  // ProfilePage / AdminProfilePage should call this before
  // FirebaseAuth.instance.signOut()
  static Future<void> clearOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();          // wipe everything
    } catch (_) {}
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey             = GlobalKey<FormState>();
  final _mobileController    = TextEditingController();
  final _passwordController  = TextEditingController();

  bool _obscure    = true;
  bool _isLoading  = false;
  bool _rememberMe = false;

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── init ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // ✅ FIX: do NOT pre-fill fields — just restore the checkbox
    // Auto-login happens in SplashGate (main.dart) BEFORE this
    // page is ever shown. If we reached LoginPage, the user is
    // not remembered, so fields stay blank.
    _restoreCheckboxState();
  }

  Future<void> _restoreCheckboxState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only restore the tick, never the text fields
      if (mounted) {
        setState(() {
          _rememberMe = prefs.getBool('remember_me') ?? false;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Save session after successful login ─────────────────────
  Future<void> _saveSession({
    required String mobile,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      // ✅ Save everything needed for SplashGate to auto-login
      await prefs.setBool  ('remember_me',  true);
      await prefs.setString('saved_mobile', mobile);
      // ⚠️  We do NOT save the plain-text password — we save a
      //     flag so SplashGate can re-use the live Firebase Auth
      //     session (which persists automatically via Firebase SDK)
      await prefs.setString('userType',     userData['userType'] ?? '');
      await prefs.setString('name',         userData['name']     ?? '');
      await prefs.setString('age',          userData['age']?.toString() ?? '');
      await prefs.setString('gender',       userData['gender']   ?? '');
      await prefs.setString('uid',
          userData['uid'] ?? _auth.currentUser?.uid ?? '');
    } else {
      // Clear any old remember-me data
      await prefs.clear();
    }
  }

  // ── Login ────────────────────────────────────────────────────
  Future<void> _loginUser() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final mobile   = _mobileController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1. Find user by mobile
      final query = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnackBar('No account found for this mobile number');
        setState(() => _isLoading = false);
        return;
      }

      final userData  = query.docs.first.data();
      final realEmail = (userData['email'] as String?) ?? '';

      if (realEmail.isEmpty) {
        _showSnackBar('Account email not found. Please contact support.');
        setState(() => _isLoading = false);
        return;
      }

      // 2. Firebase Auth sign-in
      await _auth.signInWithEmailAndPassword(
          email: realEmail, password: password);

      // 3. Save / clear session
      await _saveSession(
          mobile: mobile, password: password, userData: userData);

      if (!mounted) return;

      // 4. Navigate by role
      _navigateByRole(userData, mobile);

    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      switch (e.code) {
        case 'user-not-found':    msg = 'No account found. Please register.'; break;
        case 'wrong-password':
        case 'invalid-credential':msg = 'Incorrect password. Try again.'; break;
        case 'invalid-email':     msg = 'Invalid email format.'; break;
        case 'too-many-requests': msg = 'Too many attempts. Try again later.'; break;
        default:                  msg = 'Login failed. Check your credentials.';
      }
      _showSnackBar(msg);
      setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(Map<String, dynamic> userData, String mobile) {
    final name     = userData['name']     ?? 'User';
    final age      = userData['age']?.toString() ?? '';
    final gender   = userData['gender']   ?? '';
    final userType = userData['userType'] ?? 'Teacher';

    Widget page;
    if (userType == 'Admin') {
      page = const AdminDashboardPage();
    } else if (userType == 'Parent') {
      page = ParentDashboardPage(
          name: name, age: age,
          mobile: mobile, gender: gender,
          whoYouAre: userType);
    } else {
      page = DashboardPage(
          name: name, age: age,
          mobile: mobile, gender: gender,
          whoYouAre: userType);
    }

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  // ── Forgot password ──────────────────────────────────────────
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final resetFormKey         = GlobalKey<FormState>();
    bool  isSending            = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: _T.border,
                        borderRadius: BorderRadius.circular(2)),
                  )),
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
                  const Text('Registered Email',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _T.textPri,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                        fontSize: 15, color: _T.textPri,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'example@gmail.com',
                      hintStyle: const TextStyle(
                          fontSize: 14, color: _T.textSub),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: _T.teal, size: 20),
                      filled: true, fillColor: _T.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: _T.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: _T.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _T.teal, width: 2)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: _T.error)),
                    ),
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                        if (!resetFormKey.currentState!.validate()) return;
                        setModalState(() => isSending = true);
                        final email =
                        resetEmailController.text.trim();
                        try {
                          final q = await _firestore
                              .collection('users')
                              .where('email', isEqualTo: email)
                              .limit(1)
                              .get();
                          if (q.docs.isEmpty) {
                            setModalState(
                                    () => isSending = false);
                            _showSnackBar(
                                'No account found for this email');
                            return;
                          }
                          await _auth.sendPasswordResetEmail(
                              email: email);
                          if (mounted) Navigator.pop(ctx);
                          final parts = email.split('@');
                          final vis = parts[0].substring(
                              0,
                              (parts[0].length / 2)
                                  .ceil()
                                  .clamp(1, parts[0].length));
                          _showSnackBar(
                              '✅ Reset link sent to $vis***@${parts[1]}');
                        } on FirebaseAuthException catch (e) {
                          setModalState(
                                  () => isSending = false);
                          _showSnackBar(
                              e.code == 'user-not-found'
                                  ? 'No account found for this email'
                                  : 'Failed to send reset email');
                        } catch (e) {
                          setModalState(
                                  () => isSending = false);
                          _showSnackBar('Error: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor:
                        _T.teal.withOpacity(0.5),
                      ),
                      child: isSending
                          ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                          : const Text('Send Reset Link',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Snackbar ─────────────────────────────────────────────────
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(color: Colors.white)),
      backgroundColor: _T.navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

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

            // ── Header banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 48, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_T.navy, _T.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _T.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 56, color: _T.teal),
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

            // ── Form ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Mobile
                    const Text('Mobile Number',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _T.textPri,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      // ✅ Prevent OS autofill from showing saved credentials
                      autofillHints: const [],
                      style: const TextStyle(
                          fontSize: 15,
                          color: _T.textPri,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: '10 digit mobile number',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: _T.textSub),
                        prefixIcon: const Icon(
                            Icons.phone_android_rounded,
                            color: _T.teal, size: 20),
                        filled: true, fillColor: _T.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.border, width: 1)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.border, width: 1)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.teal, width: 2)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.error, width: 1)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter mobile number';
                        }
                        if (!RegExp(r'^\d{10}$').hasMatch(v)) {
                          return 'Must be 10 digits';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Password',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _T.textPri,
                                letterSpacing: 0.5)),
                        GestureDetector(
                          onTap: _showForgotPasswordDialog,
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
                      controller: _passwordController,
                      obscureText: _obscure,
                      // ✅ Prevent OS from showing saved password
                      autofillHints: const [],
                      enableSuggestions: false,
                      autocorrect: false,
                      style: const TextStyle(
                          fontSize: 15,
                          color: _T.textPri,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: _T.textSub),
                        prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: _T.teal, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: _T.textSub, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        filled: true, fillColor: _T.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.border, width: 1)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.border, width: 1)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.teal, width: 2)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _T.error, width: 1)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter password';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Remember Me ──────────────────────────────
                    Row(children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        activeColor: _T.teal,
                        side: const BorderSide(
                            color: _T.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 4),
                      const Text('Remember me',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _T.textPri)),
                      const Spacer(),
                      Text(
                        _rememberMe
                            ? 'Stay signed in ✓'
                            : 'Credentials saved until logout',
                        style: TextStyle(
                            fontSize: 11,
                            color: _rememberMe
                                ? _T.teal
                                : _T.textSub.withOpacity(0.6),
                            fontWeight: FontWeight.w500),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Sign In button ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _T.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor:
                          _T.teal.withOpacity(0.5),
                        ),
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

                    const SizedBox(height: 20),

                    // ── Divider ──
                    Row(children: [
                      const Expanded(child: Divider(
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
                      const Expanded(child: Divider(
                          color: _T.border, height: 1, thickness: 1)),
                    ]),

                    const SizedBox(height: 20),

                    // ── Register link ──
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage()),
                        ),
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
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