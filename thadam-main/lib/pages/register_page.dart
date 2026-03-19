import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'dashboard_page.dart';
import 'parent_dashboard_page.dart';
import 'admin_dashboard_page.dart';

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
  static const error     = Color(0xFFE63946);

  static InputDecoration inputDec(String label,
      {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: textSub)
            : null,
        labelStyle: const TextStyle(color: textSub, fontSize: 13),
        hintStyle: TextStyle(color: textSub.withOpacity(0.6), fontSize: 13),
        filled: true,
        fillColor: surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: teal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: error)),
        errorStyle: const TextStyle(color: error, fontSize: 11),
      );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController            = TextEditingController();
  final _ageController             = TextEditingController();
  final _mobileController          = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  String? _selectedUserType;

  bool _obscure        = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Header Background ──
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_T.navy, _T.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
            ),

            // ── Content ──
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ── Icon & Title ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Form Container ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _T.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _T.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Full Name ──
                            const _SectionLabel('FULL NAME'),
                            TextFormField(
                              controller: _nameController,
                              decoration: _T.inputDec(
                                'Full Name',
                                hint: 'Enter your name',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter your name'
                                  : null,
                            ),

                            const SizedBox(height: 14),

                            // ── Age ──
                            const _SectionLabel('AGE'),
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: _T.inputDec(
                                'Age',
                                hint: 'Enter your age',
                                icon: Icons.cake_outlined,
                              ),
                              validator: (value) =>
                              value == null || value.isEmpty
                                  ? 'Enter your age'
                                  : null,
                            ),

                            const SizedBox(height: 14),

                            // ── Mobile ──
                            const _SectionLabel('MOBILE NUMBER'),
                            TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: _T.inputDec(
                                'Mobile Number',
                                hint: '10 digit mobile',
                                icon: Icons.phone_android_rounded,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter mobile number';
                                }
                                if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                                  return 'Must be 10 digits';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ── Email ──
                            const _SectionLabel('EMAIL ADDRESS'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _T.inputDec(
                                'Email',
                                hint: 'example@gmail.com',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter email';
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                    .hasMatch(value)) {
                                  return 'Enter valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ── Gender ──
                            const _SectionLabel('GENDER'),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              hint: const Text('Select Gender'),
                              items: ['Male', 'Female', 'Other']
                                  .map((item) => DropdownMenuItem(
                                  value: item, child: Text(item)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedGender = val),
                              validator: (value) =>
                              value == null ? 'Select gender' : null,
                              decoration: _T.inputDec('Gender'),
                            ),

                            const SizedBox(height: 14),

                            // ── Role ──
                            const _SectionLabel('ROLE'),
                            DropdownButtonFormField<String>(
                              value: _selectedUserType,
                              hint: const Text('Who are you?'),
                              items: [
                                'Teacher',
                                'Special Educator',
                                'Therapist',
                                'Parent',
                                'Admin'
                              ]
                                  .map((item) => DropdownMenuItem(
                                  value: item, child: Text(item)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedUserType = val),
                              validator: (value) =>
                              value == null ? 'Select role' : null,
                              decoration: _T.inputDec('Role'),
                            ),

                            const SizedBox(height: 14),

                            // ── Password ──
                            const _SectionLabel('PASSWORD'),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              decoration: _T.inputDec(
                                'Password',
                                hint: 'Min 8 chars, 1 capital, 1 number',
                                icon: Icons.lock_outline_rounded,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: _T.textSub,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter password';
                                }
                                if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).{8,}$')
                                    .hasMatch(value)) {
                                  return 'Min 8 chars, 1 capital, 1 number';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ── Confirm Password ──
                            const _SectionLabel('CONFIRM PASSWORD'),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              decoration: _T.inputDec(
                                'Confirm Password',
                                hint: 'Re-enter password',
                                icon: Icons.lock_rounded,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: _T.textSub,
                                  ),
                                  onPressed: () => setState(() =>
                                  _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // ── Create Button ──
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                _isLoading ? null : _registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.teal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  disabledBackgroundColor:
                                  _T.teal.withOpacity(0.5),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Login Link ──
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Already have an account? ',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _T.textSub,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: 'Login',
                                        style: TextStyle(
                                          color: _T.teal,
                                          fontWeight: FontWeight.w700,
                                        ),
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

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null || _selectedUserType == null) {
        _showSnackBar('Please select both gender and role.');
        return;
      }

      setState(() => _isLoading = true);

      final name     = _nameController.text.trim();
      final age      = _ageController.text.trim();
      final mobile   = _mobileController.text.trim();
      final email    = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final isParent = _selectedUserType == 'Parent';
      final role     = _selectedUserType!;

      try {
        // ✅ Check if mobile already exists
        final existingUser = await _firestore
            .collection('users')
            .where('mobile', isEqualTo: mobile)
            .get();

        if (existingUser.docs.isNotEmpty) {
          _showSnackBar('This mobile number is already registered.');
          setState(() => _isLoading = false);
          return;
        }

        // ✅ Check if email already exists
        final existingEmail = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        if (existingEmail.docs.isNotEmpty) {
          _showSnackBar('This email is already registered.');
          setState(() => _isLoading = false);
          return;
        }

        if (isParent) {
          final studentSnapshot = await _firestore
              .collection('students')
              .where('parentPhone', isEqualTo: mobile)
              .get();

          if (studentSnapshot.docs.isEmpty) {
            _showSnackBar('Your child entry is not updated yet!');
            setState(() => _isLoading = false);
            return;
          }
        }

        // ✅ KEY FIX: use real email for Firebase Auth (not fake mobile@gmail.com)
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: email,      // ← was '$mobile@gmail.com' before
          password: password,
        );

        final uid = userCredential.user!.uid;

        await _firestore.collection('users').doc(uid).set({
          'uid'      : uid,
          'name'     : name,
          'age'      : age,
          'gender'   : _selectedGender,
          'userType' : role,
          'mobile'   : mobile,
          'email'    : email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        if (isParent) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentDashboardPage(
                name: name, age: age,
                mobile: mobile, gender: _selectedGender!,
                whoYouAre: _selectedUserType!,
              ),
            ),
          );
        } else if (role == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardPage(
                name: name, age: age,
                mobile: mobile, gender: _selectedGender!,
                whoYouAre: _selectedUserType!,
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String msg = e.message ?? 'Authentication error';
        if (e.code == 'email-already-in-use') {
          msg = 'This email is already registered.';
        }
        _showSnackBar(msg);
        setState(() => _isLoading = false);
      } catch (e) {
        _showSnackBar('Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _T.navy,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _T.textSub)),
  );
}