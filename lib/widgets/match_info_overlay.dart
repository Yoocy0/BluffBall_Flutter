import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/turn_result_event.dart';

/// 우상단 경기 정보 스코어보드 (컴팩트).
///
/// [AWAY/HOME + 점수] | [이닝+▲▼ / 볼-스트] | [◇베이스 + ●○아웃]
/// P 투수명(1줄)
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

    final inning = ev?.inning ?? 1;
    final isTop = ev?.isTop ?? true;
    final awayScore = ev?.awayScore ?? 0;
    final homeScore = ev?.homeScore ?? 0;
    final balls = (ev?.balls ?? 0).clamp(0, 3);
    final strikes = (ev?.strikes ?? 0).clamp(0, 2);
    final outs = (ev?.outs ?? 0).clamp(0, 2);
    final first = ev?.firstBase ?? false;
    final second = ev?.secondBase ?? false;
    final third = ev?.thirdBase ?? false;
    final pitcherUserId = ev?.pitcherUserId ?? initialPitcherUserId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildScores(awayScore, homeScore),
                _vDiv(),
                _buildInningAndCount(inning, isTop, balls, strikes),
                _vDiv(),
                _buildBasesAndOuts(first, second, third, outs),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 3),
          _buildPitcherLine(pitcherUserId),
        ],
      ),
    );
  }

  Widget _buildScores(int awayScore, int homeScore) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _teamScoreRow('AWAY', awayScore),
        const SizedBox(height: 2),
        _teamScoreRow('HOME', homeScore),
      ],
    );
  }

  Widget _teamScoreRow(String label, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningAndCount(int inning, bool isTop, int balls, int strikes) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$inning',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 2),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _inningTriangle(up: true, active: isTop),
                const SizedBox(height: 1),
                _inningTriangle(up: false, active: !isTop),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$balls-$strikes',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _inningTriangle({required bool up, required bool active}) {
    return CustomPaint(
      size: const Size(7, 5),
      painter: _TrianglePainter(
        up: up,
        color: active
            ? const Color(0xFFFF1744)
            : Colors.white.withValues(alpha: 0.20),
      ),
    );
  }

  Widget _buildBasesAndOuts(
    bool first,
    bool second,
    bool third,
    int outs,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreboardBases(first: first, second: second, third: third),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _outCircle(outs >= 1),
            const SizedBox(width: 3),
            _outCircle(outs >= 2),
          ],
        ),
      ],
    );
  }

  Widget _outCircle(bool filled) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? const Color(0xFFFF1744) : Colors.transparent,
        border: Border.all(
          color: filled
              ? const Color(0xFFFF1744)
              : Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
    );
  }

  Widget _buildPitcherLine(int pitcherUserId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'User$pitcherUserId',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _vDiv() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final bool up;
  final Color color;

  _TrianglePainter({required this.up, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (up) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.up != up || oldDelegate.color != color;
}

class _ScoreboardBases extends StatelessWidget {
  final bool first;
  final bool second;
  final bool third;

  const _ScoreboardBases({
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  Widget build(BuildContext context) {
    const size = 7.0;
    const gap = 2.0;

    return SizedBox(
      width: size * 3 + gap * 2 + 2,
      height: size * 2 + gap + 2,
      child: Stack(children: [
        Positioned(
          top: 0,
          left: size + gap,
          child: _baseDot(second, size),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: _baseDot(third, size),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _baseDot(first, size),
        ),
      ]),
    );
  }

  Widget _baseDot(bool occupied, double size) {
    const on = Color(0xFFFFD700);
    const off = Color(0xFF455A64);
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: occupied ? on : off,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
