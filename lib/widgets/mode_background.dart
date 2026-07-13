import 'package:flutter/material.dart';
import '../models/game_mode.dart';

/// 게임 모드에 따라 다른 배경을 렌더링하는 공유 위젯.
///
/// - single    : bg_single.png + 하단 어두운 그라디언트 오버레이
/// - 나머지 모드 : 모드별 그라디언트 + 다이아몬드 타일 패턴
class ModeBackground extends StatelessWidget {
  final GameMode mode;
  const ModeBackground({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == GameMode.single) {
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
      child: CustomPaint(painter: _ModeBgPainter(mode)),
    );
  }
}

// ─── Gradient + tile painter ──────────────────────────────────────────────────

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
          Color(0xFF0A2040),
        ],
      GameMode.teamMini => const [
          Color(0xFF2B0D3E),
          Color(0xFF5A1A5A),
          Color(0xFF1A0D2B),
        ],
      GameMode.custom => const [
          Color(0xFF1A1A1A),
          Color(0xFF2E2E1A),
          Color(0xFF1A1A0D),
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
    // Diamond tile overlay
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
