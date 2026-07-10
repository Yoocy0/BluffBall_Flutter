import 'package:flutter/material.dart';
import '../models/turn_result_event.dart';

/// 우상단 경기 정보 오버레이.
///
/// 이닝, B-S-O 카운트, 주자, 스코어, 현재 투수/타자 userId를 표시합니다.
/// [lastResult] 가 null 이면 초기값(1회 초, 0-0, 0:0)으로 표시합니다.
///
/// B: 최대 3 (4번째면 볼넷 처리됨)
/// S: 최대 2 (3번째면 삼진)
/// O: 최대 2 (3번째면 이닝 종료)
class MatchInfoOverlay extends StatelessWidget {
  final TurnResultEvent? lastResult;
  final int currentUserId;
  final int initialPitcherUserId;

  const MatchInfoOverlay({
    super.key,
    required this.currentUserId,
    required this.initialPitcherUserId,
    this.lastResult,
  });

  @override
  Widget build(BuildContext context) {
    final ev = lastResult;

    final inning       = ev?.inning ?? 1;
    final isTop        = ev?.isTop ?? true;
    final homeScore    = ev?.homeScore ?? 0;
    final awayScore    = ev?.awayScore ?? 0;
    final balls        = (ev?.balls ?? 0).clamp(0, 3);
    final strikes      = (ev?.strikes ?? 0).clamp(0, 2);
    final outs         = (ev?.outs ?? 0).clamp(0, 2);
    final first        = ev?.firstBase ?? false;
    final second       = ev?.secondBase ?? false;
    final third        = ev?.thirdBase ?? false;
    final pitcherUserId = ev?.pitcherUserId ?? initialPitcherUserId;
    final amIPitcher   = pitcherUserId == currentUserId;

    return Container(
      width: 158,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 이닝 + 스코어 ─────────────────────────────────────────
          Row(children: [
            Text(
              '$inning회 ${isTop ? '초' : '말'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              '$homeScore : $awayScore',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.80),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 6),

          // ── B · S · O ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _countDots('B', balls,   3, const Color(0xFF64B5F6)),
              _countDots('S', strikes, 2, const Color(0xFFFFD740)),
              _countDots('O', outs,    2, const Color(0xFFFF5252)),
            ],
          ),
          const SizedBox(height: 7),

          // ── 주자 ──────────────────────────────────────────────────
          Row(children: [
            Text(
              '주자',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            _BaseDiamond(first: first, second: second, third: third),
          ]),
          const SizedBox(height: 6),

          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
          const SizedBox(height: 6),

          // ── 투수 / 타자 ───────────────────────────────────────────
          _roleRow(
            label: '투수',
            isMe: amIPitcher,
            color: const Color(0xFFFF7043),
          ),
          const SizedBox(height: 3),
          _roleRow(
            label: '타자',
            isMe: !amIPitcher,
            color: const Color(0xFF42A5F5),
          ),
        ],
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Widget _countDots(String label, int count, int max, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Row(
          children: List.generate(max, (i) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count ? color : color.withValues(alpha: 0.15),
              boxShadow: i < count
                  ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 4)]
                  : null,
            ),
          )),
        ),
      ],
    );
  }

  Widget _roleRow({
    required String label,
    required bool isMe,
    required Color color,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        isMe ? '나' : '상대',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.white.withValues(alpha: 0.50),
          fontSize: 10,
          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ]);
  }
}

// ─── Base diamond widget ──────────────────────────────────────────────────────

class _BaseDiamond extends StatelessWidget {
  final bool first;
  final bool second;
  final bool third;

  const _BaseDiamond({
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  Widget build(BuildContext context) {
    const size = 10.0;
    const gap  = 3.0;
    const on   = Color(0xFFFFD740);
    const off  = Colors.white24;

    return SizedBox(
      width: size * 3 + gap * 2 + 4,
      height: size * 2 + gap + 2,
      child: Stack(children: [
        // 2루 (위 중앙)
        Positioned(
          top: 0,
          left: size + gap,
          child: _dot(second, size, on, off),
        ),
        // 3루 (아래 좌)
        Positioned(
          bottom: 0,
          left: 0,
          child: _dot(third, size, on, off),
        ),
        // 1루 (아래 우)
        Positioned(
          bottom: 0,
          right: 0,
          child: _dot(first, size, on, off),
        ),
      ]),
    );
  }

  Widget _dot(bool occ, double size, Color on, Color off) => Transform.rotate(
        angle: 0.785, // 45°
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: occ ? on : off,
            borderRadius: BorderRadius.circular(2),
            boxShadow: occ
                ? [BoxShadow(color: on.withValues(alpha: 0.60), blurRadius: 5)]
                : null,
          ),
        ),
      );
}
