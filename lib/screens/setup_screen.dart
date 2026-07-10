import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_mode.dart';
import '../models/setup_number_request.dart';
import '../services/game_websocket_service.dart';
import '../services/token_storage.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kPoolSize = 12;   // 주사위 숫자 풀: 1~12
const _kOutCount = 5;    // 아웃 슬롯 개수

// ─── Category definition ──────────────────────────────────────────────────────

enum _Category { homerun, triple, doublePlay, out }

extension _CategoryX on _Category {
  String get label => const {
        _Category.homerun: '홈런',
        _Category.triple: '3루타',
        _Category.doublePlay: '병살',
        _Category.out: '아웃',
      }[this]!;

  String get emoji => const {
        _Category.homerun: '🏆',
        _Category.triple: '⚡',
        _Category.doublePlay: '💀',
        _Category.out: '⚾',
      }[this]!;

  Color get color => const {
        _Category.homerun: Color(0xFFFF5252),
        _Category.triple: Color(0xFF448AFF),
        _Category.doublePlay: Color(0xFFBB66FF),
        _Category.out: Color(0xFF9E9E9E),
      }[this]!;

  int get slotCount => const {
        _Category.homerun: 1,
        _Category.triple: 1,
        _Category.doublePlay: 1,
        _Category.out: _kOutCount,
      }[this]!;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SetupScreen extends StatefulWidget {
  final GameMode gameMode;
  final String? matchSessionId;
  const SetupScreen({
    super.key,
    this.gameMode = GameMode.single,
    this.matchSessionId,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final Map<_Category, List<int?>> _slots = {
    _Category.homerun: [null],
    _Category.triple: [null],
    _Category.doublePlay: [null],
    _Category.out: List.filled(_kOutCount, null),
  };

  int? _selectedNumber;

  // WebSocket 상태
  WsStatus _wsStatus = WsStatus.connecting;
  final _ws = GameWebSocketService.instance;
  final _tokenStorage = TokenStorage();

  // 제출 중 로딩
  bool _isSubmitting = false;

  Set<int> get _assignedNumbers {
    final result = <int>{};
    for (final list in _slots.values) {
      for (final n in list) {
        if (n != null) result.add(n);
      }
    }
    return result;
  }

  int get _totalSlots =>
      _slots.values.fold(0, (sum, list) => sum + list.length);

  bool get _isComplete => _assignedNumbers.length == _totalSlots;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _wsStatus = WsStatus.error);
      return;
    }
    _ws.connect(
      accessToken: token,
      onConnected: () {
        if (mounted) setState(() => _wsStatus = WsStatus.connected);
      },
      onError: (msg) {
        if (mounted) setState(() => _wsStatus = WsStatus.error);
        _showSnackBar('WebSocket 연결 실패: $msg', isError: true);
      },
    );
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }

  void _onPoolTap(int number) {
    setState(() {
      _selectedNumber = (_selectedNumber == number) ? null : number;
    });
  }

  void _onSlotTap(_Category cat, int slotIndex) {
    setState(() {
      final current = _slots[cat]![slotIndex];
      if (current != null) {
        // Unassign → return to pool and auto-select
        _slots[cat]![slotIndex] = null;
        _selectedNumber = current;
      } else if (_selectedNumber != null) {
        // Place selected number into this slot
        _slots[cat]![slotIndex] = _selectedNumber;
        _selectedNumber = null;
      }
    });
  }

  void _onReset() {
    setState(() {
      for (final cat in _slots.keys) {
        _slots[cat] = List.filled(cat.slotCount, null);
      }
      _selectedNumber = null;
    });
  }

  Future<void> _onSubmit() async {
    if (!_isComplete || _isSubmitting) return;

    if (!_ws.isConnected) {
      _showSnackBar('서버에 연결되어 있지 않습니다. 잠시 후 다시 시도해주세요.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final request = SetupNumberRequest(
      outNumList: _slots[_Category.out]!.whereType<int>().toList(),
      dpNumList: _slots[_Category.doublePlay]!.whereType<int>().toList(),
      tripleNumList: _slots[_Category.triple]!.whereType<int>().toList(),
      hrNumList: _slots[_Category.homerun]!.whereType<int>().toList(),
    );

    final sent = _ws.sendSetupNumbers(
      matchSessionId: widget.matchSessionId ?? '',
      request: request,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (sent) {
      // TODO: 서버 응답(구독 토픽)을 수신한 뒤 게임플레이 화면으로 전환
      _showSnackBar('셋업 숫자가 제출되었습니다!');
    } else {
      _showSnackBar('전송에 실패했습니다. 다시 시도해주세요.', isError: true);
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          _buildBackground(),
          SafeArea(
            child: Column(children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 14),
                      ..._Category.values.map(_buildCategoryRow),
                      const SizedBox(height: 20),
                      _buildDivider(),
                      const SizedBox(height: 18),
                      _buildPoolSection(),
                      const SizedBox(height: 28),
                      _buildActionButtons(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    if (widget.gameMode == GameMode.single) {
      return Stack(children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg_single.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.78),
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),
        ),
      ]);
    }
    return SizedBox.expand(
      child: CustomPaint(painter: _ModeBgPainter(widget.gameMode)),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final count = _assignedNumbers.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              '셋업 숫자 선택',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '숫자를 눌러 카테고리 슬롯에 배치하세요',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ]),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 슬롯 카운터
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isComplete
                      ? const Color(0xFF7CFC00).withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isComplete
                        ? const Color(0xFF7CFC00).withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  '$count / $_totalSlots',
                  style: TextStyle(
                    color:
                        _isComplete ? const Color(0xFF7CFC00) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // WebSocket 연결 상태 뱃지
              _buildWsBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWsBadge() {
    final (label, color, icon) = switch (_wsStatus) {
      WsStatus.connecting => ('연결 중...', const Color(0xFFFFD700), Icons.sync_rounded),
      WsStatus.connected => ('연결됨', const Color(0xFF7CFC00), Icons.wifi_rounded),
      WsStatus.error => ('연결 실패', const Color(0xFFFF5252), Icons.wifi_off_rounded),
      WsStatus.disconnected => ('연결 끊김', const Color(0xFF9E9E9E), Icons.wifi_off_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Category rows ─────────────────────────────────────────────────────────

  Widget _buildCategoryRow(_Category cat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cat.color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category badge
            Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cat.color.withValues(alpha: 0.38)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    cat.label,
                    style: TextStyle(
                      color: cat.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Slots
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  cat.slotCount,
                  (i) => _buildSlot(cat, i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(_Category cat, int slotIndex) {
    final number = _slots[cat]![slotIndex];
    final isEmpty = number == null;
    final canReceive = isEmpty && _selectedNumber != null;

    return GestureDetector(
      onTap: () => _onSlotTap(cat, slotIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isEmpty
              ? (canReceive
                  ? cat.color.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.06))
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEmpty
                ? (canReceive
                    ? cat.color.withValues(alpha: 0.80)
                    : cat.color.withValues(alpha: 0.28))
                : cat.color,
            width: canReceive ? 2.0 : 1.5,
          ),
          boxShadow: isEmpty
              ? null
              : [
                  BoxShadow(
                    color: cat.color.withValues(alpha: 0.30),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: isEmpty
            ? (canReceive
                ? Center(
                    child: Icon(Icons.add_rounded,
                        color: cat.color.withValues(alpha: 0.65), size: 24))
                : null)
            : _DiceFace(
                number: number,
                numberColor: cat.color,
                dotColor: cat.color.withValues(alpha: 0.22),
                size: 52,
              ),
      ),
    );
  }

  // ── Pool section ──────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(children: [
      Expanded(
          child:
              Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '주사위 숫자',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      Expanded(
          child:
              Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1)),
    ]);
  }

  Widget _buildPoolSection() {
    final assigned = _assignedNumbers;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(_kPoolSize, (i) {
        final number = i + 1;
        final isAssigned = assigned.contains(number);
        final isSelected = _selectedNumber == number;

        return GestureDetector(
          onTap: isAssigned ? null : () => _onPoolTap(number),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isAssigned
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFD700)
                    : (isAssigned
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.0)),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.60),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : (isAssigned
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]),
            ),
            child: isAssigned
                ? Center(
                    child: Icon(Icons.check_rounded,
                        color: Colors.white.withValues(alpha: 0.22), size: 24))
                : _DiceFace(
                    number: number,
                    numberColor: const Color(0xFF1C1C1C),
                    dotColor: const Color(0xFFCCCCCC),
                    size: 60,
                  ),
          ),
        );
      }),
    );
  }

  // ── Action buttons (제출 + 초기화) ───────────────────────────────────────

  Widget _buildActionButtons() {
    final complete = _isComplete;
    final canSubmit =
        complete && _wsStatus == WsStatus.connected && !_isSubmitting;
    final count = _assignedNumbers.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 초기화 버튼 (흰 정사각형) ──────────────────────────────────────
        GestureDetector(
          onTap: _isSubmitting ? null : _onReset,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _isSubmitting ? 0.6 : 1.0),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.restart_alt_rounded,
                color: Color(_isSubmitting ? 0xFF999999 : 0xFF333333),
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // ── 제출 버튼 ──────────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: canSubmit ? _onSubmit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 58,
              decoration: BoxDecoration(
                gradient: canSubmit
                    ? const LinearGradient(
                        colors: [Color(0xFF8AFF2A), Color(0xFF4CAF50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSubmit ? null : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canSubmit
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.18),
                ),
                boxShadow: canSubmit
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF7CFC00).withValues(alpha: 0.42),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _submitLabel(complete, count),
                        style: TextStyle(
                          color: canSubmit
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: canSubmit ? 17 : 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _submitLabel(bool complete, int count) {
    if (!complete) return '숫자를 모두 배치하세요  ($count / $_totalSlots)';
    if (_wsStatus == WsStatus.connecting) return '서버 연결 중...';
    if (_wsStatus == WsStatus.error) return '연결 실패 — 재시도';
    return '제출';
  }
}

// ─── Dice face widget ─────────────────────────────────────────────────────────

class _DiceFace extends StatelessWidget {
  final int number;
  final Color numberColor;
  final Color dotColor;
  final double size;

  const _DiceFace({
    required this.number,
    required this.numberColor,
    required this.dotColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = (size * 0.08).clamp(4.0, 6.5);
    final pad = size * 0.13;
    return Stack(children: [
      Positioned(top: pad, left: pad, child: _dot(dotSize)),
      Positioned(top: pad, right: pad, child: _dot(dotSize)),
      Positioned(bottom: pad, left: pad, child: _dot(dotSize)),
      Positioned(bottom: pad, right: pad, child: _dot(dotSize)),
      Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: numberColor,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    ]);
  }

  Widget _dot(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
      );
}

// ─── Mode background painter ──────────────────────────────────────────────────

class _ModeBgPainter extends CustomPainter {
  final GameMode mode;
  const _ModeBgPainter(this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final colors = switch (mode) {
      GameMode.teamRegular => const [
          Color(0xFF0D1B3E),
          Color(0xFF1A3A6E),
          Color(0xFF0A2040)
        ],
      GameMode.teamMini => const [
          Color(0xFF2B0D3E),
          Color(0xFF5A1A5A),
          Color(0xFF1A0D2B)
        ],
      GameMode.custom => const [
          Color(0xFF1A1A1A),
          Color(0xFF2E2E1A),
          Color(0xFF1A1A0D)
        ],
      _ => const [Color(0xFF1E2810), Color(0xFF2D3A15), Color(0xFF3A2208)],
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    // Subtle diamond tile overlay
    final tilePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
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
  bool shouldRepaint(_ModeBgPainter old) => old.mode != mode;
}
