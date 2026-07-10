import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../core/api_client.dart';
import '../services/match_service.dart';
import '../services/token_storage.dart';
import 'match_found_screen.dart';
import '../models/game_mode.dart';

class MatchmakingScreen extends StatefulWidget {
  final GameMode gameMode;
  /// 실제 매칭 API 연결 시 서버에서 수신한 세션 ID로 교체
  final String matchSessionId;
  const MatchmakingScreen({
    super.key,
    this.gameMode = GameMode.single,
    this.matchSessionId = '',
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _seconds = 0;
  Timer? _timer;

  final _matchService = MatchService();
  StompClient? _stompClient;
  bool _isCancelling = false;

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatY;
  late final Animation<double> _shadowScale;

  late final AnimationController _dotsCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    // 캐릭터 플로팅
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _shadowScale = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // 세 점 애니메이션
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 탐색 링 펄스
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initWebSocket();
  }

  // ── WebSocket (STOMP) ────────────────────────────────────────────────────
  Future<void> _initWebSocket() async {
    final token = await TokenStorage().getAccessToken();
    if (token == null || !mounted) return;

    final userId = MatchService.extractUserIdFromJwt(token);
    if (userId == null || !mounted) return;

    _stompClient = StompClient(
      config: StompConfig(
        url: ApiClient.wsUrl,
        onConnect: _onStompConnect(userId),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onWebSocketError: (dynamic error) =>
            // ignore: avoid_print
            print('[WS] 오류: $error'),
        onWebSocketDone: () =>
            // ignore: avoid_print
            print('[WS] 연결 종료'),
      ),
    );
    _stompClient?.activate();
  }

  void Function(StompFrame) _onStompConnect(String userId) {
    return (_) {
      _stompClient?.subscribe(
        destination: '/topic/user/$userId/match',
        callback: (frame) {
          if (!mounted) return;
          String? matchSessionId;
          try {
            final body = frame.body;
            if (body != null && body.isNotEmpty) {
              final data = jsonDecode(body) as Map<String, dynamic>;
              matchSessionId = data['matchSessionId'] as String?;
            }
          } catch (_) {}
          _onMatchFound(matchSessionId);
        },
      );
    };
  }

  void _onMatchFound(String? matchSessionId) {
    if (!mounted) return;
    _stompClient?.deactivate();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => MatchFoundScreen(
        matchSessionId: matchSessionId,
        gameMode: widget.gameMode,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  Future<void> _onCancel() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    _stompClient?.deactivate();
    await _matchService.cancelQueue();
    if (mounted) Navigator.of(context).pop();
  }

  // ── 앱 생명주기: 백그라운드 진입 시 큐 취소 ────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _matchService.cancelQueue();
      _stompClient?.deactivate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stompClient?.deactivate();
    _floatCtrl.dispose();
    _dotsCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _timeDisplay {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    if (m > 0) return '$m분 ${s.toString().padLeft(2, '0')}초';
    return '$s초';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          SizedBox.expand(child: CustomPaint(painter: _BgPainter())),
          SafeArea(
            child: Column(children: [
              // 캐릭터
              Expanded(child: _buildCharacter()),
              // 탐색 인디케이터
              _buildSearchingSection(),
              const SizedBox(height: 36),
              // 취소 버튼
              _buildCancelButton(),
              const SizedBox(height: 14),
              // 타이머
              _buildTimer(),
              const SizedBox(height: 44),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── 캐릭터 (플로팅) ───────────────────────────────────────────────────────
  Widget _buildCharacter() {
    return LayoutBuilder(builder: (context, constraints) {
      return AnimatedBuilder(
        animation: _floatCtrl,
        builder: (_, child) => Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: 0, bottom: 16, left: 0, right: 0,
              child: Transform.translate(
                offset: Offset(0, _floatY.value), child: child,
              ),
            ),
            Positioned(
              bottom: 4,
              child: Transform.scale(
                scaleX: _shadowScale.value,
                child: Container(
                  width: constraints.maxWidth * 0.28,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.black.withValues(alpha: 0.42),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10, spreadRadius: 2,
                    )],
                  ),
                ),
              ),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/character.png',
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
        ),
      );
    });
  }

  // ── 탐색 중 텍스트 + 점 ──────────────────────────────────────────────────
  Widget _buildSearchingSection() {
    return Column(children: [
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Opacity(
          opacity: _pulseAnim.value,
          child: child,
        ),
        child: const Text(
          '상대 탐색 중',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
      const SizedBox(height: 18),
      AnimatedBuilder(
        animation: _dotsCtrl,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final offset = i / 3.0;
            final t = (_dotsCtrl.value - offset).remainder(1.0);
            final clamped = t < 0 ? t + 1 : t;
            final bounce = clamped < 0.5
                ? clamped * 2
                : (1 - clamped) * 2;
            final dy = -10.0 * bounce;
            final scale = 0.75 + 0.25 * bounce;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD700).withValues(
                        alpha: 0.5 + 0.5 * bounce,
                      ),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3 * bounce),
                        blurRadius: 6,
                      )],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  // ── 취소 버튼 ─────────────────────────────────────────────────────────────
  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: GestureDetector(
        onTap: _isCancelling ? null : _onCancel,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2810).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10, offset: const Offset(0, 4),
            )],
          ),
          child: _isCancelling
              ? const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF8080),
                    ),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, color: Color(0xFFFF8080), size: 20),
                    SizedBox(width: 8),
                    Text('취소', style: TextStyle(
                      color: Color(0xFFFF8080),
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
        ),
      ),
    );
  }

  // ── 타이머 ────────────────────────────────────────────────────────────────
  Widget _buildTimer() {
    return Text(
      _timeDisplay,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
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
