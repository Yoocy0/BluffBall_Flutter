import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const BluffBallApp());
}

class BluffBallApp extends StatelessWidget {
  const BluffBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BluffBall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF556B2F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}
