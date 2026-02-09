import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_page.dart';
import 'dashboard_page.dart';
import 'parent_dashboard_page.dart';
import 'admin_dashboard_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool rememberMe = false;
  bool _obscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _checkingSession = true;
  bool _autoChecked = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkSessionAndNavigate();
  }

  // ============ LOAD SAVED CREDENTIALS (NOW INCLUDES ROLE) ============
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMobile = prefs.getString('savedMobile') ?? '';
    final savedPassword = prefs.getString('savedPassword') ?? '';
    final savedRemember = prefs.getBool('rememberMe') ?? false;
    final savedUserType = prefs.getString('savedUserType'); // NEW

    if (savedMobile.isNotEmpty &&
        savedPassword.isNotEmpty &&
        savedRemember &&
        savedUserType != null) {

      setState(() {
        _mobileController.text = savedMobile;
        _passwordController.text = savedPassword;
        rememberMe = true;
      });

      // 🔹 INSTANT REDIRECT BASED ON SAVED ROLE (NO FIREBASE WAIT)
      if (!mounted) return;

      if (savedUserType == "Admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
        return;
      }
    }
  }

  // ============ SAVE CREDENTIALS (NOW SAVES ROLE TOO) ============
  Future<void> _saveCredentials(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);

    if (rememberMe) {
      await prefs.setString('savedMobile', _mobileController.text.trim());
      await prefs.setString('savedPassword', _passwordController.text.trim());
      await prefs.setString('savedUserType', userType); // NEW
    } else {
      await prefs.remove('savedMobile');
      await prefs.remove('savedPassword');
      await prefs.remove('savedUserType'); // NEW
    }
  }

  // ============ BACKUP CHECK USING FIREBASE ============
  Future<void> _checkSessionAndNavigate() async {
    if (_autoChecked) return;
    _autoChecked = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _checkingSession = false);
      return;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      setState(() => _checkingSession = false);
      return;
    }

    final data = doc.data()!;
    final userType = data['userType'];

    if (!mounted) return;

    if (userType == "Admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } else if (userType == "Parent") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentDashboardPage(
            name: data['name'],
            age: data['age'],
            mobile: data['mobile'],
            gender: data['gender'],
            whoYouAre: "Parent",
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            name: data['name'],
            age: data['age'],
            mobile: data['mobile'],
            gender: data['gender'],
            whoYouAre: userType,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_checkingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5A9BD8), Color(0xFF3A78C2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(40),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.health_and_safety,
                        size: 60, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text(
                      "Thadam",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Tracking every step, celebrating every win",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Login",
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),

                            _inputLabel("Mobile Number"),
                            TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration:
                              _fieldDecoration(icon: Icons.phone_android),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your mobile number';
                                }
                                if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                                  return 'Mobile number must be 10 digits';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            _inputLabel("Password"),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              decoration: _fieldDecoration(
                                icon: Icons.lock_outline,
                                suffix: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () {
                                    setState(() => _obscure = !_obscure);
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Checkbox(
                                  value: rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      rememberMe = value ?? false;
                                    });
                                  },
                                ),
                                const Text("Remember me"),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: const Text("Forgot?"),
                                )
                              ],
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loginUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF3A78C2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(14)),
                                ),
                                child: const Text(
                                  "Log In",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const RegisterPage()),
                                ),
                                child: const Text(
                                  "New user? Register here",
                                  style: TextStyle(
                                      color: Color(0xFF3A78C2),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ LOGIN LOGIC (UPDATED TO SAVE ROLE) ============
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    final mobile = _mobileController.text.trim();
    final email = "$mobile@gmail.com";
    final password = _passwordController.text.trim();

    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('Authentication failed. Try again.');
        return;
      }

      final doc =
      await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        _showSnackBar('User profile not found.');
        return;
      }

      final data = doc.data()!;
      final name = data['name'];
      final age = data['age'];
      final gender = data['gender'];
      final userType = data['userType'];

      await _saveCredentials(userType); // 🔹 SAVING ROLE NOW

      if (userType == "Admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else if (userType == "Parent") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ParentDashboardPage(
              name: name,
              age: age,
              mobile: mobile,
              gender: gender,
              whoYouAre: "Parent",
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              name: name,
              age: age,
              mobile: mobile,
              gender: gender,
              whoYouAre: userType,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Login failed.');
    } catch (e) {
      _showSnackBar('Something went wrong. Try again.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _fieldDecoration(
      {required IconData icon, Widget? suffix}) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF3F6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
