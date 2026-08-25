import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../models/card_info.dart';
import '../models/coordinate_card.dart';
import '../models/double_judgment_config.dart';
import '../models/game_mode.dart';
import '../models/pitcher_ready_event.dart';
import '../models/turn_result_event.dart';
import '../services/game_flow_controller.dart';
import '../services/game_match_meta_service.dart';
import '../services/game_websocket_service.dart';
import '../services/token_storage.dart';
import '../utils/api_error_ui.dart';
import '../widgets/match_info_overlay.dart';
import '../widgets/opponent_disconnected_overlay.dart';
import '../widgets/mode_background.dart';
import '../widgets/setup_numbers_summary.dart';

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

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTimerMax = 5.0; // seconds
const _kPitcherStartColor = Color(0xFFBB66FF);

// ─── Screen ───────────────────────────────────────────────────────────────────

class BatterGameScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;
  final Map<String, List<int>> setupNumbers;
  final DoubleJudgmentConfig? doubleJudgment;
  final List<CardInfo> handCards;
  final int currentUserId;
  final int initialPitcherUserId;
  final TurnResultEvent? lastResultEvent;

  /// 재접속 시 서버 turn.startCoordinateNumber (BATTER_SELECT phase).
  final int? restoredStartCoordinateNumber;

  const BatterGameScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    required this.handCards,
    required this.currentUserId,
    required this.initialPitcherUserId,
    this.setupNumbers = const {},
    this.doubleJudgment,
    this.lastResultEvent,
    this.restoredStartCoordinateNumber,
  });

  @override
  State<BatterGameScreen> createState() => _BatterGameScreenState();
}

enum _BatterPhase { waiting, active, submitted }

class _BatterGameScreenState extends State<BatterGameScreen>
    with WidgetsBindingObserver {
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

  TurnResultEvent? _lastResult;
  DoubleJudgmentConfig? _doubleJudgment;

  final _ws = GameWebSocketService.instance;
  final _tokenStorage = TokenStorage();
  final _metaService = GameMatchMetaService();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _lastResult = widget.lastResultEvent;
    _doubleJudgment = widget.doubleJudgment;
    _syncSession();
    if (_doubleJudgment == null) _loadDoubleJudgment();
    _fetchCoordinateCards();
    _subscribeToGameTopic();
    _ws.bootstrapMatchSession(widget.matchSessionId);
    _restoreBatterTurnIfNeeded();
  }

  void _restoreBatterTurnIfNeeded() {
    final startCoord = widget.restoredStartCoordinateNumber;
    if (startCoord == null || startCoord <= 0) return;
    _pitcherStartCoord = startCoord;
    _pitcherReadyAt = DateTime.now();
    _remainingSec = _kTimerMax;
    _phase = _BatterPhase.active;
    _startCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
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

  void _syncSession() {
    GameFlowController.instance.updateSession(GameSessionContext(
      gameMode: widget.gameMode,
      matchSessionId: widget.matchSessionId,
      setupNumbers: widget.setupNumbers,
      doubleJudgment: _doubleJudgment,
      currentUserId: widget.currentUserId,
      initialPitcherUserId: widget.initialPitcherUserId,
      handCards: widget.handCards,
    ));
  }

  Future<void> _loadDoubleJudgment() async {
    final config =
        await _metaService.fetchDoubleJudgment(widget.matchSessionId);
    if (!mounted || config == null) return;
    setState(() => _doubleJudgment = config);
    _syncSession();
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

  bool get _isSelectionComplete =>
      _selectedCoordNum != null && _selectedTiming != null;

  void _onTimingTap(_Timing timing) {
    if (_phase != _BatterPhase.active) return;
    setState(() {
      if (_selectedTiming == timing) {
        _selectedTiming = null;
        _selectedCoordNum = null;
      } else {
        _selectedTiming = timing;
        _selectedCoordNum = null;
      }
    });
  }

  void _onCoordPlaced(int coordNum, _Timing timing) {
    if (_phase != _BatterPhase.active) return;
    setState(() {
      _selectedCoordNum = coordNum;
      _selectedTiming = timing;
    });
    _submitBatterSelect();
  }

  void _onWildPitchTap() {
    if (_phase != _BatterPhase.active) return;
    setState(() {
      _selectedCoordNum = 0;
      _selectedTiming = _Timing.NORMAL;
    });
    _submitBatterSelect();
  }

  void _onTimingDropped(_Timing timing, int coordNum) {
    _onCoordPlaced(coordNum, timing);
  }

  Future<void> _submitBatterSelect({bool forceSubmit = false}) async {
    if (_phase != _BatterPhase.active) return;
    if (!forceSubmit && !_isSelectionComplete) return;

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
      showErrorDialog(context, '서버 전송 실패. 다시 시도해주세요.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: InGamePresenceShell(
          matchSessionId: widget.matchSessionId,
          gameMode: widget.gameMode,
          child: Stack(children: [
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
              if (widget.setupNumbers.isNotEmpty || _doubleJudgment != null)
                SetupNumbersSummaryBar(
                  setupNumbers: widget.setupNumbers,
                  doubleJudgment: _doubleJudgment,
                ),
              _buildPitcherInfoBar(),
              _buildSelectionDisplay(),
              _buildTimerBar(),
              Expanded(child: _buildCoordGridArea()),
              _buildTimingHandArea(),
              const SizedBox(height: 12),
            ]),
          ),
          if (_phase == _BatterPhase.waiting) _buildWaitingOverlay(),
          if (_phase == _BatterPhase.submitted) _buildSubmittedOverlay(),
        ]),
        ),
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

  // ── Pitcher info bar ──────────────────────────────────────────────────────

  Widget _buildPitcherInfoBar() {
    final hasInfo = _pitcherStartCoord != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: hasInfo
            ? _kPitcherStartColor.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasInfo
              ? _kPitcherStartColor.withValues(alpha: 0.55)
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
                ? _kPitcherStartColor
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
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
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
                  child: Text(
                    '${_remainingSec.toStringAsFixed(1)}초',
                  ),
                ),
                Text(
                  isUrgent ? '서둘러!' : '타이밍 카드를 좌표에 놓으세요',
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
    final isPitcherStart = _pitcherStartCoord == 0;
    final isActive = _phase == _BatterPhase.active;

    return GestureDetector(
      onTap: isActive ? _onWildPitchTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5252).withValues(alpha: 0.28)
              : isPitcherStart
                  ? _kPitcherStartColor.withValues(alpha: 0.38)
                  : const Color(0xFFFF5252).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF5252)
                : isPitcherStart
                    ? _kPitcherStartColor
                    : const Color(0xFFFF5252).withValues(alpha: 0.35),
            width: isSelected || isPitcherStart ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 8,
                  )
                ]
              : isPitcherStart
                  ? [
                      BoxShadow(
                        color: _kPitcherStartColor.withValues(alpha: 0.40),
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
    final isPitcherStart = _pitcherStartCoord == coord.coordinateNumber;
    final isActive = _phase == _BatterPhase.active;
    final placedTiming = isSelected ? _selectedTiming : null;

    return DragTarget<_Timing>(
      onWillAcceptWithDetails: (_) => isActive,
      onAcceptWithDetails: (d) =>
          _onTimingDropped(d.data, coord.coordinateNumber),
      builder: (ctx, candidates, rejected) {
        final hover = candidates.isNotEmpty;
        final bgColor = isSelected
            ? const Color(0xFF448AFF).withValues(alpha: 0.28)
            : isPitcherStart
                ? _kPitcherStartColor.withValues(alpha: 0.38)
                : hover
                    ? Colors.white.withValues(alpha: 0.22)
                    : (isStrike
                        ? const Color(0xFF7CFC00).withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.05));
        final borderColor = isSelected
            ? const Color(0xFF448AFF)
            : isPitcherStart
                ? _kPitcherStartColor
                : hover
                    ? Colors.white.withValues(alpha: 0.70)
                    : (isStrike
                        ? const Color(0xFF7CFC00).withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.15));

        return GestureDetector(
          onTap: isActive && _selectedTiming != null
              ? () => _onCoordPlaced(coord.coordinateNumber, _selectedTiming!)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: borderColor,
                width: isSelected || hover || isPitcherStart ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF448AFF).withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : isPitcherStart
                      ? [
                          BoxShadow(
                            color: _kPitcherStartColor.withValues(alpha: 0.42),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (placedTiming != null)
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: _TimingCardMini(timing: placedTiming),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${coord.coordinateNumber}',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF90CAFF)
                              : isPitcherStart
                                  ? Colors.white
                                  : (isStrike
                                      ? const Color(0xFF7CFC00)
                                      : Colors.white.withValues(
                                          alpha: isActive ? 0.75 : 0.30)),
                          fontSize: 13,
                          fontWeight: isSelected || isPitcherStart
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                      if (isPitcherStart && !isSelected)
                        Text(
                          '시작',
                          style: TextStyle(
                            color: _kPitcherStartColor.withValues(alpha: 0.95),
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        )
                      else if (isStrike && !isSelected)
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
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Timing hand (구종 카드와 동일한 드래그 방식) ───────────────────────────

  Widget _buildTimingHandArea() {
    if (_phase != _BatterPhase.active) {
      return const SizedBox(height: 130);
    }

    const timings = _Timing.values;
    const cardW = 76.0;
    const cardH = 108.0;
    const spread = 52.0;
    const areaH = 138.0;
    final n = timings.length;
    final totalW = (n - 1) * spread + cardW;

    return SizedBox(
      height: areaH,
      child: LayoutBuilder(builder: (context, constraints) {
        final sx = constraints.maxWidth / 2 - totalW / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < n; i++)
              _buildTimingHandCard(
                i,
                n,
                timings[i],
                sx + i * spread,
                cardW,
                cardH,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildTimingHandCard(
    int i,
    int total,
    _Timing timing,
    double left,
    double cardW,
    double cardH,
  ) {
    final mid = (total - 1) / 2.0;
    final t = i - mid;
    final isSelected = _selectedTiming == timing;
    final isPlaced = isSelected && _selectedCoordNum != null;
    final cardOpacity = isSelected && !isPlaced ? 0.50 : 1.0;

    return Positioned(
      left: left,
      bottom: t.abs() * 5.0 + (isSelected ? 22.0 : 0.0),
      child: Transform.rotate(
        angle: t * 0.07,
        alignment: Alignment.bottomCenter,
        child: Draggable<_Timing>(
          data: timing,
          onDragStarted: () => setState(() {
            _selectedTiming = timing;
            _selectedCoordNum = null;
          }),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.48,
              child: Transform.scale(
                scale: 1.08,
                child: _TimingCardWidget(
                  timing: timing,
                  isSelected: true,
                  w: cardW,
                  h: cardH,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.28,
            child: _TimingCardWidget(
              timing: timing,
              isSelected: false,
              w: cardW,
              h: cardH,
            ),
          ),
          child: GestureDetector(
            onTap: () => _onTimingTap(timing),
            child: _TimingCardWidget(
              timing: timing,
              isSelected: isSelected,
              w: cardW,
              h: cardH,
              opacity: cardOpacity,
            ),
          ),
        ),
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

// ─── Timing card widgets ──────────────────────────────────────────────────────

class _TimingCardWidget extends StatelessWidget {
  final _Timing timing;
  final bool isSelected;
  final double w, h;
  final double opacity;

  const _TimingCardWidget({
    required this.timing,
    required this.isSelected,
    required this.w,
    required this.h,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFF12122A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFFFD700).withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.45),
              blurRadius: isSelected ? 14 : 6,
              spreadRadius: isSelected ? 1 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: timing.color,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 10, 7, 7),
              child: Column(
                children: [
                  Text(
                    '타이밍',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.timer_rounded,
                    color: timing.color,
                    size: 28,
                    shadows: [
                      Shadow(
                        color: timing.color.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timing.label.replaceAll('\n', ' '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      shadows: [
                        Shadow(blurRadius: 3, color: Colors.black54),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 6,
                right: 6,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFD700),
                    ),
                    child: Icon(Icons.check_rounded, color: Colors.black, size: 9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimingCardMini extends StatelessWidget {
  final _Timing timing;

  const _TimingCardMini({required this.timing});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF12122A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: timing.color.withValues(alpha: 0.85), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: timing.color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                timing.label.replaceAll('\n', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: timing.color,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
