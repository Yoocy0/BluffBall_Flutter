import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_mode.dart';
import '../models/setup_number_request.dart';
import '../services/game_websocket_service.dart';
import '../services/match_service.dart';
import '../services/token_storage.dart';
import '../widgets/opponent_disconnected_overlay.dart';
import 'pitch_selection_screen.dart';

// ─── Step enum ────────────────────────────────────────────────────────────────

enum _Step { out, doublePlay, triple, homerun }

extension _StepX on _Step {
  String get label => switch (this) {
        _Step.out => '아웃',
        _Step.doublePlay => '병살',
        _Step.triple => '3루타',
        _Step.homerun => '홈런',
      };

  String get emoji => switch (this) {
        _Step.out => '⚾',
        _Step.doublePlay => '💀',
        _Step.triple => '⚡',
        _Step.homerun => '🏆',
      };

  Color get color => switch (this) {
        _Step.out => const Color(0xFF9E9E9E),
        _Step.doublePlay => const Color(0xFFBB66FF),
        _Step.triple => const Color(0xFF448AFF),
        _Step.homerun => const Color(0xFFFF5252),
      };

  int get quota => switch (this) {
        _Step.out => 5,
        _Step.doublePlay => 1,
        _Step.triple => 1,
        _Step.homerun => 1,
      };

  bool get isDefense => this == _Step.out || this == _Step.doublePlay;

  _Step? get next {
    final all = _Step.values;
    final idx = all.indexOf(this);
    return idx < all.length - 1 ? all[idx + 1] : null;
  }
}

const _kPoolSize = 12;

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
  final Map<_Step, List<int>> _selected = {
    for (final s in _Step.values) s: [],
  };
  _Step _currentStep = _Step.out;

  WsStatus _wsStatus = WsStatus.connecting;
  final _ws = GameWebSocketService.instance;
  final _tokenStorage = TokenStorage();
  bool _isSubmitting = false;

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
        _subscribeGameTopicEarly(token);
      },
      onError: (msg) {
        if (mounted) setState(() => _wsStatus = WsStatus.error);
        _showSnackBar('WebSocket 연결 실패: $msg', isError: true);
      },
    );
  }

  Future<void> _subscribeGameTopicEarly(String token) async {
    final sessionId = widget.matchSessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final userIdStr = MatchService.extractUserIdFromJwt(token);
    final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    if (userId == null) return;

    // ignore: avoid_print
    print('[SetupScreen] 게임 토픽 선구독 (CardHandEvent 버퍼용) userId=$userId');
    _ws.subscribeGameTopic(
      matchSessionId: sessionId,
      currentUserId: userId,
      onEvent: (_) {},
      onAllReady: (_) {},
    );
    _ws.bootstrapMatchSession(sessionId);
  }

  @override
  void dispose() {
    // 연결은 PitchSelectionScreen에서 계속 사용하므로 여기서 끊지 않음
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  /// 현재 스텝과 같은 팀(수비/공격)의 다른 스텝에서 이미 사용된 번호
  Set<int> get _unavailableForCurrent {
    final result = <int>{};
    for (final step in _Step.values) {
      if (step != _currentStep && step.isDefense == _currentStep.isDefense) {
        result.addAll(_selected[step]!);
      }
    }
    return result;
  }

  bool get _isAllComplete =>
      _Step.values.every((s) => _selected[s]!.length == s.quota);

  bool get _isCurrentComplete =>
      _selected[_currentStep]!.length == _currentStep.quota;

  void _onTap(int number) {
    final list = _selected[_currentStep]!;
    final unavailable = _unavailableForCurrent;
    if (unavailable.contains(number)) return;

    setState(() {
      if (list.contains(number)) {
        list.remove(number);
      } else if (list.length < _currentStep.quota) {
        list.add(number);
        // 선택 완료 시 자동으로 다음 스텝으로 이동
        if (list.length == _currentStep.quota) {
          final next = _currentStep.next;
          if (next != null) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _currentStep = next);
            });
          }
        }
      }
    });
  }

  void _onNext() {
    if (!_isCurrentComplete) return;
    final next = _currentStep.next;
    if (next != null) setState(() => _currentStep = next);
  }

  void _onReset() {
    if (_isSubmitting) return;
    setState(() {
      for (final step in _Step.values) {
        _selected[step] = [];
      }
      _currentStep = _Step.out;
    });
  }

  Future<void> _onSubmit() async {
    if (!_isAllComplete || _isSubmitting) return;
    if (!_ws.isConnected) {
      _showSnackBar('서버에 연결되어 있지 않습니다.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);

    final request = SetupNumberRequest(
      outNumList: _selected[_Step.out]!,
      dpNumList: _selected[_Step.doublePlay]!,
      tripleNumList: _selected[_Step.triple]!,
      hrNumList: _selected[_Step.homerun]!,
    );

    final sent = _ws.sendSetupNumbers(
      matchSessionId: widget.matchSessionId ?? '',
      request: request,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (sent) {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => PitchSelectionScreen(
          gameMode: widget.gameMode,
          matchSessionId: widget.matchSessionId ?? '',
          setupNumbers: {
            '아웃': List<int>.from(_selected[_Step.out]!..sort()),
            '병살': List<int>.from(_selected[_Step.doublePlay]!..sort()),
            '3루타': List<int>.from(_selected[_Step.triple]!..sort()),
            '홈런': List<int>.from(_selected[_Step.homerun]!..sort()),
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    } else {
      _showSnackBar('전송에 실패했습니다.', isError: true);
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        body: InGamePresenceShell(
          matchSessionId: widget.matchSessionId ?? '',
          gameMode: widget.gameMode,
          child: Stack(children: [
          _buildBackground(),
          SafeArea(
            child: Column(children: [
              _buildHeader(),
              _buildSummaryBar(),
              _buildStepIndicator(),
              _buildCurrentStepInfo(),
              Expanded(child: _buildNumberGrid()),
              _buildButtons(),
              const SizedBox(height: 12),
            ]),
          ),
        ]),
        ),
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
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0.0, 0.35, 1.0],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const Text(
            '셋업 숫자 선택',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
            ),
          ),
          const Spacer(),
          _buildWsBadge(),
        ],
      ),
    );
  }

  Widget _buildWsBadge() {
    final (label, color, icon) = switch (_wsStatus) {
      WsStatus.connecting => (
          '연결 중',
          const Color(0xFFFFD700),
          Icons.sync_rounded
        ),
      WsStatus.connected => (
          '연결됨',
          const Color(0xFF7CFC00),
          Icons.wifi_rounded
        ),
      WsStatus.error => (
          '연결 실패',
          const Color(0xFFFF5252),
          Icons.wifi_off_rounded
        ),
      WsStatus.disconnected => (
          '연결 끊김',
          const Color(0xFF9E9E9E),
          Icons.wifi_off_rounded
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Summary bar ───────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          _buildSummaryTeam('수비', [_Step.out, _Step.doublePlay]),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withValues(alpha: 0.15),
          ),
          _buildSummaryTeam('공격', [_Step.triple, _Step.homerun]),
        ],
      ),
    );
  }

  Widget _buildSummaryTeam(String teamLabel, List<_Step> steps) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          ...steps.map((step) {
            final nums = _selected[step]!;
            final isDone = nums.length == step.quota;
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                children: [
                  Text(
                    '${step.label} ',
                    style: TextStyle(
                      color: step.color.withValues(alpha: isDone ? 1.0 : 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      nums.isEmpty ? '-' : nums.join(' · '),
                      style: TextStyle(
                        color: nums.isEmpty
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.88),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final steps = _Step.values;
    final currentIdx = steps.indexOf(_currentStep);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: i <= currentIdx
                        ? steps[i - 1].color.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            _buildStepDot(steps[i], i <= currentIdx),
          ],
        ],
      ),
    );
  }

  Widget _buildStepDot(_Step step, bool reached) {
    final isDone = _selected[step]!.length == step.quota;
    final isCurrent = step == _currentStep;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? step.color
            : (isCurrent
                ? step.color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.07)),
        border: Border.all(
          color: reached
              ? step.color.withValues(alpha: 0.80)
              : Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
            : Text(step.emoji, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // ── Current step info ─────────────────────────────────────────────────────

  Widget _buildCurrentStepInfo() {
    final step = _currentStep;
    final count = _selected[step]!.length;
    final quota = step.quota;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Category badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: step.color.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  step.label,
                  style: TextStyle(
                    color: step.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Slot dots
          Row(
            children: List.generate(quota, (i) {
              final filled = i < count;
              return Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? step.color
                      : Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: filled
                        ? step.color
                        : Colors.white.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: count == quota
                  ? const Color(0xFF7CFC00)
                  : Colors.white.withValues(alpha: 0.50),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            child: Text('$count / $quota'),
          ),
        ],
      ),
    );
  }

  // ── Number grid ───────────────────────────────────────────────────────────

  Widget _buildNumberGrid() {
    final step = _currentStep;
    final selectedNums = _selected[step]!;
    final unavailable = _unavailableForCurrent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _kPoolSize,
        itemBuilder: (_, i) {
          final number = i + 1;
          final isSelected = selectedNums.contains(number);
          final isUnavailable = unavailable.contains(number);
          final isFull =
              selectedNums.length >= step.quota && !isSelected;
          final tappable = !isUnavailable && !isFull;

          return GestureDetector(
            onTap: tappable ? () => _onTap(number) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                color: isSelected
                    ? step.color
                    : (isUnavailable || isFull
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.93)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? step.color
                      : (isUnavailable || isFull
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.transparent),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: step.color.withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : (!isUnavailable && !isFull
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isUnavailable || isFull
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFF1C1C1C)),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildButtons() {
    final isLast = _currentStep == _Step.values.last;
    final currentComplete = _isCurrentComplete;
    final allComplete = _isAllComplete;
    final canAct = isLast
        ? allComplete && _wsStatus == WsStatus.connected && !_isSubmitting
        : currentComplete;

    String buttonLabel;
    if (_isSubmitting) {
      buttonLabel = '';
    } else if (isLast) {
      if (allComplete) {
        buttonLabel = _wsStatus == WsStatus.connecting ? '연결 중...' : '제출';
      } else {
        buttonLabel =
            '${_currentStep.quota - _selected[_currentStep]!.length}개 더 선택';
      }
    } else {
      if (currentComplete) {
        buttonLabel = '다음  ${_currentStep.next!.label} →';
      } else {
        buttonLabel =
            '${_currentStep.quota - _selected[_currentStep]!.length}개 더 선택';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          // Reset
          GestureDetector(
            onTap: _isSubmitting ? null : _onReset,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: _isSubmitting ? 0.5 : 1.0),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.restart_alt_rounded,
                  color:
                      Color(_isSubmitting ? 0xFF999999 : 0xFF333333),
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Next / Submit
          Expanded(
            child: GestureDetector(
              onTap: canAct
                  ? (isLast ? _onSubmit : _onNext)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 52,
                decoration: BoxDecoration(
                  gradient: canAct
                      ? LinearGradient(
                          colors: isLast
                              ? [
                                  const Color(0xFF8AFF2A),
                                  const Color(0xFF4CAF50)
                                ]
                              : [
                                  _currentStep.color,
                                  _currentStep.color
                                      .withValues(alpha: 0.72)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: canAct
                      ? null
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: canAct
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: canAct
                      ? [
                          BoxShadow(
                            color: (isLast
                                    ? const Color(0xFF7CFC00)
                                    : _currentStep.color)
                                .withValues(alpha: 0.42),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          buttonLabel,
                          style: TextStyle(
                            color: canAct
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.32),
                            fontSize: canAct ? 15 : 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
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
