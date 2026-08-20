import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/card_info.dart';
import '../screens/home_screen.dart';
import '../services/tutorial_service.dart';
import '../widgets/dice_widget.dart';
import 'tutorial_coach_overlay.dart';
import 'tutorial_coord_math.dart';
import 'tutorial_demo_data.dart';
import 'tutorial_game_panels.dart';
import 'tutorial_models.dart';

/// 인게임 화면 위에 코치 오버레이를 씌운 쇼다운 튜토리얼.
class TutorialFlowScreen extends StatefulWidget {
  final bool isReplay;

  const TutorialFlowScreen({super.key, this.isReplay = false});

  @override
  State<TutorialFlowScreen> createState() => _TutorialFlowScreenState();
}

class _TutorialFlowScreenState extends State<TutorialFlowScreen> {
  final _service = TutorialService();
  final _anchors = TutorialAnchorKeys();

  TutorialStage _stage = TutorialStage.setupDefense;
  int _beat = 0;

  // Setup
  TutSetupStep _setupStep = TutSetupStep.out;
  final Map<TutSetupStep, List<int>> _setup = {
    for (final s in TutSetupStep.values) s: <int>[],
  };

  // Pitch select
  final _hand = List<CardInfo>.from(TutorialDemoData.dealtHand);
  final Set<int> _mulliganIds = {};

  // Pitcher
  CardInfo? _pitchCard;
  int? _pitchStart;
  int? _pitchFinal;

  // Batter
  TutorialTiming? _batTiming;
  int? _batCoord;
  bool _showDice = false;
  bool _diceDone = false;

  // Reward
  final Set<TutorialRewardPitch> _rewards = {};
  bool _completing = false;

  bool get _canExit => widget.isReplay || _stage == TutorialStage.finished;

  List<CoachBeat> get _beats => switch (_stage) {
        TutorialStage.setupDefense => const [
              CoachBeat(
                text: '경기에 들어가기 전, 셋업 숫자를 고릅니다.',
                spotlight: TutorialSpotlight.setupSummary,
              ),
              CoachBeat(
                text: '수비 측은 아웃 5개와 병살 1개입니다. 주사위가 이 숫자면 해당 결과가 납니다.',
                spotlight: TutorialSpotlight.setupDefense,
              ),
              CoachBeat(
                text: '이제 직접 해보세요. 아웃 5개를 고른 뒤 병살 1개를 고르세요.',
                spotlight: TutorialSpotlight.setupGrid,
              ),
            ],
        TutorialStage.setupOffense => const [
              CoachBeat(
                text: '공격 측은 3루타 1개와 홈런 1개를 고릅니다.',
                spotlight: TutorialSpotlight.setupOffense,
              ),
              CoachBeat(
                text: '홈런은 7~12만 가능합니다. 튜토리얼에서는 홈런을 12로 고릅니다.',
                spotlight: TutorialSpotlight.setupStepChip,
              ),
              CoachBeat(
                text: '3루타 1개 선택 후, 홈런 12를 선택하세요.',
                spotlight: TutorialSpotlight.setupGrid,
              ),
            ],
        TutorialStage.pitchSelect => const [
              CoachBeat(
                text: '보유 구종 중 3장이 무작위로 배분됩니다.',
                spotlight: TutorialSpotlight.pitchHand,
              ),
              CoachBeat(
                text: '교체할 수 있지만, 보유 카드가 3장 미만이면 의미가 없습니다.',
                spotlight: TutorialSpotlight.pitchActions,
              ),
              CoachBeat(
                text: '이 3장으로 진행합니다. 확정을 눌러주세요.',
                spotlight: TutorialSpotlight.pitchActions,
              ),
            ],
        TutorialStage.pitcherLesson => [
              const CoachBeat(
                text: '카드의 방향·변화량이 시작 좌표에서 최종 좌표를 만듭니다.',
                spotlight: TutorialSpotlight.pitcherHand,
              ),
              CoachBeat(
                text:
                    '커브는 ↓ 방향, 변화 ${TutorialDemoData.curve.changeAmount}칸입니다. '
                    '시작점에서 변화량만큼 이동한 곳이 최종 좌표예요.',
                spotlight: TutorialSpotlight.pitcherHand,
              ),
              const CoachBeat(
                text:
                    '퀴즈: 커브를 놓아 최종 좌표가 ${TutorialDemoData.pitcherQuizTargetFinal}이 되게 하세요.',
                spotlight: TutorialSpotlight.pitcherGrid,
              ),
            ],
        TutorialStage.batterLesson => [
              const CoachBeat(
                text: '타자 차례입니다. 보라색이 투수가 고른 시작 좌표입니다.',
                spotlight: TutorialSpotlight.batterGrid,
              ),
              const CoachBeat(
                text:
                    '상대 구종: 포심 패스트볼.\n'
                    '타이밍 「이른」 · 방향 직구 · 변화량 0.\n'
                    '강화 카드로 이 값들이 달라질 수 있어요.',
                spotlight: TutorialSpotlight.batterTiming,
              ),
              CoachBeat(
                text:
                    '시작 좌표는 ${TutorialDemoData.batterStartCoord}입니다.\n'
                    '구종 정보를 보고 맞는 타이밍과 좌표에 타격하세요.',
                spotlight: TutorialSpotlight.batterGrid,
              ),
            ],
        TutorialStage.reward => const [
              CoachBeat(
                text: '커브 / 슬라이더 / 포크 중 2장을 고르세요. 포심은 기본 지급됩니다.',
              ),
            ],
        TutorialStage.finished => const [
              CoachBeat(text: '튜토리얼이 완료되었습니다!'),
            ],
      };

  bool get _inInteractiveBeat {
    final last = _beats.length - 1;
    if (_beat < last) return false;
    return switch (_stage) {
      TutorialStage.setupDefense ||
      TutorialStage.setupOffense ||
      TutorialStage.pitchSelect ||
      TutorialStage.pitcherLesson ||
      TutorialStage.batterLesson ||
      TutorialStage.reward =>
        true,
      _ => false,
    };
  }

  void _advanceBeat() {
    if (_beat < _beats.length - 1) {
      setState(() => _beat++);
      return;
    }
    // last beat of finished → home handled by button
  }

  void _goStage(TutorialStage stage) {
    setState(() {
      _stage = stage;
      _beat = 0;
    });
  }

  void _goHome() {
    final route = MaterialPageRoute(builder: (_) => const HomeScreen());
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
    }
  }

  // ── Setup interactions ────────────────────────────────────────────────────

  void _onSetupNumber(int n) {
    if (!_inInteractiveBeat) return;
    final list = _setup[_setupStep]!;

    if (_stage == TutorialStage.setupDefense) {
      if (_setupStep == TutSetupStep.out) {
        _toggleSetup(n);
        if (list.length == 5) {
          setState(() => _setupStep = TutSetupStep.doublePlay);
        }
      } else if (_setupStep == TutSetupStep.doublePlay) {
        _toggleSetup(n);
        if (list.length == 1) {
          _goStage(TutorialStage.setupOffense);
          setState(() => _setupStep = TutSetupStep.triple);
        }
      }
      return;
    }

    if (_stage == TutorialStage.setupOffense) {
      if (_setupStep == TutSetupStep.triple) {
        _toggleSetup(n);
        if (list.length == 1) {
          setState(() => _setupStep = TutSetupStep.homerun);
        }
      } else if (_setupStep == TutSetupStep.homerun) {
        if (n != TutorialDemoData.forcedHomerunNumber) {
          _showPopup('홈런은 12를 선택해주세요.',
              detail: '튜토리얼에서는 홈런 숫자를 12로 고정합니다. (선택 가능: 7~12)');
          return;
        }
        _toggleSetup(n);
        if (list.length == 1) {
          _goStage(TutorialStage.pitchSelect);
        }
      }
    }
  }

  void _toggleSetup(int n) {
    final list = _setup[_setupStep]!;
    final used = <int>{};
    for (final s in TutSetupStep.values) {
      if (s != _setupStep && s.isDefense == _setupStep.isDefense) {
        used.addAll(_setup[s]!);
      }
    }
    if (used.contains(n)) return;
    setState(() {
      if (list.contains(n)) {
        list.remove(n);
      } else if (list.length < _setupStep.quota) {
        list.add(n);
      }
    });
  }

  bool _setupEnabled(int n) {
    if (_setupStep == TutSetupStep.homerun) {
      return n >= 7 && n <= 12;
    }
    if (_setupStep == TutSetupStep.triple) {
      // avoid conflict with later HR pool optionally - allow 1-12 except used
      return true;
    }
    return true;
  }

  // ── Pitcher quiz ──────────────────────────────────────────────────────────

  void _onPitchDrop(CardInfo card, int coord) {
    if (!_inInteractiveBeat || _stage != TutorialStage.pitcherLesson) return;
    if (card.cardId != TutorialDemoData.curve.cardId) {
      _showPopup('커브 카드를 사용하세요.');
      return;
    }

    final fin = tutorialApplyMove(
      start: coord,
      direction: card.direction,
      changeAmount: card.changeAmount,
    );

    if (fin != TutorialDemoData.pitcherQuizTargetFinal) {
      setState(() {
        _pitchCard = card;
        _pitchStart = coord;
        _pitchFinal = fin;
      });
      _showPopup(
        '최종 좌표가 ${TutorialDemoData.pitcherQuizTargetFinal}이 아닙니다.',
        detail:
            '지금 시작 $coord → 최종 $fin 입니다.\n'
            '커브(↓ 변화 ${TutorialDemoData.curve.changeAmount})로 '
            '최종 ${TutorialDemoData.pitcherQuizTargetFinal}이 되는 시작 좌표를 찾아보세요.',
      );
      return;
    }

    setState(() {
      _pitchCard = card;
      _pitchStart = coord;
      _pitchFinal = fin;
    });
  }

  void _onConfirmPitch() {
    if (_pitchFinal == null) return;
    _goStage(TutorialStage.batterLesson);
  }

  // ── Batter hit ────────────────────────────────────────────────────────────

  void _onBatterPlace(TutorialTiming timing, int coord) {
    if (!_inInteractiveBeat || _stage != TutorialStage.batterLesson) return;
    if (_showDice) return;

    final okTiming = timing == TutorialDemoData.batterCorrectTiming;
    final okCoord = coord == TutorialDemoData.batterCorrectCoord;
    if (!okTiming || !okCoord) {
      setState(() {
        _batTiming = timing;
        _batCoord = coord;
      });
      _showPopup(
        '타격이 맞지 않습니다.',
        detail:
            '포심의 타이밍·변화 방향·변화량과 시작 좌표를 다시 생각해보세요.\n'
            '(지금 선택: ${timing.apiValue} @ $coord)',
      );
      return;
    }

    setState(() {
      _batTiming = timing;
      _batCoord = coord;
      _showDice = true;
    });
  }

  Future<void> _showPopup(String title, {String? detail}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2810),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: detail == null
            ? null
            : Text(
                detail,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '확인',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDiceLanded() {
    if (_diceDone) return;
    setState(() => _diceDone = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _goStage(TutorialStage.reward);
    });
  }

  Future<void> _completeRewards() async {
    if (_completing || _rewards.length != 2) return;
    setState(() => _completing = true);
    try {
      if (!widget.isReplay) {
        await _service.complete(
          selectedPitchKeys: _rewards.map((e) => e.key).toList(),
        );
      }
      if (!mounted) return;
      setState(() {
        _completing = false;
        _stage = TutorialStage.finished;
        _beat = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xFF3A1A05),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final beat = _beats[_beat.clamp(0, _beats.length - 1)];
    final interactive = _inInteractiveBeat;

    return PopScope(
      canPop: _canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canExit) _goHome();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: _TutBg()),
              SafeArea(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(child: _buildStageBody()),
                  ],
                ),
              ),
              if (_stage != TutorialStage.finished)
                Positioned.fill(
                  child: TutorialCoachLayer(
                    text: _composeCoachText(beat),
                    badge: _stage.title,
                    spotlight: beat.spotlight,
                    anchors: _anchors,
                    interactive: interactive,
                    onTapAdvance: interactive ? null : _advanceBeat,
                  ),
                ),
              if (_showDice && _stage == TutorialStage.batterLesson)
                Positioned.fill(child: _diceOverlay()),
              if (_stage == TutorialStage.finished) _finishedOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  String _composeCoachText(CoachBeat beat) {
    if (_stage == TutorialStage.setupDefense &&
        _inInteractiveBeat &&
        _setupStep == TutSetupStep.doublePlay) {
      return '좋아요! 이제 병살 숫자 1개를 선택하세요.';
    }
    if (_stage == TutorialStage.setupOffense &&
        _inInteractiveBeat &&
        _setupStep == TutSetupStep.homerun) {
      return '마지막으로 홈런 12를 선택하세요. (7~12만 가능)';
    }
    if (_stage == TutorialStage.pitcherLesson &&
        _pitchFinal == TutorialDemoData.pitcherQuizTargetFinal &&
        _inInteractiveBeat) {
      return '정답! 시작 $_pitchStart → 최종 $_pitchFinal. 투구를 누르세요.';
    }
    if (_stage == TutorialStage.batterLesson && _showDice) {
      return '타격 성공! 주사위 합이 홈런 숫자 12가 되면 홈런입니다.';
    }
    return beat.text;
  }

  Map<String, List<int>> get _setupMap => {
        '아웃': List<int>.from(_setup[TutSetupStep.out]!),
        '병살': List<int>.from(_setup[TutSetupStep.doublePlay]!),
        '3루타': List<int>.from(_setup[TutSetupStep.triple]!),
        '홈런': List<int>.from(_setup[TutSetupStep.homerun]!),
      };

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          if (_canExit)
            IconButton(
              onPressed: _goHome,
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              _stage.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStageBody() {
    switch (_stage) {
      case TutorialStage.setupDefense:
      case TutorialStage.setupOffense:
        return TutorialSetupPanel(
          current: _setupStep,
          selected: _setup,
          anchors: _anchors,
          onTapNumber: _inInteractiveBeat ? _onSetupNumber : null,
          isEnabled: _setupEnabled,
        );
      case TutorialStage.pitchSelect:
        return TutorialPitchHandPanel(
          cards: _hand,
          selectedIds: _mulliganIds,
          anchors: _anchors,
          onToggle: _inInteractiveBeat
              ? (id) => setState(() {
                    if (_mulliganIds.contains(id)) {
                      _mulliganIds.remove(id);
                    } else {
                      _mulliganIds.add(id);
                    }
                  })
              : null,
          onConfirm: _inInteractiveBeat
              ? () => _goStage(TutorialStage.pitcherLesson)
              : null,
        );
      case TutorialStage.pitcherLesson:
        return TutorialPitcherPanel(
          hand: TutorialDemoData.dealtHand,
          selectedCard: _pitchCard,
          placedStart: _pitchStart,
          revealFinal: _pitchFinal,
          setupNumbers: _setupMap,
          anchors: _anchors,
          onSelectCard: _inInteractiveBeat
              ? (c) => setState(() {
                    _pitchCard = c;
                  })
              : null,
          onDrop: _inInteractiveBeat ? _onPitchDrop : null,
          onConfirmPitch: _inInteractiveBeat &&
                  _pitchFinal == TutorialDemoData.pitcherQuizTargetFinal
              ? _onConfirmPitch
              : null,
        );
      case TutorialStage.batterLesson:
        return TutorialBatterPanel(
          startCoord: TutorialDemoData.batterStartCoord,
          selectedTiming: _batTiming,
          selectedCoord: _batCoord,
          setupNumbers: _setupMap,
          anchors: _anchors,
          onSelectTiming: _inInteractiveBeat && !_showDice
              ? (t) => setState(() {
                    _batTiming = t;
                  })
              : null,
          onPlace: _inInteractiveBeat && !_showDice ? _onBatterPlace : null,
        );
      case TutorialStage.reward:
        return _rewardBody();
      case TutorialStage.finished:
        return const SizedBox.shrink();
    }
  }

  Widget _rewardBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const TutorialStageHeader(
          title: '시작 구종 지급',
          subtitle: '포심 + 변화구 2장',
        ),
        ...TutorialRewardPitch.values.map((p) {
          final sel = _rewards.contains(p);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() {
                if (sel) {
                  _rewards.remove(p);
                } else if (_rewards.length < 2) {
                  _rewards.add(p);
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: p.accent.withValues(alpha: sel ? 0.3 : 0.1),
                  border: Border.all(
                    color: sel ? const Color(0xFFFFD700) : p.accent,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sel ? Icons.check_circle : Icons.circle_outlined,
                      color: sel ? const Color(0xFFFFD700) : Colors.white38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${p.name}  ·  ${p.direction} 변화 ${p.changeAmount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _rewards.length == 2 && !_completing ? _completeRewards : null,
          child: Opacity(
            opacity: _rewards.length == 2 ? 1 : 0.4,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
                ),
              ),
              child: Text(
                _completing
                    ? '처리 중...'
                    : widget.isReplay
                        ? '데모 완료'
                        : '선택 완료 · 튜토리얼 끝내기',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _diceOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '결과 주사위',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '홈런 셋업 = ${TutorialDemoData.forcedHomerunNumber}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: DiceThrowWidget(
              diceCount: 2,
              diceValues: const [6, 6],
              onLanded: _onDiceLanded,
            ),
          ),
          if (_diceDone) ...[
            const SizedBox(height: 16),
            const Text(
              '6 + 6 = 12  →  홈런!',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _finishedOverlay() {
    final names = _rewards.map((e) => e.name).join(' · ');
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF1A220E),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    '튜토리얼이 완료되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.isReplay
                        ? '데모만 진행했습니다.'
                        : '포심 패스트볼 + $names 지급',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _goHome,
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
                        ),
                      ),
                      child: const Text(
                        '홈으로',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutBg extends StatelessWidget {
  const _TutBg();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/bg_single.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1E2810)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.82),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
