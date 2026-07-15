import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card_info.dart';
import '../models/game_mode.dart';
import '../models/turn_result_event.dart';
import '../navigation/app_navigator.dart';
import '../services/game_flow_controller.dart';
import '../services/game_forfeit_service.dart';
import '../widgets/exit_confirm_dialogs.dart';
import '../widgets/dice_widget.dart';
import '../widgets/mode_background.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class TurnResultScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;
  final TurnResultEvent event;
  final Map<String, List<int>> setupNumbers;
  final int currentUserId;

  /// 투수가 이 턴에 사용한 (또는 보유 중인) 핸드 카드.
  /// halfInningChanged=false일 때 PitcherGameScreen으로 그대로 전달됩니다.
  final List<CardInfo> myHandCards;

  const TurnResultScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    required this.event,
    required this.currentUserId,
    required this.myHandCards,
    this.setupNumbers = const {},
  });

  @override
  State<TurnResultScreen> createState() => _TurnResultScreenState();
}

enum _ResultPhase { dice, reveal }

class _TurnResultScreenState extends State<TurnResultScreen>
    with SingleTickerProviderStateMixin {
  _ResultPhase _phase = _ResultPhase.dice;
  late final AnimationController _revealCtrl;
  late final Animation<double> _revealFade;
  late final Animation<double> _revealScale;

  // 3초 자동 이동 타이머
  Timer? _autoNavTimer;
  double _countdown = 3.0;
  Timer? _countdownDisplay;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _revealFade = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    _revealScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.elasticOut),
    );

    if (widget.event.diceResults.isEmpty) {
      // 주사위 없으면 바로 결과 표시 후 3초 카운트
      _phase = _ResultPhase.reveal;
      _revealCtrl.forward();
      _startCountdown();
    }
    // 주사위 있으면 _onDiceLanded에서 처리
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _autoNavTimer?.cancel();
    _countdownDisplay?.cancel();
    super.dispose();
  }

  // ── Dice & countdown ──────────────────────────────────────────────────────

  void _onDiceLanded() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _phase = _ResultPhase.reveal);
      _revealCtrl.forward();
      _startCountdown();
    });
  }

  void _startCountdown() {
    _countdown = 3.0;
    _countdownDisplay = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown = (_countdown - 0.1).clamp(0.0, 3.0));
    });
    _autoNavTimer = Timer(const Duration(seconds: 3), _navigate);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigate() {
    if (!mounted) return;
    _autoNavTimer?.cancel();
    _countdownDisplay?.cancel();

    final nav = rootNavigatorKey.currentState ?? Navigator.of(context);
    final ctx = GameFlowController.instance.session;
    if (ctx == null) return;

    GameFlowController.instance.navigateAfterResultCountdown(
      nav,
      ctx,
      widget.event,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showInGameForfeitConfirmDialog(context);
        if (leave != true) return;
        await GameForfeitService.instance.leaveMatchWithForfeit(
          gameMode: widget.gameMode,
          matchSessionId: widget.matchSessionId,
        );
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(children: [
            ModeBackground(mode: widget.gameMode),
            Container(color: Colors.black.withValues(alpha: 0.50)),
            SafeArea(
              child: Column(children: [
                _buildHeader(ev),
                _buildCountBoard(ev),
                Expanded(child: _buildCenterArea(ev)),
                _buildBasesRow(ev),
                _buildCountdownBar(),
                const SizedBox(height: 20),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(TurnResultEvent ev) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Text(
          '${ev.inning}회 ${ev.isTop ? '초' : '말'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Row(children: [
            const Text(
              '홈 ',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${ev.homeScore}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(':',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40), fontSize: 13)),
            ),
            Text(
              '${ev.awayScore}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const Text(
              ' 원정',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Count board ───────────────────────────────────────────────────────────

  Widget _buildCountBoard(TurnResultEvent ev) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _countItem('B', ev.balls, 2, const Color(0xFF64B5F6)),
          _countDivider(),
          _countItem('S', ev.strikes, 3, const Color(0xFFFFD740)),
          _countDivider(),
          _countItem('O', ev.outs, 2, const Color(0xFFFF5252)),
        ],
      ),
    );
  }

  Widget _countItem(String label, int count, int max, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
              color: color.withValues(alpha: 0.80),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            )),
        const SizedBox(width: 6),
        Row(
          children: List.generate(max, (i) => Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < count ? color : color.withValues(alpha: 0.20),
                  boxShadow: i < count
                      ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 4)]
                      : null,
                ),
              )),
        ),
      ],
    );
  }

  Widget _countDivider() => Container(
        width: 1,
        height: 14,
        color: Colors.white.withValues(alpha: 0.15),
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );

  // ── Center area ───────────────────────────────────────────────────────────

  Widget _buildCenterArea(TurnResultEvent ev) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ev.diceResults.isNotEmpty) ...[
            DiceThrowWidget(
              diceCount: ev.diceResults.length,
              diceValues: ev.diceResults,
              onLanded: _onDiceLanded,
              diceSize: 62.4,
            ),
            AnimatedOpacity(
              opacity: _phase == _ResultPhase.reveal ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  '합계  ${ev.diceResults.fold(0, (a, b) => a + b)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _revealFade,
            child: ScaleTransition(
              scale: _revealScale,
              child: _buildResultCard(ev),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(TurnResultEvent ev) {
    final color = ev.resultColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.50),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 좌측 컬러 바
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ev.resultLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                // 구종명 — 검정, 작게
                Text(
                  ev.pitchCardName,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 기호
          Text(
            ev.resultEmoji,
            style: TextStyle(
              color: color.withValues(alpha: 0.20),
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bases row ─────────────────────────────────────────────────────────────

  Widget _buildBasesRow(TurnResultEvent ev) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('주자',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _BasesWidget(
            first: ev.firstBase,
            second: ev.secondBase,
            third: ev.thirdBase,
          ),
        ],
      ),
    );
  }

  // ── Countdown bar ─────────────────────────────────────────────────────────

  Widget _buildCountdownBar() {
    final ratio = (_countdown / 3.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.event.halfInningChanged
                    ? '공수 교대'
                    : (widget.event.gameOver ? '게임 종료' : '다음 투구'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_countdown.toStringAsFixed(1)}초',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 4, color: Colors.white.withValues(alpha: 0.10)),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 100),
                widthFactor: ratio,
                child: Container(
                  height: 4,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Bases widget ─────────────────────────────────────────────────────────────

class _BasesWidget extends StatelessWidget {
  final bool first;
  final bool second;
  final bool third;

  const _BasesWidget({
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  Widget build(BuildContext context) {
    const size = 14.0;
    const gap = 4.0;
    const occupied = Color(0xFFFFD740);
    const empty = Colors.white24;

    return SizedBox(
      width: size * 3 + gap * 2 + 4,
      height: size * 2 + gap + 2,
      child: Stack(children: [
        Positioned(
          top: 0,
          left: size + gap,
          child: _base(second, size, occupied, empty),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: _base(third, size, occupied, empty),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _base(first, size, occupied, empty),
        ),
      ]),
    );
  }

  Widget _base(bool occ, double size, Color on, Color off) => Transform.rotate(
        angle: 0.785,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: occ ? on : off,
            borderRadius: BorderRadius.circular(2),
            boxShadow: occ
                ? [BoxShadow(color: on.withValues(alpha: 0.60), blurRadius: 6)]
                : null,
          ),
        ),
      );
}
