import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const LunchPickApp());
}

class LunchPickApp extends StatelessWidget {
  const LunchPickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '점심 픽',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B35)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
