import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../models/card_info.dart';
import '../models/coordinate_card.dart';
import '../models/game_mode.dart';
import '../services/game_websocket_service.dart';
import '../services/token_storage.dart';
import '../widgets/mode_background.dart';

// ─── Setup category colors (SetupScreen과 동일) ───────────────────────────────

const _kSetupColors = {
  '아웃': Color(0xFF9E9E9E),
  '병살': Color(0xFFBB66FF),
  '3루타': Color(0xFF448AFF),
  '홈런': Color(0xFFFF5252),
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class PitcherGameScreen extends StatefulWidget {
  final GameMode gameMode;
  final String matchSessionId;
  final Map<String, List<int>> setupNumbers;
  final List<CardInfo> handCards;

  const PitcherGameScreen({
    super.key,
    required this.gameMode,
    required this.matchSessionId,
    this.setupNumbers = const {},
    required this.handCards,
  });

  @override
  State<PitcherGameScreen> createState() => _PitcherGameScreenState();
}

class _PitcherGameScreenState extends State<PitcherGameScreen> {
  // ── Coordinate cards (from backend prefetch) ──────────────────────────────
  List<CoordinateCard> _coordCards = [];
  bool _loadingCoords = true;
  String? _coordError;

  // ── Selection state ───────────────────────────────────────────────────────
  CardInfo? _selectedCard;
  CoordinateCard? _selectedCoord;
  bool _isPitching = false;
  bool _isWaitingBatter = false; // 투구 완료 후 타자 선택 대기

  final _ws = GameWebSocketService.instance;
  final _tokenStorage = TokenStorage();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchCoordinateCards();
  }

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
        // 투수 화면에서는 좌표 1~25만 사용 (0번 폭투존은 타자 전용)
        final pitcherCoords =
            list.where((c) => c.coordinateNumber >= 1).toList();
        if (mounted) setState(() => _coordCards = pitcherCoords);
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
      _selectedCard != null &&
      _selectedCoord != null &&
      !_isPitching &&
      !_isWaitingBatter;

  void _onCardTap(CardInfo card) {
    setState(() {
      if (_selectedCard?.cardId == card.cardId) {
        _selectedCard = null;
        _selectedCoord = null;
      } else {
        _selectedCard = card;
      }
    });
  }

  void _onCoordTap(CoordinateCard coord) {
    if (_selectedCard == null) return;
    setState(() {
      _selectedCoord =
          _selectedCoord?.id == coord.id ? null : coord;
    });
  }

  void _onCardDropped(CardInfo card, CoordinateCard coord) {
    setState(() {
      _selectedCard = card;
      _selectedCoord = coord;
    });
  }

  Future<void> _onPitch() async {
    if (!_canPitch) return;
    setState(() => _isPitching = true);

    final sent = _ws.sendPitcherSelectCard(
      matchSessionId: widget.matchSessionId,
      pitchCardId: _selectedCard!.cardId,
      coordinateCardId: _selectedCoord!.id,
    );

    if (!sent) {
      if (mounted) {
        setState(() => _isPitching = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('서버 전송 실패. 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    // 투구 완료 → 타자 선택 대기 상태로 전환
    if (mounted) {
      setState(() {
        _isPitching = false;
        _isWaitingBatter = true;
      });
    }
    // TODO: 턴 결과 이벤트(백엔드 미정) 수신 시 결과 화면으로 이동
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
              _buildHeader(),
              if (widget.setupNumbers.isNotEmpty) _buildSetupSummary(),
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
    );
  }

  // ── Waiting overlay ───────────────────────────────────────────────────────

  Widget _buildWaitingOverlay() {
    final cardName = _selectedCard?.name ?? '';
    final coordNum = _selectedCoord?.coordinateNumber ?? 0;
    final isStrike = _selectedCoord?.isStrike ?? false;

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
              color: const Color(0xFFFFD700).withValues(alpha: 0.35),
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
              // 투구 확인 표시
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_baseball_rounded,
                      color: Color(0xFFFFD700), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$cardName  ·  $coordNum번${isStrike ? '  S' : ''}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '투구 완료',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // 대기 스피너
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '타자 선택 대기 중...',
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        const Text(
          '투구',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
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
          child: Text(
            '투수',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded,
            size: 11, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 1,
            children: widget.setupNumbers.entries.map((e) {
              final color = _kSetupColors[e.key] ?? Colors.white;
              return RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '${e.key} ',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: e.value.join('·'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Pitch display ─────────────────────────────────────────────────────────

  Widget _buildPitchDisplay() {
    final hasSelection = _selectedCard != null || _selectedCoord != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasSelection
            ? Colors.black.withValues(alpha: 0.50)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelection
              ? const Color(0xFFFFD700).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PitchInfoChip(
            label: _selectedCard?.name ?? '─',
            icon: Icons.style_rounded,
            active: _selectedCard != null,
            color: _selectedCard != null
                ? _selectedCard!.timingColor
                : Colors.white.withValues(alpha: 0.25),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '·',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          _PitchInfoChip(
            label: _selectedCoord != null
                ? '${_selectedCoord!.coordinateNumber}번'
                : '─',
            icon: Icons.location_on_rounded,
            active: _selectedCoord != null,
            color: _selectedCoord != null
                ? (_selectedCoord!.isStrike
                    ? const Color(0xFF7CFC00)
                    : const Color(0xFFFFD700))
                : Colors.white.withValues(alpha: 0.25),
          ),
          if (_selectedCoord?.isStrike == true) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7CFC00).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'S',
                style: TextStyle(
                  color: Color(0xFF7CFC00),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
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
              child:
                  CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
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
              child: const Text('다시 시도', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemCount: _coordCards.length,
        itemBuilder: (_, i) => _buildCoordCell(_coordCards[i]),
      ),
    );
  }

  Widget _buildCoordCell(CoordinateCard coord) {
    final isStrike = coord.isStrike;
    final isSelected = _selectedCoord?.id == coord.id;
    final hasCard = _selectedCard != null;

    return DragTarget<CardInfo>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _onCardDropped(details.data, coord),
      builder: (_, candidates, _r) {
        final isHovering = candidates.isNotEmpty;
        return GestureDetector(
          onTap: () => _onCoordTap(coord),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFD700).withValues(alpha: 0.28)
                  : (isHovering
                      ? Colors.white.withValues(alpha: 0.28)
                      : (isStrike
                          ? const Color(0xFF7CFC00).withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.05))),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFD700)
                    : (isHovering
                        ? Colors.white.withValues(alpha: 0.70)
                        : (isStrike
                            ? const Color(0xFF7CFC00).withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.15))),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
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
                          ? const Color(0xFFFFD700)
                          : (isStrike
                              ? const Color(0xFF7CFC00)
                              : (hasCard
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.white.withValues(alpha: 0.40))),
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
      },
    );
  }

  // ── Hand area (Hearthstone fan) ───────────────────────────────────────────

  Widget _buildHandArea() {
    final cards = widget.handCards;
    final n = cards.length;
    if (n == 0) return const SizedBox(height: 130);

    const double cardW = 76.0;
    const double cardH = 108.0;
    const double spread = 58.0;
    const double areaH = 138.0;

    final double totalFanW = (n - 1) * spread + cardW;

    return SizedBox(
      height: areaH,
      child: LayoutBuilder(builder: (context, constraints) {
        final double center = constraints.maxWidth / 2;
        final double startX = center - totalFanW / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < n; i++)
              _buildHandCard(
                  i, n, cards[i], startX + i * spread, cardW, cardH),
          ],
        );
      }),
    );
  }

  Widget _buildHandCard(
    int i,
    int total,
    CardInfo card,
    double left,
    double cardW,
    double cardH,
  ) {
    final double mid = (total - 1) / 2.0;
    final double t = i - mid;
    final double angle = t * 0.07;
    final double arcDip = t.abs() * 5.0;
    final bool isSelected = _selectedCard?.cardId == card.cardId;

    return Positioned(
      left: left,
      bottom: arcDip + (isSelected ? 22.0 : 0.0),
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Draggable<CardInfo>(
          data: card,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.1,
              child: _HandCardWidget(
                  card: card, isSelected: true, w: cardW, h: cardH),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.30,
            child: _HandCardWidget(
                card: card, isSelected: false, w: cardW, h: cardH),
          ),
          onDragStarted: () => setState(() => _selectedCard = card),
          child: GestureDetector(
            onTap: () => _onCardTap(card),
            child: _HandCardWidget(
                card: card, isSelected: isSelected, w: cardW, h: cardH),
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _canPitch ? _onPitch : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: _canPitch
                    ? const LinearGradient(
                        colors: [Color(0xFFFF8C00), Color(0xFFFF5722)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _canPitch ? null : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _canPitch
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: _canPitch
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: _isPitching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_baseball_rounded,
                            color: _canPitch
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.28),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '투구',
                            style: TextStyle(
                              color: _canPitch
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
}

// ─── Pitch info chip ──────────────────────────────────────────────────────────

class _PitchInfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;

  const _PitchInfoChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.30),
            fontSize: active ? 15 : 14,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0.3,
            shadows: active
                ? const [Shadow(blurRadius: 6, color: Colors.black54)]
                : null,
          ),
        ),
      ],
    );
  }
}

// ─── Hand card widget ─────────────────────────────────────────────────────────

class _HandCardWidget extends StatelessWidget {
  final CardInfo card;
  final bool isSelected;
  final double w;
  final double h;

  const _HandCardWidget({
    required this.card,
    required this.isSelected,
    required this.w,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
      child: Stack(children: [
        // 타이밍 컬러 상단 바
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: card.timingColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
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
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: card.timingColor.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
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
        if (isSelected)
          Positioned(
            top: 6, right: 6,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFD700),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.black, size: 9),
            ),
          ),
      ]),
    );
  }
}
