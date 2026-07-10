import 'package:flutter/material.dart';
import '../widgets/game_background.dart';
import '../widgets/bluffball_logo.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 0.68;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 야구장 배경 이미지
          const GameBackground(),

          // 전체 살짝 어둡게 (로고 가독성)
          Container(color: Colors.black.withValues(alpha: 0.18)),

          // 로고 (화면 중앙 살짝 위)
          Align(
            alignment: const Alignment(0, -0.30),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: BluffBallLogo(size: logoSize),
            ),
          ),

          // AI 생성 이미지 문구
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'AI를 통해 생성된 이미지입니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
