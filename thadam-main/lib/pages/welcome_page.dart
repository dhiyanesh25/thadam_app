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
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _startLoadingAnimation();
    _checkLoginAndRoute();
  }

  void _startLoadingAnimation() {
    // Smoothly fill progress bar over 4 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return false;
      setState(() {
        _loadingProgress += 1 / 100; // 100 steps over 4000ms
        if (_loadingProgress > 1.0) _loadingProgress = 1.0;
      });
      return _loadingProgress < 1.0;
    });
  }

  Future<void> _checkLoginAndRoute() async {
    // Splash delay — 4 seconds
    await Future.delayed(const Duration(seconds: 4));

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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Spacer(),

            // App Logo
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: MediaQuery.of(context).size.height * 0.35,
              ),
            ),
            const SizedBox(height: 20),

            // App Name
            const Text(
              'Thadam',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Tagline card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.8 * 255).toInt()),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: const Text(
                'Tracking every step, celebrating every win',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Progress bar loading indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      minHeight: 6,
                      backgroundColor: Colors.white30,
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_loadingProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Powered by Agate Infotek
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.15 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white30,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Powered by  ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    // Agate logo
                    Image.asset(
                      'assets/images/agate_logo.png',
                      height: 32,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Agate Infotek',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
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
}