import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../models/card_info.dart';
import '../models/coordinate_card.dart';
import '../models/double_judgment_config.dart';
import '../models/game_mode.dart';
import '../models/turn_result_event.dart';
import '../services/game_flow_controller.dart';
import '../services/game_match_meta_service.dart';
import '../services/game_websocket_service.dart';
import '../services/token_storage.dart';
import '../widgets/match_info_overlay.dart';
import '../widgets/opponent_disconnected_overlay.dart';
import '../widgets/mode_background.dart';
import '../widgets/setup_numbers_summary.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class PitcherGameScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;
  final Map<String, List<int>> setupNumbers;
  final DoubleJudgmentConfig? doubleJudgment;
  final List<CardInfo> handCards;
  final int currentUserId;
  final int initialPitcherUserId;
  final TurnResultEvent? lastResultEvent;

  const PitcherGameScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    required this.handCards,
    required this.currentUserId,
    required this.initialPitcherUserId,
    this.setupNumbers = const {},
    this.doubleJudgment,
    this.lastResultEvent,
  });

  @override
  State<PitcherGameScreen> createState() => _PitcherGameScreenState();
}

class _PitcherGameScreenState extends State<PitcherGameScreen>
    with WidgetsBindingObserver {
  // ── Coordinate cards ──────────────────────────────────────────────────────
  List<CoordinateCard> _coordCards = [];
  bool _loadingCoords = true;
  String? _coordError;

  // ── Selection state ───────────────────────────────────────────────────────
  CardInfo? _selectedCard;
  CoordinateCard? _selectedCoord;
  bool _isPitching = false;
  bool _isWaitingBatter = false;

  // ── Match info ────────────────────────────────────────────────────────────
  TurnResultEvent? _lastResult;
  DoubleJudgmentConfig? _doubleJudgment;

  final _ws = GameWebSocketService.instance;
  final _tokenStorage = TokenStorage();
  final _metaService = GameMatchMetaService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastResult = widget.lastResultEvent;
    _doubleJudgment = widget.doubleJudgment;
    _syncSession();
    if (_doubleJudgment == null) _loadDoubleJudgment();
    _subscribeGameTopic();
    _ws.bootstrapMatchSession(widget.matchSessionId);
    _fetchCoordinateCards();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ws.refreshConnectionAndSubscriptions();
      GameFlowController.instance.refreshSubscriptions();
    }
  }

  void _subscribeGameTopic() {
    _ws.subscribeGameTopic(
      matchSessionId: widget.matchSessionId,
      currentUserId: widget.currentUserId,
      onEvent: (_) {},
      onAllReady: (_) {},
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

  // ── Coordinate card prefetch ──────────────────────────────────────────────

  Future<void> _fetchCoordinateCards() async {
    setState(() { _loadingCoords = true; _coordError = null; });
    try {
      final token = await _tokenStorage.getAccessToken();
      final resp = await ApiClient().dio.get(
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
        if (mounted) setState(() => _coordCards = list.where((c) => c.coordinateNumber >= 1).toList());
      } else {
        if (mounted) setState(() => _coordError = '좌표 카드 로드 실패 (${resp.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() => _coordError = '네트워크 오류: $e');
    } finally {
      if (mounted) setState(() => _loadingCoords = false);
    }
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  bool get _canPitch =>
      _selectedCard != null && _selectedCoord != null &&
      !_isPitching && !_isWaitingBatter;

  void _onCardTap(CardInfo card) {
    setState(() {
      if (_selectedCard?.cardId == card.cardId) {
        _selectedCard = null; _selectedCoord = null;
      } else {
        _selectedCard = card;
      }
    });
  }

  void _onCoordTap(CoordinateCard coord) {
    if (_selectedCard == null) return;
    setState(() {
      _selectedCoord = _selectedCoord?.id == coord.id ? null : coord;
    });
  }

  void _onCardDropped(CardInfo card, CoordinateCard coord) {
    setState(() { _selectedCard = card; _selectedCoord = coord; });
  }

  Future<void> _onPitch() async {
    if (!_canPitch) return;
    setState(() => _isPitching = true);
    final sent = _ws.sendPitcherSelectCard(
      matchSessionId: widget.matchSessionId,
      pitchCardId: _selectedCard!.cardId,
      coordinateCardId: _selectedCoord!.id,
    );
    if (!sent && mounted) {
      setState(() => _isPitching = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('서버 전송 실패. 다시 시도해주세요.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (mounted) setState(() { _isPitching = false; _isWaitingBatter = true; });
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
              // ── 상단: 헤더(좌) + 스코어보드(우) ───────────────────────────
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
              _buildPitchDisplay(),
              Expanded(child: _buildCoordGridArea()),
              _buildHandArea(),
              _buildBottomBar(),
              const SizedBox(height: 12),
            ]),
          ),
          if (_isWaitingBatter) _buildWaitingOverlay(),
        ]),
        ),
      ),
    );
  }

  // ── Waiting overlay ───────────────────────────────────────────────────────

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.60),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D20).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 30, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_baseball_rounded, color: Color(0xFFFFD700), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedCard?.name ?? ''}  ·  ${_selectedCoord?.coordinateNumber ?? 0}번'
                    '${_selectedCoord?.isStrike == true ? '  S' : ''}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('투구 완료', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.5),
              ),
              const SizedBox(height: 14),
              Text('타자 선택 대기 중...', style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
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
          '투구',
          style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
            letterSpacing: 0.5, shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text('투수', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Pitch display ─────────────────────────────────────────────────────────

  Widget _buildPitchDisplay() {
    final has = _selectedCard != null || _selectedCoord != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: has ? Colors.black.withValues(alpha: 0.50) : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: has ? const Color(0xFFFFD700).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip(Icons.style_rounded, _selectedCard?.name ?? '─', _selectedCard != null, _selectedCard?.timingColor ?? Colors.white.withValues(alpha: 0.25)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 20, fontWeight: FontWeight.w300)),
          ),
          _chip(Icons.location_on_rounded,
            _selectedCoord != null ? '${_selectedCoord!.coordinateNumber}번' : '─',
            _selectedCoord != null,
            _selectedCoord != null ? (_selectedCoord!.isStrike ? const Color(0xFF7CFC00) : const Color(0xFFFFD700)) : Colors.white.withValues(alpha: 0.25)),
          if (_selectedCoord?.isStrike == true) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF7CFC00).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
              child: const Text('S', style: TextStyle(color: Color(0xFF7CFC00), fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool active, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.30),
        fontSize: active ? 15 : 14, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        shadows: active ? const [Shadow(blurRadius: 6, color: Colors.black54)] : null,
      )),
    ]);
  }

  // ── Coordinate grid area ──────────────────────────────────────────────────

  Widget _buildCoordGridArea() {
    if (_loadingCoords) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5)),
        SizedBox(height: 12),
        Text('좌표 로딩 중...', style: TextStyle(color: Colors.white54, fontSize: 13)),
      ]));
    }
    if (_coordError != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_coordError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        const SizedBox(height: 12),
        TextButton(onPressed: _fetchCoordinateCards, child: const Text('다시 시도', style: TextStyle(color: Colors.white))),
      ]));
    }
    // 투수는 좌표 1~25만 (폭투존 0 제외)
    final cells = _coordCards.where((c) => c.coordinateNumber >= 1).toList()
      ..sort((a, b) => a.coordinateNumber.compareTo(b.coordinateNumber));

    const hPad = 10.0;
    const gap  = 4.0;
    const cols = 5;
    const rows = 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(hPad, 6, hPad, 4),
      // LayoutBuilder로 가용 공간을 정확히 측정해 셀 비율 계산
      child: LayoutBuilder(builder: (context, constraints) {
        final cellW = (constraints.maxWidth  - gap * (cols - 1)) / cols;
        final cellH = (constraints.maxHeight - gap * (rows - 1)) / rows;
        final aspect = cellW / cellH; // 실제 비율 → 스크롤 없이 5×5가 꼭 맞게 들어감

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: aspect > 0 ? aspect : 3 / 4,
          ),
          itemCount: cells.length,
          itemBuilder: (_, i) => _buildCoordCell(cells[i]),
        );
      }),
    );
  }

  Widget _buildCoordCell(CoordinateCard coord) {
    final isStrike  = coord.isStrike;
    final isSelected = _selectedCoord?.id == coord.id && _selectedCoord != null;

    // 색상 팔레트
    const strikeBase  = Color(0xFF00C853); // 스트라이크 존 — 진한 초록
    const ballBase    = Color(0xFF37474F); // 볼 존 — 어두운 청회색
    const selectedCol = Color(0xFFFFD700); // 선택됨 — 골드

    return DragTarget<CardInfo>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onCardDropped(d.data, coord),
      builder: (ctx, candidates, rejected) {
        final hover = candidates.isNotEmpty;
        final bgColor = isSelected
            ? selectedCol.withValues(alpha: 0.30)
            : hover
                ? Colors.white.withValues(alpha: 0.25)
                : isStrike
                    ? strikeBase.withValues(alpha: 0.22) // 스트라이크 존: 더 짙게
                    : ballBase.withValues(alpha: 0.35);  // 볼 존: 어두운 색

        final borderColor = isSelected
            ? selectedCol
            : hover
                ? Colors.white.withValues(alpha: 0.70)
                : isStrike
                    ? strikeBase.withValues(alpha: 0.65)
                    : ballBase.withValues(alpha: 0.45);

        final textColor = isSelected
            ? selectedCol
            : isStrike
                ? strikeBase.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.55);

        return GestureDetector(
          onTap: () => _onCoordTap(coord),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
              boxShadow: isSelected
                  ? [BoxShadow(color: selectedCol.withValues(alpha: 0.40), blurRadius: 8, spreadRadius: 1)]
                  : isStrike
                      ? [BoxShadow(color: strikeBase.withValues(alpha: 0.18), blurRadius: 4)]
                      : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${coord.coordinateNumber}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isStrike ? 'S' : 'B',
                  style: TextStyle(
                    color: isStrike
                        ? strikeBase.withValues(alpha: isSelected ? 0.90 : 0.75)
                        : Colors.white.withValues(alpha: 0.25),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Hand area ─────────────────────────────────────────────────────────────

  Widget _buildHandArea() {
    final cards = widget.handCards;
    final n = cards.length;
    if (n == 0) return const SizedBox(height: 130);
    const double cardW = 76.0, cardH = 108.0, spread = 58.0, areaH = 138.0;
    final double totalW = (n - 1) * spread + cardW;
    return SizedBox(
      height: areaH,
      child: LayoutBuilder(builder: (context, constraints) {
        final double cx = constraints.maxWidth / 2;
        final double sx = cx - totalW / 2;
        return Stack(clipBehavior: Clip.none, children: [
          for (int i = 0; i < n; i++) _buildHandCard(i, n, cards[i], sx + i * spread, cardW, cardH),
        ]);
      }),
    );
  }

  Widget _buildHandCard(int i, int total, CardInfo card, double left, double cardW, double cardH) {
    final double mid = (total - 1) / 2.0;
    final double t = i - mid;
    final bool isSelected = _selectedCard?.cardId == card.cardId;
    final bool isPlaced = isSelected && _selectedCoord != null;
    // 선택 후 좌표에 놓기 전까지 반투명 — 뒤 좌표 확인 가능
    final double cardOpacity = isSelected && !isPlaced ? 0.50 : 1.0;

    return Positioned(
      left: left, bottom: t.abs() * 5.0 + (isSelected ? 22.0 : 0.0),
      child: Transform.rotate(
        angle: t * 0.07, alignment: Alignment.bottomCenter,
        child: Draggable<CardInfo>(
          data: card,
          onDragStarted: () => setState(() => _selectedCard = card),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.48,
              child: Transform.scale(
                scale: 1.08,
                child: _HandCardWidget(
                  card: card,
                  isSelected: true,
                  w: cardW,
                  h: cardH,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.28,
            child: _HandCardWidget(
              card: card,
              isSelected: false,
              w: cardW,
              h: cardH,
              opacity: 1.0,
            ),
          ),
          child: GestureDetector(
            onTap: () => _onCardTap(card),
            child: _HandCardWidget(
              card: card,
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

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        GestureDetector(
          onTap: _canPitch ? _onPitch : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              gradient: _canPitch ? const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFFF5722)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
              color: _canPitch ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _canPitch ? Colors.transparent : Colors.white.withValues(alpha: 0.14)),
              boxShadow: _canPitch ? [BoxShadow(color: const Color(0xFFFF5722).withValues(alpha: 0.45), blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 3))] : null,
            ),
            child: Center(
              child: _isPitching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sports_baseball_rounded, color: _canPitch ? Colors.white : Colors.white.withValues(alpha: 0.28), size: 18),
                      const SizedBox(width: 8),
                      Text('투구', style: TextStyle(color: _canPitch ? Colors.white : Colors.white.withValues(alpha: 0.28), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Hand card widget ─────────────────────────────────────────────────────────

class _HandCardWidget extends StatelessWidget {
  final CardInfo card;
  final bool isSelected;
  final double w, h;
  final double opacity;

  const _HandCardWidget({
    required this.card,
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
      width: w, height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF12122A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.18), width: isSelected ? 2.0 : 1.0),
        boxShadow: [BoxShadow(color: isSelected ? const Color(0xFFFFD700).withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.45), blurRadius: isSelected ? 14 : 6, spreadRadius: isSelected ? 1 : 0, offset: const Offset(0, 4))],
      ),
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, child: Container(height: 3, decoration: BoxDecoration(color: card.timingColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))))),
        Padding(
          padding: const EdgeInsets.fromLTRB(7, 10, 7, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.2, shadows: [Shadow(blurRadius: 3, color: Colors.black54)]), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Center(child: Text(card.directionArrow, style: TextStyle(color: card.timingColor, fontSize: 32, fontWeight: FontWeight.w900, height: 1, shadows: [Shadow(color: card.timingColor.withValues(alpha: 0.45), blurRadius: 10)]))),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('변화', style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 8)),
              Text('${card.changeAmount}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('타이밍', style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 8)),
              Text(card.timingLabel, style: TextStyle(color: card.timingColor, fontSize: 8, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        if (isSelected) Positioned(top: 6, right: 6, child: Container(
          width: 14, height: 14,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
          child: const Icon(Icons.check_rounded, color: Colors.black, size: 9),
        )),
      ]),
      ),
    );
  }
}
