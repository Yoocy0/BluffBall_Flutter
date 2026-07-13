import 'dart:math' as math;

import 'package:flutter/material.dart';import 'package:flutter/services.dart';

import '../models/card_info.dart';
import '../models/double_judgment_config.dart';
import '../models/game_mode.dart';
import '../services/game_flow_controller.dart';
import '../services/game_match_meta_service.dart';
import '../widgets/dice_widget.dart';
import '../widgets/mode_background.dart';
import 'batter_game_screen.dart';
import 'pitcher_game_screen.dart';

// ─── Phase ────────────────────────────────────────────────────────────────────

enum _Phase { loading, error, drawCard, rollDice, summary }

// ─── Screen ───────────────────────────────────────────────────────────────────

/// 멀리건 완료 후 2루타 판정 조건을 카드·주사위 연출로 공개하는 화면.
class DoubleJudgmentRevealScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;
  final Map<String, List<int>> setupNumbers;
  final List<CardInfo> handCards;
  final int currentUserId;
  final int pitcherUserId;

  const DoubleJudgmentRevealScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    this.setupNumbers = const {},
    required this.handCards,
    required this.currentUserId,
    required this.pitcherUserId,
  });

  @override
  State<DoubleJudgmentRevealScreen> createState() =>
      _DoubleJudgmentRevealScreenState();
}

class _DoubleJudgmentRevealScreenState extends State<DoubleJudgmentRevealScreen>
    with TickerProviderStateMixin {
  static const _kAccent = Color(0xFFFFC107);
  static const _kCardW = 120.0;
  static const _kCardH = 172.0;
  static const _kPhaseHold = Duration(seconds: 1);
  final _metaService = GameMatchMetaService();

  _Phase _phase = _Phase.loading;
  DoubleJudgmentConfig? _config;
  String? _loadError;

  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  late final AnimationController _summaryCtrl;  late final Animation<double> _summaryFade;
  late final Animation<double> _summaryScale;

  bool _cardRevealed = false;
  bool _diceLanded = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flipAnim = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutBack),
    );

    _summaryCtrl = AnimationController(      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _summaryFade = CurvedAnimation(parent: _summaryCtrl, curve: Curves.easeOut);
    _summaryScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _summaryCtrl, curve: Curves.easeOutBack),
    );

    _loadConfig();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }
  Future<void> _loadConfig() async {
    final config =
        await _metaService.fetchDoubleJudgment(widget.matchSessionId);
    if (!mounted) return;

    if (config == null) {
      setState(() {
        _phase = _Phase.error;
        _loadError = '2루타 조건을 불러오지 못했습니다.';
      });
      return;
    }

    setState(() {
      _config = config;
      _phase = _Phase.drawCard;
    });

    _startCardSequence();
  }

  Future<void> _startCardSequence() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _phase != _Phase.drawCard) return;
    await _revealCard();
  }

  Future<void> _revealCard() async {
    if (_cardRevealed || _config == null) return;
    _cardRevealed = true;
    HapticFeedback.mediumImpact();
    await _flipCtrl.forward();
    if (!mounted || _phase != _Phase.drawCard) return;
    await Future.delayed(_kPhaseHold);
    if (!mounted) return;
    setState(() => _phase = _Phase.rollDice);
  }

  void _onDiceLanded() {
    if (!mounted || _diceLanded) return;
    _diceLanded = true;
    HapticFeedback.lightImpact();
    Future.delayed(_kPhaseHold, () {
      if (!mounted || _phase != _Phase.rollDice) return;
      setState(() => _phase = _Phase.summary);
      _summaryCtrl.forward();
    });
  }
  void _goToGame({bool skipReveal = false}) {
    if (!mounted || _navigated) return;
    _navigated = true;

    final isPitcher = widget.currentUserId == widget.pitcherUserId;
    final doubleJudgment = _config;

    GameFlowController.instance.updateSession(GameSessionContext(
      gameMode: widget.gameMode,
      matchSessionId: widget.matchSessionId,
      setupNumbers: widget.setupNumbers,
      doubleJudgment: doubleJudgment,
      currentUserId: widget.currentUserId,
      initialPitcherUserId: widget.pitcherUserId,
      handCards: widget.handCards,
    ));

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _a, _b) => isPitcher
          ? PitcherGameScreen(
              gameMode: widget.gameMode,
              matchSessionId: widget.matchSessionId,
              setupNumbers: widget.setupNumbers,
              doubleJudgment: doubleJudgment,
              handCards: widget.handCards,
              currentUserId: widget.currentUserId,
              initialPitcherUserId: widget.pitcherUserId,
            )
          : BatterGameScreen(
              gameMode: widget.gameMode,
              matchSessionId: widget.matchSessionId,
              setupNumbers: widget.setupNumbers,
              doubleJudgment: doubleJudgment,
              handCards: widget.handCards,
              currentUserId: widget.currentUserId,
              initialPitcherUserId: widget.pitcherUserId,
            ),
      transitionsBuilder: (_, anim, _c, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: Duration(milliseconds: skipReveal ? 300 : 400),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ModeBackground(mode: widget.gameMode),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  Expanded(child: _buildBody()),
                  const SizedBox(height: 16),
                  _buildBottomAction(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withValues(alpha: 0.45)),
          ),
          child: const Text(
            '◎◎ 2루타 조건',
            style: TextStyle(
              color: _kAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _phaseTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _phaseSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  String get _phaseTitle => switch (_phase) {
        _Phase.loading => '조건 확인 중',
        _Phase.error => '조건 불러오기 실패',
        _Phase.drawCard => '주사위 선택',
        _Phase.rollDice => '목표 눈금',
        _Phase.summary => '2루타 조건 확정',
      };

  String get _phaseSubtitle => switch (_phase) {
        _Phase.loading => '이번 경기의 2루타 판정 조건을 가져오고 있습니다.',
        _Phase.error => _loadError ?? '잠시 후 다시 시도해주세요.',
        _Phase.drawCard => '카드를 뽑아 어떤 주사위를 볼지 확인하세요.',
        _Phase.rollDice => '선택된 주사위에 나와야 할 눈금입니다.',
        _Phase.summary =>
            '블러핑 숫자와 맞지 않을 때 아래 조건이면 2루타가 됩니다.',
      };

  Widget _buildBody() {
    return switch (_phase) {
      _Phase.loading => const Center(
          child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2.5),
        ),
      _Phase.error => Center(
          child: Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      _Phase.drawCard => _buildCardPhase(),
      _Phase.rollDice => _buildDicePhase(),
      _Phase.summary => _buildSummaryPhase(),
    };
  }

  Widget _buildCardPhase() {
    final config = _config!;
    return Center(
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (_, child) {
          final angle = _flipAnim.value;
          final showFront = angle >= math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _DiceSelectCard(
                      diceNumber: config.diceNumber,
                      diceLabel: config.diceLabel,
                    ),
                  )
                : const _CardBack(),
          );
        },
      ),
    );
  }
  Widget _buildDicePhase() {
    final config = _config!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              '${config.diceLabel} · 목표 ${config.targetFace}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 36),
          DiceThrowWidget(
            diceCount: 1,
            diceValues: [config.targetFace],
            diceSize: 64,
            onLanded: _onDiceLanded,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPhase() {
    final config = _config!;
    return FadeTransition(
      opacity: _summaryFade,
      child: ScaleTransition(
        scale: _summaryScale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SummaryChip(
                  label: '주사위',
                  value: '${config.diceNumber}',
                  accent: _kAccent,
                ),
                const SizedBox(width: 20),
                _SummaryChip(
                  label: '눈금',
                  value: '${config.targetFace}',
                  accent: _kAccent,
                ),
              ],
            ),
            const SizedBox(height: 32),
            DiceWidget(value: config.targetFace, size: 72),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15,
                    height: 1.55,
                  ),
                  children: [
                    const TextSpan(text: '주사위 2개를 굴릴 때\n'),
                    TextSpan(
                      text: '${config.diceNumber}번째 주사위',
                      style: const TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '에 '),
                    TextSpan(
                      text: '${config.targetFace}',
                      style: const TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const TextSpan(text: '이 나오면\n'),
                    const TextSpan(
                      text: '2루타',
                      style: TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '가 됩니다'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return switch (_phase) {
      _Phase.loading => const SizedBox.shrink(),
      _Phase.error => Row(
          children: [
            Expanded(
              child: _OutlineButton(
                label: '다시 시도',
                onTap: () {
                  setState(() {
                    _phase = _Phase.loading;
                    _loadError = null;
                    _cardRevealed = false;
                    _diceLanded = false;
                    _flipCtrl.reset();
                    _summaryCtrl.reset();
                  });
                  _loadConfig();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: '경기 시작',
                onTap: () => _goToGame(skipReveal: true),
              ),
            ),
          ],
        ),
      _Phase.summary => _PrimaryButton(
          label: '경기 시작',
          onTap: _goToGame,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _DoubleJudgmentRevealScreenState._kCardW,
      height: _DoubleJudgmentRevealScreenState._kCardH,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A3A), Color(0xFF0E0E22)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_rounded,
            size: 48,
            color: const Color(0xFFFFC107).withValues(alpha: 0.85),
          ),
          const SizedBox(height: 10),
          Text(
            'BLUFF',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiceSelectCard extends StatelessWidget {
  final int diceNumber;
  final String diceLabel;

  const _DiceSelectCard({
    required this.diceNumber,
    required this.diceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _DoubleJudgmentRevealScreenState._kCardW,
      height: _DoubleJudgmentRevealScreenState._kCardH,
      decoration: BoxDecoration(
        color: const Color(0xFF12122A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$diceNumber',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 72,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            diceLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
            border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFC107),
          foregroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
