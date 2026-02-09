import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'dashboard_page.dart';
import 'parent_dashboard_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {

  @override
  void initState() {
    super.initState();
    _checkLoginAndRoute();
  }

  Future<void> _checkLoginAndRoute() async {
    // Splash delay
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // ❌ If remember me not selected, force login
    if (!rememberMe) {
      if (user != null) {
        await FirebaseAuth.instance.signOut();
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    // ❌ rememberMe = true but no Firebase user
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    // ✅ rememberMe = true and user exists → fetch Firestore data
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    if (!doc.exists) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    final data = doc.data()!;
    final name = data['name'];
    final age = data['age'];
    final gender = data['gender'];
    final userType = data['userType'];
    final mobile = data['mobile'];

    if (userType == "Parent") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentDashboardPage(
            name: name,
            age: age,
            mobile: mobile,
            gender: gender,
            whoYouAre: userType,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A9BD8),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: MediaQuery.of(context).size.height * 0.35,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thadam',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.8 * 255).toInt()),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 4))
                ],
              ),
              child: const Text(
                'Tracking every step, celebrating every win',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 40),

            // Loading indicator instead of Get Started
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
