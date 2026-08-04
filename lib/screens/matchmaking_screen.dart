import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../core/api_client.dart';
import '../models/match_join_response.dart';
import '../services/match_service.dart';
import '../services/match_session_storage.dart';
import '../services/token_storage.dart';
import '../widgets/board_game_box.dart';
import '../widgets/exit_confirm_dialogs.dart';
import 'match_found_screen.dart';
import '../models/game_mode.dart';

class MatchmakingScreen extends StatefulWidget {
  final GameMode gameMode;
  /// 실제 매칭 API 연결 시 서버에서 수신한 세션 ID로 교체
  final String matchSessionId;
  /// 큐 취소 API. null이면 쇼다운 큐 취소를 사용한다.
  final Future<void> Function()? onCancelQueue;
  /// WS 구독 직후 호출. 리그 매칭처럼 join을 대기 화면 진입 후에 할 때 사용.
  final Future<MatchJoinResponse> Function()? pendingJoin;
  const MatchmakingScreen({
    super.key,
    this.gameMode = GameMode.single,
    this.matchSessionId = '',
    this.onCancelQueue,
    this.pendingJoin,
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
  bool _pendingJoinStarted = false;
  bool _matched = false;

  late final AnimationController _dotsCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

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

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _entryCtrl.forward();
    });

    _initWebSocket();
  }

  // ── WebSocket (STOMP) ────────────────────────────────────────────────────
  Future<void> _initWebSocket() async {
    final token = await TokenStorage().getAccessToken();
    final userId =
        token != null ? MatchService.extractUserIdFromJwt(token) : null;

    if (token != null && userId != null && mounted) {
      _stompClient = StompClient(
        config: StompConfig(
          url: ApiClient.wsUrl,
          onConnect: _onStompConnect(userId),
          stompConnectHeaders: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
          webSocketConnectHeaders: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
          onWebSocketError: (dynamic error) {
            // ignore: avoid_print
            print('[WS] 오류: $error');
            // 연결 실패해도 큐 join은 진행 (즉시 MATCHED일 수 있음)
            _runPendingJoin();
          },
          onWebSocketDone: () =>
              // ignore: avoid_print
              print('[WS] 연결 종료'),
        ),
      );
      _stompClient?.activate();
      // WS가 느리거나 실패해도 join이 막히지 않도록 폴백
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _runPendingJoin();
      });
    } else if (mounted) {
      _runPendingJoin();
    }
  }

  void Function(StompFrame) _onStompConnect(String userId) {
    return (_) {
      _stompClient?.subscribe(
        destination: '/topic/user/$userId/match',
        callback: (frame) {
          if (!mounted || _matched) return;
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
      _runPendingJoin();
    };
  }

  Future<void> _runPendingJoin() async {
    final join = widget.pendingJoin;
    if (join == null || _pendingJoinStarted) return;
    _pendingJoinStarted = true;
    try {
      final result = await join();
      if (!mounted || _matched) return;
      if (result.isMatched) {
        _onMatchFound(result.matchSessionId);
      }
      // WAITING이면 이 화면에 머물며 WS 성사를 기다린다.
    } on MatchException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(e);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(
        const MatchException('리그 매칭에 실패했습니다.'),
      );
    }
  }

  void _onMatchFound(String? matchSessionId) {
    if (!mounted || _matched) return;
    _matched = true;
    MatchSessionCoordinator.onMatchFound(
      matchSessionId: matchSessionId,
      gameMode: widget.gameMode,
    );
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
    final cancel = widget.onCancelQueue ?? _matchService.cancelQueue;
    await cancel();
    if (mounted) Navigator.of(context).pop();
  }

  // ── 앱 생명주기: 백그라운드 진입 시 큐 취소 ────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final cancel = widget.onCancelQueue ?? _matchService.cancelQueue;
      cancel();
      _stompClient?.deactivate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stompClient?.deactivate();
    _dotsCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isCancelling) return;
        final cancel = await showMatchmakingCancelConfirmDialog(context);
        if (cancel == true) {
          await _onCancel();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(children: [
          SizedBox.expand(child: CustomPaint(painter: _BgPainter())),
          SafeArea(
            child: Column(children: [
              // 보드게임 상자
              Expanded(
                child: BoardGameBox(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  lockedPanelSize: BoardGameBoxLayout.mainPanelSize(context),
                  heroTagOverride: BoardGameBox.heroTag,
                ),
              ),
              FadeTransition(
                opacity: _entryFade,
                child: SlideTransition(
                  position: _entrySlide,
                  child: Column(
                    children: [
                      _buildSearchingSection(),
                      const SizedBox(height: 36),
                      _buildCancelButton(),
                      const SizedBox(height: 14),
                      _buildTimer(),
                      const SizedBox(height: 44),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
        ),
      ),
    );
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
