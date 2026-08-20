import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/post_auth_navigation.dart';
import '../services/token_storage.dart';
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
  bool _checkingSession = false;

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
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final splash = Future<void>.delayed(const Duration(milliseconds: 2800));
    var sessionResolved = false;
    final sessionFuture = _resolveSession().whenComplete(() {
      sessionResolved = true;
    });

    await splash;
    if (!mounted) return;

    // 스플래시 후에도 서버 확인이 남았으면 안내 표시
    if (!sessionResolved) {
      setState(() => _checkingSession = true);
    }

    final hasValidSession = await sessionFuture;
    if (!mounted) return;

    if (hasValidSession) {
      await navigateAfterAuth(context);
    } else {
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
  }

  /// 로컬 토큰이 있으면 서버에 세션 유효성을 확인한다.
  Future<bool> _resolveSession() async {
    final hasTokens = await TokenStorage().hasTokens();
    if (!hasTokens) return false;
    return AuthService().restoreSession();
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

          if (_checkingSession)
            const Align(
              alignment: Alignment(0, 0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '로그인 확인 중...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
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
