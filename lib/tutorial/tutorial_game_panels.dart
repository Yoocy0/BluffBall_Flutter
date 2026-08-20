import 'package:flutter/material.dart';

import '../models/card_info.dart';
import '../widgets/setup_numbers_summary.dart';
import 'tutorial_coach_overlay.dart';
import 'tutorial_demo_data.dart';
import 'tutorial_models.dart';

const _kGold = Color(0xFFFFD700);

class TutorialStageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const TutorialStageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.school_rounded, color: _kGold, size: 14),
                SizedBox(width: 4),
                Text(
                  'DEMO',
                  style: TextStyle(
                    color: _kGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setup number panel ───────────────────────────────────────────────────────

enum TutSetupStep { out, doublePlay, triple, homerun }

extension TutSetupStepX on TutSetupStep {
  String get label => switch (this) {
        TutSetupStep.out => '아웃',
        TutSetupStep.doublePlay => '병살',
        TutSetupStep.triple => '3루타',
        TutSetupStep.homerun => '홈런',
      };

  Color get color => switch (this) {
        TutSetupStep.out => const Color(0xFF9E9E9E),
        TutSetupStep.doublePlay => const Color(0xFFBB66FF),
        TutSetupStep.triple => const Color(0xFF448AFF),
        TutSetupStep.homerun => const Color(0xFFFF5252),
      };

  int get quota => switch (this) {
        TutSetupStep.out => 5,
        _ => 1,
      };

  bool get isDefense =>
      this == TutSetupStep.out || this == TutSetupStep.doublePlay;
}

class TutorialSetupPanel extends StatelessWidget {
  final TutSetupStep current;
  final Map<TutSetupStep, List<int>> selected;
  final ValueChanged<int>? onTapNumber;
  final bool Function(int)? isEnabled;
  final TutorialAnchorKeys? anchors;

  const TutorialSetupPanel({
    super.key,
    required this.current,
    required this.selected,
    this.onTapNumber,
    this.isEnabled,
    this.anchors,
  });

  @override
  Widget build(BuildContext context) {
    final nums = selected[current] ?? const <int>[];
    return Column(
      children: [
        TutorialStageHeader(
          title: '셋업 숫자 선택',
          subtitle: '${current.label} · ${nums.length}/${current.quota}',
        ),
        _summary(),
        Padding(
          key: anchors?.stepChip,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: current.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: current.color),
                ),
                child: Text(
                  current.label,
                  style: TextStyle(
                    color: current.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current == TutSetupStep.homerun
                      ? '홈런은 7~12만 선택 가능'
                      : '${current.quota}개 선택',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: anchors?.numberGrid,
            child: _grid(nums),
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    return Container(
      key: anchors?.summary,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: KeyedSubtree(
              key: anchors?.defense,
              child: _teamContent(
                  '수비', [TutSetupStep.out, TutSetupStep.doublePlay]),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white24,
          ),
          Expanded(
            child: KeyedSubtree(
              key: anchors?.offense,
              child: _teamContent(
                  '공격', [TutSetupStep.triple, TutSetupStep.homerun]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamContent(String label, List<TutSetupStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w700)),
        ...steps.map((s) {
          final list = selected[s] ?? const <int>[];
          return Text(
            '${s.label} ${list.isEmpty ? '-' : list.join('·')}',
            style: TextStyle(
              color: s.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          );
        }),
      ],
    );
  }

  Widget _grid(List<int> nums) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 12,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (_, i) {
          final n = i + 1;
          final selectedNow = nums.contains(n);
          final enabled = isEnabled?.call(n) ?? true;
          final full = nums.length >= current.quota && !selectedNow;
          final canTap = enabled && !full && onTapNumber != null;
          return GestureDetector(
            onTap: canTap ? () => onTapNumber!(n) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: selectedNow
                    ? current.color
                    : (!enabled || full
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.92)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedNow ? current.color : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$n',
                style: TextStyle(
                  color: selectedNow
                      ? Colors.white
                      : (!enabled || full
                          ? Colors.white30
                          : const Color(0xFF1C1C1C)),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Pitch hand panel ─────────────────────────────────────────────────────────

class TutorialPitchHandPanel extends StatelessWidget {
  final List<CardInfo> cards;
  final Set<int> selectedIds;
  final ValueChanged<int>? onToggle;
  final VoidCallback? onConfirm;
  final bool canReplace;
  final TutorialAnchorKeys? anchors;

  const TutorialPitchHandPanel({
    super.key,
    required this.cards,
    required this.selectedIds,
    this.onToggle,
    this.onConfirm,
    this.canReplace = true,
    this.anchors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TutorialStageHeader(
          title: '구종 선택',
          subtitle: '보유 구종에서 3장을 무작위로 배분',
        ),
        Expanded(
          child: Center(
            child: KeyedSubtree(
              key: anchors?.pitchHand,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: cards
                    .map(
                      (c) => _PitchCard(
                        card: c,
                        selected: selectedIds.contains(c.cardId),
                        onTap: onToggle == null
                            ? null
                            : () => onToggle!(c.cardId),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        Padding(
          key: anchors?.pitchActions,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _ActionChip(
                  label: canReplace ? '교체 (데모)' : '교체 불가',
                  enabled: canReplace && selectedIds.isNotEmpty,
                  color: const Color(0xFF6BB8E8),
                  onTap: canReplace && selectedIds.isNotEmpty ? () {} : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionChip(
                  label: '확정',
                  enabled: onConfirm != null,
                  color: const Color(0xFFD4821A),
                  onTap: onConfirm,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.label,
    required this.enabled,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchCard extends StatelessWidget {
  final CardInfo card;
  final bool selected;
  final VoidCallback? onTap;
  final double w;
  final double h;

  const _PitchCard({
    required this.card,
    this.selected = false,
    this.onTap,
    this.w = 100,
    this.h = 140,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              card.timingColor.withValues(alpha: 0.6),
              const Color(0xFF1A220E),
            ],
          ),
          border: Border.all(
            color: selected ? _kGold : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
            const Spacer(),
            Text(card.directionArrow,
                style: const TextStyle(color: Colors.white, fontSize: 24)),
            Text('변화 ${card.changeAmount}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            Text(card.timingLabel,
                style: TextStyle(
                    color: card.timingColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ── Pitcher play panel (인게임과 동일: 격자 위 · 손패 하단) ─────────────────

class TutorialPitcherPanel extends StatelessWidget {
  final List<CardInfo> hand;
  final CardInfo? selectedCard;
  final int? placedStart;
  final int? revealFinal;
  final Map<String, List<int>> setupNumbers;
  final ValueChanged<CardInfo>? onSelectCard;
  final void Function(CardInfo card, int coord)? onDrop;
  final VoidCallback? onConfirmPitch;
  final TutorialAnchorKeys? anchors;

  const TutorialPitcherPanel({
    super.key,
    required this.hand,
    this.selectedCard,
    this.placedStart,
    this.revealFinal,
    this.setupNumbers = const {},
    this.onSelectCard,
    this.onDrop,
    this.onConfirmPitch,
    this.anchors,
  });

  bool get _canPitch =>
      selectedCard != null && placedStart != null && onConfirmPitch != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            const Text(
              '투구',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
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
        ),
        if (setupNumbers.isNotEmpty)
          SetupNumbersSummaryBar(setupNumbers: setupNumbers),
        if (revealFinal != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              '시작 ${placedStart ?? '-'} → 최종 $revealFinal',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            key: anchors?.pitcherGrid,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: TutorialPlayGrid(
              selectedCoord: placedStart,
              highlightFinal: revealFinal,
              startCoord: placedStart,
              showWild: false,
              onTapCoord: selectedCard == null || onDrop == null
                  ? null
                  : (n) => onDrop!(selectedCard!, n),
              onAcceptCard: onDrop,
            ),
          ),
        ),
        // 손패 — 인게임처럼 하단 부채
        SizedBox(
          key: anchors?.pitcherHand,
          height: 138,
          child: LayoutBuilder(builder: (context, constraints) {
            const cardW = 76.0;
            const cardH = 108.0;
            const spread = 58.0;
            final n = hand.length;
            if (n == 0) return const SizedBox.shrink();
            final totalW = (n - 1) * spread + cardW;
            final sx = constraints.maxWidth / 2 - totalW / 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < n; i++)
                  _fanCard(
                    index: i,
                    total: n,
                    left: sx + i * spread,
                    cardW: cardW,
                    cardH: cardH,
                    card: hand[i],
                  ),
              ],
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _canPitch ? onConfirmPitch : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: _canPitch
                        ? const LinearGradient(
                            colors: [Color(0xFFFF8C00), Color(0xFFFF5722)],
                          )
                        : null,
                    color: _canPitch
                        ? null
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '투구',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: _canPitch ? 1 : 0.35),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fanCard({
    required int index,
    required int total,
    required double left,
    required double cardW,
    required double cardH,
    required CardInfo card,
  }) {
    final mid = (total - 1) / 2.0;
    final t = index - mid;
    final sel = selectedCard?.cardId == card.cardId;
    return Positioned(
      left: left,
      bottom: t.abs() * 5.0 + (sel ? 22.0 : 0.0),
      child: Transform.rotate(
        angle: t * 0.07,
        alignment: Alignment.bottomCenter,
        child: Draggable<CardInfo>(
          data: card,
          onDragStarted:
              onSelectCard == null ? null : () => onSelectCard!(card),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: _PitchCard(card: card, selected: true, w: cardW, h: cardH),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.28,
            child: _PitchCard(card: card, w: cardW, h: cardH),
          ),
          child: GestureDetector(
            onTap: onSelectCard == null ? null : () => onSelectCard!(card),
            child: _PitchCard(
              card: card,
              selected: sel,
              w: cardW,
              h: cardH,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Batter play panel (인게임과 동일: 격자 위 · 타이밍 하단) ─────────────────

class TutorialBatterPanel extends StatelessWidget {
  final int startCoord;
  final TutorialTiming? selectedTiming;
  final int? selectedCoord;
  final Map<String, List<int>> setupNumbers;
  final ValueChanged<TutorialTiming>? onSelectTiming;
  final void Function(TutorialTiming timing, int coord)? onPlace;
  final TutorialAnchorKeys? anchors;

  const TutorialBatterPanel({
    super.key,
    required this.startCoord,
    this.selectedTiming,
    this.selectedCoord,
    this.setupNumbers = const {},
    this.onSelectTiming,
    this.onPlace,
    this.anchors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KeyedSubtree(
          key: anchors?.batterHeader,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              const Text(
                '타격',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF448AFF).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF448AFF).withValues(alpha: 0.45),
                  ),
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
          ),
        ),
        if (setupNumbers.isNotEmpty)
          SetupNumbersSummaryBar(setupNumbers: setupNumbers),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: _timerBar(),
        ),
        Expanded(
          child: Padding(
            key: anchors?.batterGrid,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: TutorialPlayGrid(
              startCoord: startCoord,
              selectedCoord: selectedCoord,
              showWild: true,
              onTapCoord: selectedTiming == null || onPlace == null
                  ? null
                  : (n) => onPlace!(selectedTiming!, n),
              acceptTiming: true,
              onAcceptTiming: onPlace,
            ),
          ),
        ),
        // 타이밍 손패 — 인게임처럼 하단 부채
        SizedBox(
          key: anchors?.batterTiming,
          height: 138,
          child: LayoutBuilder(builder: (context, constraints) {
            const timings = TutorialTiming.values;
            const cardW = 76.0;
            const cardH = 108.0;
            const spread = 52.0;
            final n = timings.length;
            final totalW = (n - 1) * spread + cardW;
            final sx = constraints.maxWidth / 2 - totalW / 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < n; i++)
                  _timingFan(
                    index: i,
                    total: n,
                    left: sx + i * spread,
                    cardW: cardW,
                    cardH: cardH,
                    timing: timings[i],
                  ),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _timingFan({
    required int index,
    required int total,
    required double left,
    required double cardW,
    required double cardH,
    required TutorialTiming timing,
  }) {
    final mid = (total - 1) / 2.0;
    final t = index - mid;
    final sel = selectedTiming == timing;
    final card = _TimingCard(timing: timing, selected: sel, w: cardW, h: cardH);
    return Positioned(
      left: left,
      bottom: t.abs() * 5.0 + (sel ? 22.0 : 0.0),
      child: Transform.rotate(
        angle: t * 0.07,
        alignment: Alignment.bottomCenter,
        child: Draggable<TutorialTiming>(
          data: timing,
          onDragStarted:
              onSelectTiming == null ? null : () => onSelectTiming!(timing),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: cardW, height: cardH, child: card),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: GestureDetector(
            onTap:
                onSelectTiming == null ? null : () => onSelectTiming!(timing),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _timerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('5.0초',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
              Text('타이밍 카드를 좌표에 놓으세요',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 1,
              minHeight: 5,
              color: _kGold,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimingCard extends StatelessWidget {
  final TutorialTiming timing;
  final bool selected;
  final double w;
  final double h;

  const _TimingCard({
    required this.timing,
    this.selected = false,
    this.w = 56,
    this.h = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: timing.color.withValues(alpha: selected ? 0.55 : 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _kGold : Colors.white24,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: Text(
        timing.label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
    );
  }
}

// ── Shared play grid ─────────────────────────────────────────────────────────

class TutorialPlayGrid extends StatelessWidget {
  final int? startCoord;
  final int? selectedCoord;
  final int? highlightFinal;
  final bool showWild;
  final ValueChanged<int>? onTapCoord;
  final void Function(CardInfo card, int coord)? onAcceptCard;
  final bool acceptTiming;
  final void Function(TutorialTiming timing, int coord)? onAcceptTiming;

  const TutorialPlayGrid({
    super.key,
    this.startCoord,
    this.selectedCoord,
    this.highlightFinal,
    this.showWild = false,
    this.onTapCoord,
    this.onAcceptCard,
    this.acceptTiming = false,
    this.onAcceptTiming,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showWild)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildCell(0, wide: true),
          ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            const gap = 4.0;
            final cellW = (c.maxWidth - gap * 4) / 5;
            final cellH = (c.maxHeight - gap * 4) / 5;
            final aspect = cellW / (cellH <= 0 ? cellW : cellH);
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 25,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                childAspectRatio: aspect > 0 ? aspect : 1,
              ),
              itemBuilder: (_, i) => _buildCell(i + 1),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCell(int n, {bool wide = false}) {
    final isStart = startCoord == n;
    final isSel = selectedCoord == n;
    final isFinal = highlightFinal == n;
    final strike = TutorialDemoData.isStrike(n);

    Color border = Colors.white24;
    Color fill = Colors.black.withValues(alpha: 0.28);
    if (strike) fill = const Color(0xFF7CFC00).withValues(alpha: 0.12);
    if (isFinal) {
      fill = const Color(0xFFFF7043).withValues(alpha: 0.3);
      border = const Color(0xFFFF7043);
    }
    if (isStart) {
      fill = const Color(0xFFBB66FF).withValues(alpha: 0.3);
      border = const Color(0xFFBB66FF);
    }
    if (isSel) {
      fill = _kGold.withValues(alpha: 0.25);
      border = _kGold;
    }

    final content = Container(
      width: wide ? double.infinity : null,
      height: wide ? 34 : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: isStart || isSel ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            n == 0 ? '0 · 폭투' : '$n',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: wide ? 12 : 13,
            ),
          ),
          if (isStart)
            const Text('시작',
                style: TextStyle(
                    color: Color(0xFFBB66FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          if (isFinal && !isStart)
            const Text('최종',
                style: TextStyle(
                    color: Color(0xFFFF7043),
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
        ],
      ),
    );

    if (onAcceptCard != null && n > 0) {
      return DragTarget<CardInfo>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => onAcceptCard!(d.data, n),
        builder: (context, cand, _) {
          final hovering = cand.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: hovering
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kGold, width: 2),
                  )
                : null,
            child: GestureDetector(
              onTap: onTapCoord == null ? null : () => onTapCoord!(n),
              child: content,
            ),
          );
        },
      );
    }

    if (acceptTiming && onAcceptTiming != null) {
      return DragTarget<TutorialTiming>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => onAcceptTiming!(d.data, n),
        builder: (context, cand, _) {
          final hovering = cand.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: hovering
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kGold, width: 2),
                  )
                : null,
            child: GestureDetector(
              onTap: onTapCoord == null ? null : () => onTapCoord!(n),
              child: content,
            ),
          );
        },
      );
    }

    if (onTapCoord != null) {
      return GestureDetector(onTap: () => onTapCoord!(n), child: content);
    }

    return content;
  }
}
