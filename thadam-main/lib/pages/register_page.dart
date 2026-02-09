import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'dashboard_page.dart';
import 'parent_dashboard_page.dart';
import 'admin_dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  String? _selectedUserType;

  bool _obscure = true;
  bool _obscureConfirm = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.28,
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
                    const SizedBox(height: 30),

                    const Icon(Icons.person_add_alt_1,
                        size: 55, color: Colors.white),
                    const SizedBox(height: 8),
                    const Text(
                      "Create Account",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 25),

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
                            _label("Full Name"),
                            _textField(_nameController, "Enter name",
                                icon: Icons.person_outline),

                            const SizedBox(height: 14),

                            _label("Age"),
                            _textField(_ageController, "Enter age",
                                keyboardType: TextInputType.number,
                                icon: Icons.cake_outlined),

                            const SizedBox(height: 14),

                            _label("Mobile Number"),
                            _textField(
                              _mobileController,
                              "10 digit mobile",
                              keyboardType: TextInputType.phone,
                              icon: Icons.phone_android,
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

                            _label("Email"),
                            _textField(
                              _emailController,
                              "example@gmail.com",
                              keyboardType: TextInputType.emailAddress,
                              icon: Icons.email_outlined,
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

                            _label("Gender"),
                            _dropdownField(
                              hint: "Select Gender",
                              value: _selectedGender,
                              items: const ['Male', 'Female', 'Other'],
                              onChanged: (val) =>
                                  setState(() => _selectedGender = val),
                            ),

                            const SizedBox(height: 14),

                            _label("Role"),
                            _dropdownField(
                              hint: "Who are you?",
                              value: _selectedUserType,
                              items: const [
                                'Teacher',
                                'Special Educator',
                                'Therapist',
                                'Parent',
                                'Admin'
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedUserType = val),
                            ),

                            const SizedBox(height: 14),

                            _label("Password"),
                            _textField(
                              _passwordController,
                              "Create password",
                              obscureText: _obscure,
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
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

                            _label("Confirm Password"),
                            _textField(
                              _confirmPasswordController,
                              "Re-enter password",
                              obscureText: _obscureConfirm,
                              icon: Icons.lock,
                              suffix: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFF3A78C2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  "Create Account",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                ),
                                child: const Text(
                                  "Already have an account? Login",
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _textField(
      TextEditingController controller,
      String hint, {
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
        Widget? suffix,
        IconData? icon,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator:
      validator ?? (value) => value == null || value.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF3F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF3F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null || _selectedUserType == null) {
        _showSnackBar("Please select both gender and role.");
        return;
      }

      final name = _nameController.text.trim();
      final age = _ageController.text.trim();
      final mobile = _mobileController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final isParent = _selectedUserType == 'Parent';

      // 👉 BACK TO ORIGINAL FORMAT (READABLE ROLE)
      String role = _selectedUserType!;

      try {
        // ✅ CHECK IF MOBILE ALREADY EXISTS (NEW FIX YOU ASKED)
        final existingUser = await _firestore
            .collection('users')
            .where('mobile', isEqualTo: mobile)
            .get();

        if (existingUser.docs.isNotEmpty) {
          _showSnackBar("This mobile number is already registered.");
          return;
        }

        if (isParent) {
          final studentSnapshot = await _firestore
              .collection('students')
              .where('parentPhone', isEqualTo: mobile)
              .get();

          if (studentSnapshot.docs.isEmpty) {
            _showSnackBar("Your child entry is not updated yet!");
            return;
          }
        }

        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: "$mobile@gmail.com",
          password: password,
        );

        String uid = userCredential.user!.uid;

        final userData = {
          'uid': uid,
          'name': name,
          'age': age,
          'gender': _selectedGender,
          'userType': role, // 👈 STORES "Teacher", "Parent", etc.
          'mobile': mobile,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(uid).set(userData);

        if (isParent) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentDashboardPage(
                name: name,
                age: age,
                mobile: mobile,
                gender: _selectedGender!,
                whoYouAre: _selectedUserType!,
              ),
            ),
          );
        } else if (role == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminDashboardPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardPage(
                name: name,
                age: age,
                mobile: mobile,
                gender: _selectedGender!,
                whoYouAre: _selectedUserType!,
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        _showSnackBar(e.message ?? "Authentication error");
      } catch (e) {
        _showSnackBar("Error: $e");
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
