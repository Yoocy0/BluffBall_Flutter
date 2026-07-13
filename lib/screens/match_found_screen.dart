import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'setup_screen.dart';
import '../models/game_mode.dart';

class MatchFoundScreen extends StatefulWidget {
  final String? matchSessionId;
  final GameMode gameMode;

  const MatchFoundScreen({
    super.key,
    this.matchSessionId,
    this.gameMode = GameMode.single,
  });

  @override
  State<MatchFoundScreen> createState() => _MatchFoundScreenState();
}

class _MatchFoundScreenState extends State<MatchFoundScreen>
    with TickerProviderStateMixin {
  // 3초 확인 타이머
  static const _verifyDuration = Duration(seconds: 3);

  double _progress = 0.0;
  Timer? _progressTimer;

  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;

  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  late final AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();

    // 체크 아이콘 등장
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _checkOpacity = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));

    // 글로우 펄스
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.6, end: 1.0));

    // 텍스트 슬라이드-인
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textSlide = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: const Offset(0, 0.3), end: Offset.zero));

    // 확인 링 회전
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // 순차 실행
    _checkCtrl.forward().whenComplete(() {
      _textCtrl.forward();
      _startProgressTimer();
    });
  }

  void _startProgressTimer() {
    const tickMs = 50;
    final totalTicks = _verifyDuration.inMilliseconds / tickMs;
    int tick = 0;

    _progressTimer = Timer.periodic(
      const Duration(milliseconds: tickMs),
      (_) {
        tick++;
        final p = (tick / totalTicks).clamp(0.0, 1.0);
        if (mounted) setState(() => _progress = p);
        if (p >= 1.0) {
          _progressTimer?.cancel();
          _navigateToSetup();
        }
      },
    );
  }

  void _navigateToSetup() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => SetupScreen(
        gameMode: widget.gameMode,
        matchSessionId: widget.matchSessionId,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _checkCtrl.dispose();
    _glowCtrl.dispose();
    _textCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          SizedBox.expand(child: CustomPaint(painter: _BgPainter())),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCheckIcon(),
                  const SizedBox(height: 40),
                  _buildTitle(),
                  const SizedBox(height: 12),
                  _buildSubtitle(),
                  const SizedBox(height: 52),
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCheckIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_checkCtrl, _glowCtrl]),
      builder: (_, _) => Opacity(
        opacity: _checkOpacity.value,
        child: Transform.scale(
          scale: _checkScale.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 바깥 글로우 링
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7CFC00)
                          .withValues(alpha: 0.35 * _glowAnim.value),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // 회전 링 (확인 중 표시)
              AnimatedBuilder(
                animation: _ringCtrl,
                builder: (_, _) => Transform.rotate(
                  angle: _ringCtrl.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(120, 120),
                    painter: _ArcPainter(progress: _progress),
                  ),
                ),
              ),
              // 메인 원형 배경
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4CAF50).withValues(alpha: 0.9),
                      const Color(0xFF2E7D32).withValues(alpha: 0.95),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50)
                          .withValues(alpha: 0.5 * _glowAnim.value),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _textOpacity,
        child: SlideTransition(
          position: _textSlide,
          child: child,
        ),
      ),
      child: const Text(
        '매칭이 완료되었습니다.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _textOpacity,
        child: child,
      ),
      child: Text(
        '매치 정보를 확인하고 있습니다...',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _textOpacity,
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF7CFC00),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_progress * 3).toStringAsFixed(1)}초 / 3.0초',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 확인 중 arc 페인터 ───────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = const Color(0xFF7CFC00).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─── 배경 페인터 ──────────────────────────────────────────────────────────────

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2810), Color(0xFF2D3A15), Color(0xFF3A2208)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final tilePaint = Paint()
      ..color = const Color(0xFF3D5020).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const tw = 30.0;
    const th = 30.0;
    for (double r = -1; r * th < size.height + th; r++) {
      for (double c = -1; c * tw < size.width + tw; c++) {
        final cx = c * tw;
        final cy = r * th;
        canvas.drawPath(
          Path()
            ..moveTo(cx + tw / 2, cy)
            ..lineTo(cx + tw, cy + th / 2)
            ..lineTo(cx + tw / 2, cy + th)
            ..lineTo(cx, cy + th / 2)
            ..close(),
          tilePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
