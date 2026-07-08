import 'package:flutter/material.dart';

class BluffBallLogo extends StatelessWidget {
  final double size;

  const BluffBallLogo({this.size = 210, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StrokedText(
          'BLUFF',
          fontSize: size * 0.195,
          fillColor: Colors.white,
          strokeColor: const Color(0xFF5C2A00),
          strokeWidth: size * 0.040,
          letterSpacing: size * 0.012,
        ),
        SizedBox(height: size * 0.008),
        _StrokedText(
          'BALL',
          fontSize: size * 0.245,
          fillColor: Colors.white,
          strokeColor: const Color(0xFF5C2A00),
          strokeWidth: size * 0.040,
          letterSpacing: size * 0.012,
        ),
      ],
    );
  }
}

// ─── Outlined text widget ─────────────────────────────────────────────────────

class _StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double letterSpacing;

  const _StrokedText(
    this.text, {
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: 1.0,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor
              ..strokeJoin = StrokeJoin.round,
          ),
        ),
        Text(
          text,
          style: baseStyle.copyWith(color: fillColor),
        ),
      ],
    );
  }
}
