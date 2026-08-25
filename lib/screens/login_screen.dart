import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/post_auth_navigation.dart';
import '../utils/api_error_ui.dart';
import '../widgets/game_background.dart';
import '../widgets/bluffball_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin(Future<void> Function() loginFn) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await loginFn();
      if (mounted) {
        await navigateAfterLogin(context);
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('예상치 못한 오류가 발생했습니다.\n다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showErrorDialog(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final logoSize = screenSize.width * 0.58;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 야구장 배경 이미지
          const GameBackground(),

          // 하단 그라디언트 오버레이 (버튼 가독성 확보)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenSize.height * 0.55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),

          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // 콘텐츠
          SafeArea(
            child: Column(
              children: [
                // 로고 영역 (상단 45%)
                SizedBox(
                  height: screenSize.height * 0.45,
                  child: Center(
                    child: BluffBallLogo(size: logoSize),
                  ),
                ),

                // 로그인 버튼 영역
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialLoginButton.kakao(
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin(_authService.signInWithKakao),
                        ),
                        const SizedBox(height: 12),
                        _SocialLoginButton.google(
                          onPressed: _isLoading
                              ? null
                              : () => _handleLogin(_authService.signInWithGoogle),
                        ),
                        if (Platform.isIOS) ...[
                          const SizedBox(height: 12),
                          _SocialLoginButton.apple(
                            onPressed: _isLoading
                                ? null
                                : () => _handleLogin(_authService.signInWithApple),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          '로그인 시 서비스 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주합니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'AI를 통해 생성된 이미지입니다',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 소셜 로그인 버튼 ─────────────────────────────────────────────────────────

enum _SocialType { kakao, google, apple }

class _SocialLoginButton extends StatelessWidget {
  final _SocialType type;
  final VoidCallback? onPressed;

  const _SocialLoginButton.kakao({required this.onPressed})
      : type = _SocialType.kakao;
  const _SocialLoginButton.google({required this.onPressed})
      : type = _SocialType.google;
  const _SocialLoginButton.apple({required this.onPressed})
      : type = _SocialType.apple;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      _SocialType.kakao => _buildKakao(),
      _SocialType.google => _buildGoogle(),
      _SocialType.apple => _buildApple(),
    };
  }

  Widget _buildKakao() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF191600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KakaoIcon(),
            SizedBox(width: 10),
            Text(
              '카카오로 시작하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogle() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          side: const BorderSide(color: Color(0xFFDADADA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleIcon(),
            SizedBox(width: 10),
            Text(
              'Google로 시작하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApple() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, size: 24, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Apple로 시작하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 카카오 아이콘 ─────────────────────────────────────────────────────────────

class _KakaoIcon extends StatelessWidget {
  const _KakaoIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22, 22), painter: _KakaoIconPainter());
}

class _KakaoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF191600)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final rx = size.width * 0.50;
    final ry = size.height * 0.42;

    // 말풍선 몸체
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      paint,
    );

    // 꼬리
    final tail = Path()
      ..moveTo(cx - size.width * 0.10, cy + ry * 0.70)
      ..lineTo(cx - size.width * 0.25, cy + ry * 1.35)
      ..lineTo(cx + size.width * 0.06, cy + ry * 0.82)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 구글 아이콘 ──────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22, 22), painter: _GoogleIconPainter());
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    const segments = [
      (Color(0xFF4285F4), -0.10, 0.50),
      (Color(0xFFEA4335), 0.50, 1.10),
      (Color(0xFFFBBC05), 1.10, 1.65),
      (Color(0xFF34A853), 1.65, 6.08),
    ];

    for (final (color, start, end) in segments) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: r),
          start, end - start, false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // 도넛 구멍
    canvas.drawCircle(center, r * 0.60, Paint()..color = Colors.white);

    // G 가로 막대
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - r * 0.14, r, r * 0.28),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
