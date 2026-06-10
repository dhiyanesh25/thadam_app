import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/parent_dashboard_page.dart';
import 'pages/admin_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ThadamApp());
}

class ThadamApp extends StatelessWidget {
  const ThadamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SPLASH GATE
//  • Remember Me ON  + live Firebase session → skip to Dashboard
//  • Everything else                         → WelcomePage
// ─────────────────────────────────────────────────────────────
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 600));

    final prefs      = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Both must be true to auto-login
    if (rememberMe && firebaseUser != null) {
      final userType = prefs.getString('userType') ?? '';
      final name     = prefs.getString('name')     ?? '';
      final age      = prefs.getString('age')      ?? '';
      final gender   = prefs.getString('gender')   ?? '';
      final mobile   = prefs.getString('saved_mobile') ?? '';

      if (userType.isNotEmpty) {
        _goHome(userType: userType, name: name,
            age: age, gender: gender, mobile: mobile);
        return;
      }
    }

    // Stale data — clean up
    if (!rememberMe) await prefs.clear();
    _go(const WelcomePage());
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  void _goHome({
    required String userType,
    required String name,
    required String age,
    required String gender,
    required String mobile,
  }) {
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
    _go(page);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF0A9396),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Thadam',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}