import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../models/card_info.dart';
import '../models/coordinate_card.dart';
import '../models/game_mode.dart';
import '../models/pitcher_ready_event.dart';
import '../models/turn_result_event.dart';
import '../services/game_flow_controller.dart';
import '../services/game_websocket_service.dart';
import '../services/token_storage.dart';
import '../widgets/match_info_overlay.dart';
import '../widgets/mode_background.dart';

// ─── Timing slots ─────────────────────────────────────────────────────────────

enum _Timing {
  TOO_EARLY('너무\n이른', 'TOO_EARLY', Color(0xFF7B68EE)),
  EARLY('이른', 'EARLY', Color(0xFF4CAF50)),
  NORMAL('보통', 'NORMAL', Color(0xFFFFB300)),
  LATE('늦은', 'LATE', Color(0xFFFF7043)),
  TOO_LATE('너무\n늦은', 'TOO_LATE', Color(0xFFEF5350));

  final String label;
  final String requestValue;
  final Color color;
  const _Timing(this.label, this.requestValue, this.color);
}

// ─── Setup category colors ────────────────────────────────────────────────────

const _kSetupColors = {
  '아웃': Color(0xFF9E9E9E),
  '병살': Color(0xFFBB66FF),
  '3루타': Color(0xFF448AFF),
  '홈런': Color(0xFFFF5252),
};

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTimerMax = 5.0; // seconds

// ─── Screen ───────────────────────────────────────────────────────────────────

class BatterGameScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;
  final Map<String, List<int>> setupNumbers;
  final List<CardInfo> handCards;
  final int currentUserId;
  final int initialPitcherUserId;
  final TurnResultEvent? lastResultEvent;

  const BatterGameScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    required this.handCards,
    required this.currentUserId,
    required this.initialPitcherUserId,
    this.setupNumbers = const {},
    this.lastResultEvent,
  });

  @override
  State<BatterGameScreen> createState() => _BatterGameScreenState();
}

enum _BatterPhase { waiting, active, submitted }

class _BatterGameScreenState extends State<BatterGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Coordinate cards ──────────────────────────────────────────────────────
  List<CoordinateCard> _coordCards = [];
  bool _loadingCoords = true;
  String? _coordError;

  // ── Game state ────────────────────────────────────────────────────────────
  _BatterPhase _phase = _BatterPhase.waiting;
  int? _pitcherStartCoord; // from PitcherReadyEvent
  DateTime? _pitcherReadyAt; // timestamp for responseTimeSec calculation

  // ── Selection state ───────────────────────────────────────────────────────
  int? _selectedCoordNum;      // 0~25
  _Timing? _selectedTiming;

  // ── Timer ─────────────────────────────────────────────────────────────────
  double _remainingSec = _kTimerMax;
  Timer? _countdownTimer;

  // ── Animation for timer pulse ─────────────────────────────────────────────
  late final AnimationController _pulseCtrl;

  TurnResultEvent? _lastResult;

  final _ws = GameWebSocketService.instance;
  final _tokenStorage = TokenStorage();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _lastResult = widget.lastResultEvent;
    GameFlowController.instance.updateSession(GameSessionContext(
      gameMode: widget.gameMode,
      matchSessionId: widget.matchSessionId,
      setupNumbers: widget.setupNumbers,
      currentUserId: widget.currentUserId,
      initialPitcherUserId: widget.initialPitcherUserId,
      handCards: widget.handCards,
    ));
    _fetchCoordinateCards();
    _subscribeToGameTopic();
    _ws.refreshResultTopicSubscription(widget.matchSessionId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── WebSocket subscription ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ws.refreshConnectionAndSubscriptions();
      GameFlowController.instance.refreshSubscriptions();
    }
  }

  void _subscribeToGameTopic() {
    // widget.currentUserId는 PitchSelectionScreen에서 전달받은 값
    _ws.subscribeGameTopic(
      matchSessionId: widget.matchSessionId,
      currentUserId: widget.currentUserId,
      onEvent: (_) {},
      onAllReady: (_) {},
      onPitcherReady: _onPitcherReady,
    );
  }

  void _onPitcherReady(PitcherReadyEvent event) {
    if (!mounted || _phase != _BatterPhase.waiting) return;
    setState(() {
      _pitcherStartCoord = event.startCoordinateNumber;
      _pitcherReadyAt = DateTime.now();
      _remainingSec = _kTimerMax;
      _phase = _BatterPhase.active;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now()
              .difference(_pitcherReadyAt!)
              .inMilliseconds /
          1000.0;
      final remaining = _kTimerMax - elapsed;

      if (remaining <= 0) {
        t.cancel();
        // 시간 초과 시 자동 제출 (스윙 미발동)
        _submitBatterSelect(forceSubmit: true);
      } else {
        setState(() => _remainingSec = remaining);
      }
    });
  }

  // ── API: coordinate cards prefetch ────────────────────────────────────────

  Future<void> _fetchCoordinateCards() async {
    setState(() {
      _loadingCoords = true;
      _coordError = null;
    });
    try {
      final token = await _tokenStorage.getAccessToken();
      final dio = ApiClient().dio;
      final resp = await dio.get(
        '/api/v1/cards/coordinate',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (resp.statusCode == 200) {
        final list = (resp.data as List<dynamic>)
            .map((e) => CoordinateCard.fromJson(e as Map<String, dynamic>))
            .toList();
        // 타자는 0번(폭투존) 포함 전체 사용
        if (mounted) setState(() => _coordCards = list);
      } else {
        if (mounted) {
          setState(() => _coordError = '좌표 카드 로드 실패 (${resp.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _coordError = '네트워크 오류: $e');
    } finally {
      if (mounted) setState(() => _loadingCoords = false);
    }
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  bool get _canSwing =>
      _selectedCoordNum != null &&
      _selectedTiming != null &&
      _phase == _BatterPhase.active;

  void _onCoordTap(int coordNum) {
    if (_phase != _BatterPhase.active) return;
    setState(() {
      _selectedCoordNum = _selectedCoordNum == coordNum ? null : coordNum;
    });
  }

  void _onTimingTap(_Timing timing) {
    if (_phase != _BatterPhase.active) return;
    setState(() {
      _selectedTiming =
          _selectedTiming == timing ? null : timing;
    });
  }

  Future<void> _submitBatterSelect({bool forceSubmit = false}) async {
    if (_phase != _BatterPhase.active) return;
    if (!forceSubmit && !_canSwing) return;

    _countdownTimer?.cancel();

    final elapsed = _pitcherReadyAt == null
        ? _kTimerMax
        : DateTime.now()
                .difference(_pitcherReadyAt!)
                .inMilliseconds /
            1000.0;

    final coordNum = _selectedCoordNum ?? 0;
    final timing = _selectedTiming?.requestValue ?? 'NORMAL';

    setState(() => _phase = _BatterPhase.submitted);

    final sent = _ws.sendBatterSelectCard(
      matchSessionId: widget.matchSessionId,
      responseTimeSec: elapsed.clamp(0.0, _kTimerMax + 1),
      batterCoordinateNumber: coordNum,
      timing: timing,
    );

    if (!sent && mounted) {
      setState(() => _phase = _BatterPhase.active);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('서버 전송 실패. 다시 시도해주세요.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          ModeBackground(mode: widget.gameMode),
          SafeArea(
            child: Column(children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildHeader()),
                  MatchInfoOverlay(
                    currentUserId: widget.currentUserId,
                    initialPitcherUserId: widget.initialPitcherUserId,
                    lastResult: _lastResult,
                  ),
                ],
              ),
              if (widget.setupNumbers.isNotEmpty) _buildSetupSummary(),
              _buildPitcherInfoBar(),
              _buildSelectionDisplay(),
              _buildTimerBar(),
              Expanded(child: _buildCoordGridArea()),
              _buildTimingSlots(),
              _buildBottomBar(),
              const SizedBox(height: 12),
            ]),
          ),
          if (_phase == _BatterPhase.waiting) _buildWaitingOverlay(),
          if (_phase == _BatterPhase.submitted) _buildSubmittedOverlay(),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(children: [
        const Text(
          '타격',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF448AFF).withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.45)),
          ),
          child: const Text(
            '타자',
            style: TextStyle(
              color: Color(0xFF90CAFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Setup summary ─────────────────────────────────────────────────────────

  Widget _buildSetupSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          children: widget.setupNumbers.entries.map((e) {
            final color = _kSetupColors[e.key] ?? Colors.white;
            return RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: '${e.key} ',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: e.value.join('·'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Pitcher info bar ──────────────────────────────────────────────────────

  Widget _buildPitcherInfoBar() {
    final hasInfo = _pitcherStartCoord != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: hasInfo
            ? const Color(0xFFFF5722).withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasInfo
              ? const Color(0xFFFF5722).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_baseball_rounded,
            size: 14,
            color: hasInfo
                ? const Color(0xFFFF8A65)
                : Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),
          Text(
            hasInfo ? '투수 시작 좌표 :  $_pitcherStartCoord번' : '투수 대기 중...',
            style: TextStyle(
              color: hasInfo
                  ? Colors.white.withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
              fontWeight: hasInfo ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Selection display ─────────────────────────────────────────────────────

  Widget _buildSelectionDisplay() {
    final hasCoord = _selectedCoordNum != null;
    final hasTiming = _selectedTiming != null;
    final hasAny = hasCoord || hasTiming;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: hasAny
            ? Colors.black.withValues(alpha: 0.50)
            : Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasAny
              ? const Color(0xFF448AFF).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 좌표
          _chip(
            icon: Icons.location_on_rounded,
            label: hasCoord
                ? (_selectedCoordNum == 0 ? '0 폭투' : '$_selectedCoordNum번')
                : '좌표 ─',
            color: hasCoord
                ? const Color(0xFF7CFC00)
                : Colors.white.withValues(alpha: 0.25),
            active: hasCoord,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('·',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 18)),
          ),
          // 타이밍
          _chip(
            icon: Icons.timer_rounded,
            label: hasTiming ? _selectedTiming!.label.replaceAll('\n', ' ') : '타이밍 ─',
            color: hasTiming
                ? _selectedTiming!.color
                : Colors.white.withValues(alpha: 0.25),
            active: hasTiming,
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required bool active,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.30),
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Timer bar ─────────────────────────────────────────────────────────────

  Widget _buildTimerBar() {
    final isActive = _phase == _BatterPhase.active;
    final ratio = (_remainingSec / _kTimerMax).clamp(0.0, 1.0);
    final isUrgent = _remainingSec < 2.0;

    final barColor = isUrgent ? const Color(0xFFFF5252) : const Color(0xFF448AFF);

    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (ctx, child) {
                    final opacity = isUrgent
                        ? 0.6 + _pulseCtrl.value * 0.4
                        : 1.0;
                    return Opacity(
                      opacity: opacity,
                      child: Text(
                        '${_remainingSec.toStringAsFixed(1)}초',
                        style: TextStyle(
                          color: isUrgent
                              ? const Color(0xFFFF5252)
                              : Colors.white.withValues(alpha: 0.85),
                          fontSize: isUrgent ? 16 : 14,
                          fontWeight: FontWeight.w800,
                          shadows: isUrgent
                              ? const [
                                  Shadow(
                                    color: Color(0xFFFF5252),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                Text(
                  isUrgent ? '서둘러!' : '타이밍을 선택하세요',
                  style: TextStyle(
                    color: isUrgent
                        ? const Color(0xFFFF8A65)
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(
                  height: 5,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 100),
                  widthFactor: ratio,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor, barColor.withValues(alpha: 0.70)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.50),
                          blurRadius: 6,
                        )
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Coordinate grid area ──────────────────────────────────────────────────

  Widget _buildCoordGridArea() {
    if (_loadingCoords) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white70, strokeWidth: 2.5),
            ),
            SizedBox(height: 12),
            Text('좌표 로딩 중...',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    if (_coordError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_coordError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchCoordinateCards,
              child: const Text('다시 시도',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // 0번 폭투존 분리
    final zeroCard = _coordCards
        .where((c) => c.coordinateNumber == 0)
        .firstOrNull;
    final mainCards = _coordCards
        .where((c) => c.coordinateNumber > 0)
        .toList()
      ..sort((a, b) => a.coordinateNumber.compareTo(b.coordinateNumber));

    const hPad = 10.0;
    const gap = 4.0;
    const cols = 5;
    const rows = 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(hPad, 4, hPad, 2),
      child: Column(
        children: [
          if (zeroCard != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildWildCell(zeroCard),
            ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final cellW =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;
              final cellH =
                  (constraints.maxHeight - gap * (rows - 1)) / rows;
              final aspect = cellW / cellH;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: aspect > 0 ? aspect : 3 / 4,
                ),
                itemCount: mainCards.length,
                itemBuilder: (_, i) => _buildCoordCell(mainCards[i]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWildCell(CoordinateCard coord) {
    final isSelected = _selectedCoordNum == 0;
    final isActive = _phase == _BatterPhase.active;

    return GestureDetector(
      onTap: isActive ? () => _onCoordTap(0) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5252).withValues(alpha: 0.28)
              : const Color(0xFFFF5252).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF5252)
                : const Color(0xFFFF5252).withValues(alpha: 0.35),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 13,
                color: isSelected
                    ? const Color(0xFFFF5252)
                    : const Color(0xFFFF5252).withValues(alpha: 0.60),
              ),
              const SizedBox(width: 6),
              Text(
                '0  ·  폭투 존',
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFF5252)
                      : const Color(0xFFFF8A80),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordCell(CoordinateCard coord) {
    final isStrike = coord.isStrike;
    final isSelected = _selectedCoordNum == coord.coordinateNumber;
    final isActive = _phase == _BatterPhase.active;

    return GestureDetector(
      onTap: isActive ? () => _onCoordTap(coord.coordinateNumber) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF448AFF).withValues(alpha: 0.28)
              : (isStrike
                  ? const Color(0xFF7CFC00).withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF448AFF)
                : (isStrike
                    ? const Color(0xFF7CFC00).withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.15)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF448AFF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${coord.coordinateNumber}',
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF90CAFF)
                      : (isStrike
                          ? const Color(0xFF7CFC00)
                          : Colors.white.withValues(
                              alpha: isActive ? 0.75 : 0.30)),
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              if (isStrike && !isSelected)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7CFC00),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Timing slots ──────────────────────────────────────────────────────────

  Widget _buildTimingSlots() {
    final isActive = _phase == _BatterPhase.active;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: _Timing.values.map((t) {
          final isSelected = _selectedTiming == t;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: isActive ? () => _onTimingTap(t) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  height: 68,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? t.color.withValues(alpha: 0.25)
                        : (isActive
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? t.color
                          : (isActive
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.08)),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: t.color.withValues(alpha: 0.40),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 컬러 상단 띠
                      Container(
                        width: 24,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? t.color
                              : t.color.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        t.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isActive
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.20)),
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _canSwing ? () => _submitBatterSelect() : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: _canSwing
                    ? const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _canSwing
                    ? null
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _canSwing
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: _canSwing
                    ? [
                        BoxShadow(
                          color: const Color(0xFF42A5F5)
                              .withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports_baseball_rounded,
                      color: _canSwing
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.28),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '타격',
                      style: TextStyle(
                        color: _canSwing
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.28),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Overlays ──────────────────────────────────────────────────────────────

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D20).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Color(0xFF448AFF),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '투구를 준비하고 있습니다',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '투수가 구종을 선택하면 타격이 시작됩니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmittedOverlay() {
    final coordNum = _selectedCoordNum;
    final timing = _selectedTiming;

    return Container(
      color: Colors.black.withValues(alpha: 0.60),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D20).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF448AFF).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_baseball_rounded,
                      color: Color(0xFF90CAFF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    coordNum != null
                        ? '${coordNum == 0 ? '폭투' : '$coordNum번'}  ·  ${timing?.label.replaceAll('\n', ' ') ?? '-'}'
                        : '타격 완료',
                    style: const TextStyle(
                      color: Color(0xFF90CAFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '타격 완료',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2.5),
              ),
              const SizedBox(height: 14),
              Text(
                '결과 계산 중...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
