import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_mode.dart';
import '../models/pitch_card_data.dart';
import '../widgets/mode_background.dart';

// ─── Phase state machine ──────────────────────────────────────────────────────

enum _Phase { dealing, idle, collecting, shuffling, redealing }

// ─── Mock data (백엔드 연결 전 임시) ─────────────────────────────────────────

List<PitchCardData> _mockCardsForMode(GameMode mode) => switch (mode) {
      GameMode.teamRegular => const [
          PitchCardData(id: '1', name: '포심 패스트볼', direction: '↓', change: 0, timing: '이른'),
          PitchCardData(id: '2', name: '투심 패스트볼', direction: '↙', change: -1, timing: '이른'),
          PitchCardData(id: '3', name: '슬라이더', direction: '↘', change: -2, timing: '보통'),
          PitchCardData(id: '4', name: '체인지업', direction: '↓', change: -3, timing: '늦은'),
          PitchCardData(id: '5', name: '커브', direction: '↙', change: -3, timing: '늦은'),
        ],
      GameMode.teamMini => const [
          PitchCardData(id: '1', name: '포심 패스트볼', direction: '↓', change: 0, timing: '이른'),
          PitchCardData(id: '2', name: '슬라이더', direction: '↘', change: -2, timing: '보통'),
          PitchCardData(id: '3', name: '커브', direction: '↙', change: -3, timing: '늦은'),
          PitchCardData(id: '4', name: '체인지업', direction: '↓', change: -2, timing: '늦은'),
        ],
      _ => const [
          PitchCardData(id: '1', name: '포심 패스트볼', direction: '↓', change: 0, timing: '이른'),
          PitchCardData(id: '2', name: '슬라이더', direction: '↘', change: -2, timing: '보통'),
          PitchCardData(id: '3', name: '커브', direction: '↙', change: -3, timing: '늦은'),
        ],
    };

// ─── Screen ───────────────────────────────────────────────────────────────────

class PitchSelectionScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;

  const PitchSelectionScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
  });

  @override
  State<PitchSelectionScreen> createState() => _PitchSelectionScreenState();
}

class _PitchSelectionScreenState extends State<PitchSelectionScreen>
    with TickerProviderStateMixin {
  // ── Data state ────────────────────────────────────────────────────────────

  late List<PitchCardData> _cards;
  final Set<String> _selectedIds = {};
  bool _hasReplaced = false;
  _Phase _phase = _Phase.dealing;

  /// 현재 교체 중인 카드의 인덱스
  Set<int> _replacingIndices = {};

  // ── Animation controllers ─────────────────────────────────────────────────

  /// 최초 딜 (또는 재딜) 애니메이션
  late AnimationController _dealCtrl;

  /// 선택 카드를 덱으로 수집하는 애니메이션
  late AnimationController _collectCtrl;

  /// 덱 셔플 루프 애니메이션
  late AnimationController _shuffleCtrl;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cards = _mockCardsForMode(widget.gameMode);

    _dealCtrl = AnimationController(
      vsync: this,
      duration: _staggeredDuration(_cards.length),
    );
    _collectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shuffleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _runDealSequence(_dealCtrl);
  }

  @override
  void dispose() {
    _dealCtrl.dispose();
    _collectCtrl.dispose();
    _shuffleCtrl.dispose();
    super.dispose();
  }

  // ── Duration helpers ──────────────────────────────────────────────────────

  /// 카드 수에 따라 딜 애니메이션 전체 길이 계산
  static Duration _staggeredDuration(int n) =>
      Duration(milliseconds: (n - 1) * 130 + 560);

  /// 카드 i의 애니메이션 구간 (Interval 기준 0~1)
  Animation<double> _dealInterval(int i, AnimationController ctrl) {
    final totalMs = _staggeredDuration(_cards.length).inMilliseconds.toDouble();
    final start = (i * 130.0) / totalMs;
    final end = (i * 130.0 + 560.0) / totalMs;
    return CurvedAnimation(
      parent: ctrl,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
  }

  // ── Phase transitions ─────────────────────────────────────────────────────

  Future<void> _runDealSequence(AnimationController ctrl) async {
    setState(() => _phase = _Phase.dealing);
    await ctrl.forward(from: 0);
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  // ── User interactions ─────────────────────────────────────────────────────

  void _toggleSelect(String id) {
    if (_phase != _Phase.idle || _hasReplaced) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _onReplace() async {
    if (_selectedIds.isEmpty || _hasReplaced || _phase != _Phase.idle) return;

    _replacingIndices = {
      for (int i = 0; i < _cards.length; i++)
        if (_selectedIds.contains(_cards[i].id)) i,
    };

    // ── 1단계: 수집 (선택 카드 → 덱) ──────────────────────────────────────
    setState(() => _phase = _Phase.collecting);
    await _collectCtrl.forward(from: 0);
    if (!mounted) return;

    // ── 2단계: 셔플 루프 (API 대기 중) ────────────────────────────────────
    setState(() => _phase = _Phase.shuffling);
    _shuffleCtrl.repeat();

    // TODO: 실제 WebSocket 교체 요청으로 교체
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;

    // ── 새 카드 데이터 적용 (mock) ─────────────────────────────────────────
    final updatedCards = List<PitchCardData>.from(_cards);
    final pool = _mockCardsForMode(widget.gameMode);
    for (final i in _replacingIndices) {
      updatedCards[i] = pool[i % pool.length].copyWith(id: 'r$i');
    }

    _shuffleCtrl.stop();
    _shuffleCtrl.reset();
    _collectCtrl.reset();

    setState(() {
      _cards = updatedCards;
      _selectedIds.clear();
      _hasReplaced = true;
      _phase = _Phase.redealing;
    });

    // ── 3단계: 재딜 (새 카드 등장) ────────────────────────────────────────
    // 교체된 카드만 새로 딜
    final redealCtrl = AnimationController(
      vsync: this,
      duration: _staggeredDuration(_replacingIndices.length),
    );
    await redealCtrl.forward(from: 0);
    redealCtrl.dispose();

    if (mounted) setState(() => _phase = _Phase.idle);
  }

  void _onConfirm() {
    if (_phase != _Phase.idle) return;
    // TODO: WebSocket으로 확정 구종 전송 후 게임플레이 화면으로 전환
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          ModeBackground(mode: widget.gameMode),
          SafeArea(
            child: Column(children: [
              _buildHeader(),
              Expanded(child: _buildCardsArea()),
              _buildBottomButtons(),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              '구종 선택',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(_hasReplaced),
                _hasReplaced
                    ? '교체 완료 — 더 이상 교체할 수 없습니다'
                    : '교체할 구종을 선택하세요 (1회)',
                style: TextStyle(
                  color: _hasReplaced
                      ? const Color(0xFFFF8080).withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: 0.60),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ),
          ]),
          const Spacer(),
          if (_selectedIds.isNotEmpty)
            AnimatedOpacity(
              opacity: _selectedIds.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.50)),
                ),
                child: Text(
                  '${_selectedIds.length}장 선택',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Cards area ────────────────────────────────────────────────────────────

  Widget _buildCardsArea() {
    return Column(
      children: [
        // 덱 오버레이 (애니메이션 단계에서만 표시)
        _buildDeckOverlay(),
        const SizedBox(height: 8),
        // 카드 행
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _cards.length; i++) ...[
                    _buildCardSlot(i),
                    if (i < _cards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Deck overlay ──────────────────────────────────────────────────────────

  Widget _buildDeckOverlay() {
    final visible = _phase != _Phase.idle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: visible ? 90 : 0,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Center(
          child: _phase == _Phase.shuffling
              ? _buildShufflingDeck()
              : _buildStaticDeck(),
        ),
      ),
    );
  }

  Widget _buildStaticDeck() {
    return SizedBox(
      width: 60,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(4, (i) {
          return Transform.translate(
            offset: Offset(0, -(3 - i) * 2.0),
            child: Transform.rotate(
              angle: (i - 1.5) * 0.04,
              child: _deckCard(),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShufflingDeck() {
    return AnimatedBuilder(
      animation: _shuffleCtrl,
      builder: (_, child) {
        final angle = math.sin(_shuffleCtrl.value * math.pi * 2) * 0.22;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(angle: angle, child: child),
            const SizedBox(height: 6),
            Text(
              '섞는 중...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
          ],
        );
      },
      child: _buildStaticDeck(),
    );
  }

  Widget _deckCard() => Container(
        width: 44,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'BB',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.20),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      );

  // ── Card slot builder ─────────────────────────────────────────────────────

  Widget _buildCardSlot(int i) {
    final card = _cards[i];
    final isSelected = _selectedIds.contains(card.id);
    final isReplacing = _replacingIndices.contains(i);
    final canInteract = _phase == _Phase.idle && !_hasReplaced;

    // ── 최초 딜 애니메이션 ────────────────────────────────────────────────
    if (_phase == _Phase.dealing) {
      final anim = _dealInterval(i, _dealCtrl);
      return _withDealTransform(
        anim: anim,
        direction: i.isEven ? 1 : -1,
        child: _PitchCardWidget(card: card, isSelected: false, onTap: null),
      );
    }

    // ── 수집 애니메이션 (선택된 카드만) ──────────────────────────────────
    if (_phase == _Phase.collecting && isReplacing) {
      return AnimatedBuilder(
        animation: _collectCtrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -180.0 * _collectCtrl.value),
          child: Transform.scale(
            scale: 1.0 - _collectCtrl.value * 0.6,
            child: Opacity(opacity: 1.0 - _collectCtrl.value, child: child),
          ),
        ),
        child: _PitchCardWidget(card: card, isSelected: true, onTap: null),
      );
    }

    // ── 셔플 중: 교체 슬롯은 빈 자리 표시 ────────────────────────────────
    if ((_phase == _Phase.shuffling || _phase == _Phase.collecting) &&
        isReplacing) {
      return _CardPlaceholder(width: _kCardW, height: _kCardH);
    }

    // ── 재딜 애니메이션 (교체된 카드만) ──────────────────────────────────
    if (_phase == _Phase.redealing && isReplacing) {
      // 교체 인덱스 내에서의 순서
      final localIdx =
          _replacingIndices.toList().indexOf(i).clamp(0, _replacingIndices.length - 1);
      return AnimatedBuilder(
        animation: _collectCtrl, // collectCtrl이 0으로 리셋됨 → 이 시점엔 0
        builder: (_, child) {
          // 딜레이: 교체 인덱스 순서마다 100ms
          return FutureBuilder<void>(
            future: Future.delayed(Duration(milliseconds: localIdx * 100)),
            builder: (_, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _CardPlaceholder(width: _kCardW, height: _kCardH);
              }
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => _withDealTransformValue(
                  value: v,
                  direction: i.isEven ? 1 : -1,
                  child: child!,
                ),
                child: _PitchCardWidget(card: card, isSelected: false, onTap: null),
              );
            },
          );
        },
        child: _CardPlaceholder(width: _kCardW, height: _kCardH),
      );
    }

    // ── 기본 상태 ─────────────────────────────────────────────────────────
    return _PitchCardWidget(
      card: card,
      isSelected: isSelected,
      onTap: canInteract ? () => _toggleSelect(card.id) : null,
    );
  }

  // ── Animation transform helpers ───────────────────────────────────────────

  Widget _withDealTransform({
    required Animation<double> anim,
    required int direction,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => _withDealTransformValue(
        value: anim.value,
        direction: direction,
        child: c!,
      ),
      child: child,
    );
  }

  Widget _withDealTransformValue({
    required double value,
    required int direction,
    required Widget child,
  }) {
    return Transform.translate(
      offset: Offset(0, -220.0 * (1 - value)),
      child: Transform.rotate(
        angle: (1 - value) * 0.28 * direction,
        alignment: Alignment.bottomCenter,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
    );
  }

  // ── Bottom buttons ────────────────────────────────────────────────────────

  Widget _buildBottomButtons() {
    final canReplace =
        _selectedIds.isNotEmpty && !_hasReplaced && _phase == _Phase.idle;
    final isAnimating = _phase != _Phase.idle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          // ── 교체 버튼 ──────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: canReplace ? _onReplace : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 54,
                decoration: BoxDecoration(
                  color: canReplace
                      ? const Color(0xFF1565C0).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: canReplace
                        ? const Color(0xFF42A5F5).withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: canReplace
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isAnimating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: canReplace
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hasReplaced ? '교체 불가' : '교체',
                              style: TextStyle(
                                color: canReplace
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.28),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── 확정 버튼 ──────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: !isAnimating ? _onConfirm : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 54,
                decoration: BoxDecoration(
                  gradient: !isAnimating
                      ? const LinearGradient(
                          colors: [Color(0xFF8AFF2A), Color(0xFF4CAF50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isAnimating ? Colors.white.withValues(alpha: 0.08) : null,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isAnimating
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                  boxShadow: !isAnimating
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7CFC00).withValues(alpha: 0.38),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '확정',
                    style: TextStyle(
                      color: !isAnimating
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.28),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
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

// ─── Constants ────────────────────────────────────────────────────────────────

const double _kCardW = 104.0;
const double _kCardH = 158.0;

// ─── Pitch card widget ────────────────────────────────────────────────────────

class _PitchCardWidget extends StatelessWidget {
  final PitchCardData card;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PitchCardWidget({
    required this.card,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _kCardW,
        height: _kCardH,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, isSelected ? -10.0 : 0.0, 0.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF12122A).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.16),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFFFD700).withValues(alpha: 0.38)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: isSelected ? 16 : 8,
              spreadRadius: isSelected ? 2 : 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 타이밍 컬러 상단 바
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: card.timingColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                ),
              ),
            ),
            // 카드 콘텐츠
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 13, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 구종 이름
                  Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // 방향 화살표 (크게)
                  Center(
                    child: Text(
                      card.direction,
                      style: TextStyle(
                        color: card.timingColor,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: card.timingColor.withValues(alpha: 0.40),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 스탯 행
                  _StatRow(label: '방향', value: card.direction),
                  const SizedBox(height: 3),
                  _StatRow(label: '변화', value: card.changeLabel),
                  const SizedBox(height: 3),
                  _StatRow(
                      label: '타이밍',
                      value: card.timing,
                      valueColor: card.timingColor),
                ],
              ),
            ),
            // 선택 체크 뱃지
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFD700),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.black, size: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat row ─────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Empty slot placeholder ───────────────────────────────────────────────────

class _CardPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  const _CardPlaceholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          style: BorderStyle.solid,
        ),
      ),
    );
  }
}
