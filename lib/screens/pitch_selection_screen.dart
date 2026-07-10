import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card_hand_event.dart';
import '../models/card_info.dart';
import '../models/game_mode.dart';
import '../services/game_websocket_service.dart';
import '../services/match_service.dart';
import '../services/token_storage.dart';
import '../widgets/mode_background.dart';
import 'batter_game_screen.dart';
import 'pitcher_game_screen.dart';

// ─── Phase state machine ──────────────────────────────────────────────────────

enum _Phase { waiting, dealing, idle, collecting, shuffling, redealing }

// ─── Screen ───────────────────────────────────────────────────────────────────

class PitchSelectionScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;

  /// 셋업 숫자 선택 결과 { '아웃': [...], '병살': [...], '3루타': [...], '홈런': [...] }
  final Map<String, List<int>> setupNumbers;

  const PitchSelectionScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    this.setupNumbers = const {},
  });

  @override
  State<PitchSelectionScreen> createState() => _PitchSelectionScreenState();
}

class _PitchSelectionScreenState extends State<PitchSelectionScreen>
    with TickerProviderStateMixin {
  // ── Data state ────────────────────────────────────────────────────────────

  List<CardInfo> _cards = [];
  List<CardInfo>? _originalCards; // 교체 전 카드 (비교용)
  final Set<int> _selectedIds = {};
  bool _hasReplaced = false;
  _Phase _phase = _Phase.waiting;
  Set<int> _replacingIndices = {};

  // ── WebSocket ─────────────────────────────────────────────────────────────

  final _ws = GameWebSocketService.instance;
  int? _currentUserId;

  /// 멀리건 응답 대기용 Completer
  Completer<CardHandEvent>? _mulliganCompleter;
  bool _isConfirming = false;

  /// allMulliganReady 수신 시 내비게이션에 사용할 마지막 카드 이벤트
  CardHandEvent? _latestHandEvent;

  // ── Animation controllers ─────────────────────────────────────────────────

  late AnimationController _dealCtrl;
  late AnimationController _collectCtrl;
  late AnimationController _shuffleCtrl;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // 카드 수 미확정이므로 placeholder duration으로 초기화
    _dealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _collectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shuffleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _initWebSocket();
  }

  @override
  void dispose() {
    // WebSocket 연결은 유지 — BatterGameScreen/PitcherGameScreen이 계속 사용.
    // 게임 종료 시 GameOverScreen 또는 홈으로 이동할 때 disconnect 호출.
    _dealCtrl.dispose();
    _collectCtrl.dispose();
    _shuffleCtrl.dispose();
    super.dispose();
  }

  // ── WebSocket init ────────────────────────────────────────────────────────

  Future<void> _initWebSocket() async {
    final token = await TokenStorage().getAccessToken();
    if (token == null || !mounted) return;

    final userIdStr = MatchService.extractUserIdFromJwt(token);
    _currentUserId = userIdStr != null ? int.tryParse(userIdStr) : null;

    // ignore: avoid_print
    print('[PitchScreen] userId from JWT: "$userIdStr" → int: $_currentUserId');
    // ignore: avoid_print
    print('[PitchScreen] WS isConnected: ${_ws.isConnected}');

    if (_ws.isConnected) {
      _subscribeToGameTopic();
    } else {
      // SetupScreen에서 연결이 끊겼을 경우 재연결
      _ws.connect(
        accessToken: token,
        onConnected: () {
          // ignore: avoid_print
          print('[PitchScreen] WS 재연결 성공, 구독 시작');
          if (mounted) _subscribeToGameTopic();
        },
        onError: (msg) {
          // ignore: avoid_print
          print('[PitchScreen] WS 연결 실패: $msg');
          if (mounted) {
            _showSnackBar('서버 연결 실패: $msg', isError: true);
          }
        },
      );
    }
  }

  void _subscribeToGameTopic() {
    if (_currentUserId == null) return;
    _ws.subscribeGameTopic(
      matchSessionId: widget.matchSessionId,
      currentUserId: _currentUserId!,
      onEvent: _handleCardHandEvent,
      onAllReady: _handleAllReady,
    );
  }

  void _handleCardHandEvent(CardHandEvent event) {
    if (!mounted) return;
    _latestHandEvent = event;
    if (event.fromMulligan) {
      _mulliganCompleter?.complete(event);
      if (event.allMulliganReady) {
        _navigateToGameScreen(event);
      }
    } else {
      _onInitialDeal(event.cardInfos);
    }
  }

  void _handleAllReady(bool allReady) {
    if (!mounted || _latestHandEvent == null) return;
    _navigateToGameScreen(_latestHandEvent!);
  }

  void _navigateToGameScreen(CardHandEvent event) {
    if (!mounted) return;
    final isPitcher = _currentUserId == event.pitcherUserId;

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _a, _b) => isPitcher
          ? PitcherGameScreen(
              gameMode: widget.gameMode,
              matchSessionId: widget.matchSessionId,
              setupNumbers: widget.setupNumbers,
              handCards: event.cardInfos,
              currentUserId: _currentUserId!,
              initialPitcherUserId: event.pitcherUserId,
            )
          : BatterGameScreen(
              gameMode: widget.gameMode,
              matchSessionId: widget.matchSessionId,
              setupNumbers: widget.setupNumbers,
              handCards: event.cardInfos,
              currentUserId: _currentUserId!,
              initialPitcherUserId: event.pitcherUserId,
            ),
      transitionsBuilder: (_, anim, _c, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  void _onInitialDeal(List<CardInfo> cards) {
    if (!mounted || cards.isEmpty) return;

    _dealCtrl.dispose();
    _dealCtrl = AnimationController(
      vsync: this,
      duration: _staggeredDuration(cards.length),
    );

    setState(() {
      _cards = cards;
      _phase = _Phase.dealing;
    });

    _runDealSequence(_dealCtrl);
  }

  // ── Duration helpers ──────────────────────────────────────────────────────

  static Duration _staggeredDuration(int n) =>
      Duration(milliseconds: (n - 1) * 130 + 560);

  Animation<double> _dealInterval(int i, AnimationController ctrl) {
    final totalMs =
        _staggeredDuration(_cards.length).inMilliseconds.toDouble();
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

  void _toggleSelect(int id) {
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
        if (_selectedIds.contains(_cards[i].cardId)) i,
    };

    // 교체 전 패 저장
    final previousCards = List<CardInfo>.from(_cards);

    // ── 1단계: 수집 애니메이션 ───────────────────────────────────────────
    setState(() => _phase = _Phase.collecting);
    await _collectCtrl.forward(from: 0);
    if (!mounted) return;

    // ── 2단계: 셔플 + WebSocket 요청 동시 진행 ───────────────────────────
    setState(() => _phase = _Phase.shuffling);
    _shuffleCtrl.repeat();

    _mulliganCompleter = Completer<CardHandEvent>();
    final sent = _ws.sendMulligan(
      matchSessionId: widget.matchSessionId,
      cardIdsToSwap: _selectedIds.toList(),
    );

    List<CardInfo> newCards = _cards;
    if (sent) {
      try {
        final event = await _mulliganCompleter!.future
            .timeout(const Duration(seconds: 15));
        newCards = event.cardInfos;
      } catch (_) {
        if (mounted) _showSnackBar('교체 응답 시간 초과. 기존 패를 유지합니다.', isError: true);
      }
    } else {
      if (mounted) _showSnackBar('전송 실패. 기존 패를 유지합니다.', isError: true);
    }
    _mulliganCompleter = null;

    if (!mounted) return;
    _shuffleCtrl.stop();
    _shuffleCtrl.reset();
    _collectCtrl.reset();

    // ── 새 카드 매핑: 교체된 인덱스에만 새 카드 적용 ──────────────────────
    final updatedCards = List<CardInfo>.from(_cards);
    if (newCards.length == _cards.length) {
      for (final i in _replacingIndices) {
        updatedCards[i] = newCards[i];
      }
    } else {
      // 카드 수가 달라졌을 경우 전체 교체
      updatedCards
        ..clear()
        ..addAll(newCards);
    }

    setState(() {
      _originalCards = previousCards;
      _cards = updatedCards;
      _selectedIds.clear();
      _hasReplaced = true;
      _phase = _Phase.redealing;
    });

    // ── 3단계: 재딜 애니메이션 ───────────────────────────────────────────
    final redealCtrl = AnimationController(
      vsync: this,
      duration: _staggeredDuration(_replacingIndices.length.clamp(1, 99)),
    );
    await redealCtrl.forward(from: 0);
    redealCtrl.dispose();

    if (mounted) setState(() => _phase = _Phase.idle);
  }

  void _onConfirm() {
    if (_phase != _Phase.idle || _isConfirming) return;
    setState(() => _isConfirming = true);

    final sent = _ws.sendMulligan(
      matchSessionId: widget.matchSessionId,
      cardIdsToSwap: const [],
    );

    if (!sent) {
      setState(() => _isConfirming = false);
      _showSnackBar('서버 전송 실패. 다시 시도해주세요.', isError: true);
      return;
    }
    // 이후 _handleCardHandEvent / _handleAllReady에서 allMulliganReady=true 수신 시 화면 전환
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor:
            isError ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
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
              if (widget.setupNumbers.isNotEmpty) _buildSetupSummary(),
              Expanded(
                child: _phase == _Phase.waiting
                    ? _buildWaitingState()
                    : _buildCardsArea(),
              ),
              _buildBottomButtons(),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Setup summary bar ─────────────────────────────────────────────────────

  static const _kSetupColors = {
    '아웃': Color(0xFF9E9E9E),
    '병살': Color(0xFFBB66FF),
    '3루타': Color(0xFF448AFF),
    '홈런': Color(0xFFFF5252),
  };

  Widget _buildSetupSummary() {
    final entries = widget.setupNumbers.entries.toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 12, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              children: entries.map((e) {
                final color =
                    _kSetupColors[e.key] ?? Colors.white;
                final nums = e.value.join(' · ');
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${e.key} ',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: nums,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting state ─────────────────────────────────────────────────────────

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFFFFD700),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '카드를 받는 중...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
            ),
          ),
        ],
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
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black87)
                  ],
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
    // 교체 완료 후: 교체 전/후 2행 비교 레이아웃
    if (_hasReplaced && _originalCards != null && _phase == _Phase.idle) {
      return _buildComparisonLayout();
    }

    return Column(
      children: [
        _buildDeckOverlay(),
        const SizedBox(height: 8),
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

  // ── Before / after comparison layout ─────────────────────────────────────

  Widget _buildComparisonLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // ── 교체 전 ────────────────────────────────────────────────────
          _buildComparisonLabel('교체 전', Colors.white.withValues(alpha: 0.40)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _originalCards!.length; i++) ...[
                  Opacity(
                    opacity: 0.45,
                    child: _SmallCardWidget(
                      card: _originalCards![i],
                      isReplaced: _replacingIndices.contains(i),
                    ),
                  ),
                  if (i < _originalCards!.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          // ── 화살표 ─────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white24, thickness: 0.6)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.keyboard_double_arrow_down_rounded,
                      color: Color(0xFFFFD700), size: 22),
                ),
                Expanded(child: Divider(color: Colors.white24, thickness: 0.6)),
              ],
            ),
          ),
          // ── 교체 후 ────────────────────────────────────────────────────
          _buildComparisonLabel('교체 후', const Color(0xFF7CFC00)),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
      ),
    );
  }

  Widget _buildComparisonLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
      ),
    );
  }

  // ── Deck overlay ──────────────────────────────────────────────────────────

  Widget _buildDeckOverlay() {
    final visible = _phase != _Phase.idle && _phase != _Phase.waiting;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: visible ? 90 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
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
                shadows: const [
                  Shadow(blurRadius: 4, color: Colors.black87)
                ],
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
    final isSelected = _selectedIds.contains(card.cardId);
    final isReplacing = _replacingIndices.contains(i);
    final canInteract = _phase == _Phase.idle && !_hasReplaced;

    // 최초 딜 애니메이션
    if (_phase == _Phase.dealing) {
      final anim = _dealInterval(i, _dealCtrl);
      return _withDealTransform(
        anim: anim,
        direction: i.isEven ? 1 : -1,
        child: _PitchCardWidget(card: card, isSelected: false, onTap: null),
      );
    }

    // 수집 애니메이션 (선택된 카드만)
    if (_phase == _Phase.collecting && isReplacing) {
      return AnimatedBuilder(
        animation: _collectCtrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -180.0 * _collectCtrl.value),
          child: Transform.scale(
            scale: 1.0 - _collectCtrl.value * 0.6,
            child:
                Opacity(opacity: 1.0 - _collectCtrl.value, child: child),
          ),
        ),
        child: _PitchCardWidget(card: card, isSelected: true, onTap: null),
      );
    }

    // 셔플 중: 교체 슬롯은 빈 자리
    if ((_phase == _Phase.shuffling || _phase == _Phase.collecting) &&
        isReplacing) {
      return _CardPlaceholder(width: _kCardW, height: _kCardH);
    }

    // 재딜 애니메이션 (교체된 카드만)
    if (_phase == _Phase.redealing && isReplacing) {
      final localIdx = _replacingIndices
          .toList()
          .indexOf(i)
          .clamp(0, _replacingIndices.length - 1);
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
            child:
                _PitchCardWidget(card: card, isSelected: false, onTap: null),
          );
        },
      );
    }

    // 기본 상태
    return _PitchCardWidget(
      card: card,
      isSelected: isSelected,
      onTap: canInteract ? () => _toggleSelect(card.cardId) : null,
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
    final canReplace = _selectedIds.isNotEmpty &&
        !_hasReplaced &&
        _phase == _Phase.idle &&
        !_isConfirming;
    final isAnimating =
        _phase != _Phase.idle && _phase != _Phase.waiting;
    final canConfirm =
        _phase == _Phase.idle && !isAnimating && !_isConfirming;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          // ── 교체 버튼 ────────────────────────────────────────────────
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
                            color: const Color(0xFF1565C0)
                                .withValues(alpha: 0.40),
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
                              color: Colors.white54, strokeWidth: 2),
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
          // ── 확정 버튼 ────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: (canConfirm && !_isConfirming) ? _onConfirm : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 54,
                decoration: BoxDecoration(
                  gradient: canConfirm
                      ? const LinearGradient(
                          colors: [Color(0xFF8AFF2A), Color(0xFF4CAF50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: canConfirm
                      ? null
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: canConfirm
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: canConfirm
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7CFC00)
                                .withValues(alpha: 0.38),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: _isConfirming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          '확정',
                          style: TextStyle(
                            color: canConfirm
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
  final CardInfo card;
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
              top: 0, left: 0, right: 0,
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
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black54)
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // 방향 화살표 (크게)
                  Center(
                    child: Text(
                      card.directionArrow,
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
                  _StatRow(label: '방향', value: card.directionArrow),
                  const SizedBox(height: 3),
                  _StatRow(label: '변화', value: '${card.changeAmount}'),
                  const SizedBox(height: 3),
                  _StatRow(
                    label: '타이밍',
                    value: card.timingLabel,
                    valueColor: card.timingColor,
                  ),
                ],
              ),
            ),
            // 선택 체크 뱃지
            if (isSelected)
              Positioned(
                top: 8, right: 8,
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

// ─── Small card (교체 전 표시용) ──────────────────────────────────────────────

class _SmallCardWidget extends StatelessWidget {
  final CardInfo card;
  final bool isReplaced;

  const _SmallCardWidget({required this.card, required this.isReplaced});

  static const double _w = 72.0;
  static const double _h = 106.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: const Color(0xFF12122A).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isReplaced
                  ? const Color(0xFFFF5252).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.14),
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: card.timingColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 10, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Center(
                      child: Text(
                        card.directionArrow,
                        style: TextStyle(
                          color: card.timingColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('변화',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.40),
                                fontSize: 8)),
                        Text('${card.changeAmount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('타이밍',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.40),
                                fontSize: 8)),
                        Text(card.timingLabel,
                            style: TextStyle(
                                color: card.timingColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 교체된 카드 X 표시
        if (isReplaced)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.close_rounded,
                    color: Color(0xFFFF5252), size: 20),
              ),
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
        ),
      ),
    );
  }
}
