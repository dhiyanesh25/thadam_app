import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'pages/welcome_page.dart';

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
      home: WelcomePage(), // 🔥 always start with welcome (splash + router)
    );
  }
}
