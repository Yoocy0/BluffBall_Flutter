import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Dice face painter ────────────────────────────────────────────────────────

/// 주사위 한 면을 그리는 CustomPainter.
/// [value] 는 1~6, [pipColor] 는 눈 색상, [faceColor] 는 배경색.
class DicePainter extends CustomPainter {
  final int value;
  final Color faceColor;
  final Color pipColor;
  final Color borderColor;
  final double borderRadius;
  final double elevation;

  const DicePainter({
    required this.value,
    this.faceColor = Colors.white,
    this.pipColor = const Color(0xFF1A1A2E),
    this.borderColor = const Color(0xFFE0E0E0),
    this.borderRadius = 14.0,
    this.elevation = 6.0,
  });

  // pip 중심 좌표 (단위: 0~1, 패딩 포함)
  static const _pipLayouts = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.5, 0.25), Offset(0.5, 0.75)],
    3: [Offset(0.5, 0.25), Offset(0.5, 0.5), Offset(0.5, 0.75)],
    4: [
      Offset(0.25, 0.25), Offset(0.75, 0.25),
      Offset(0.25, 0.75), Offset(0.75, 0.75),
    ],
    5: [
      Offset(0.25, 0.25), Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75), Offset(0.75, 0.75),
    ],
    6: [
      Offset(0.25, 0.20), Offset(0.75, 0.20),
      Offset(0.25, 0.50), Offset(0.75, 0.50),
      Offset(0.25, 0.80), Offset(0.75, 0.80),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = borderRadius;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // 그림자
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, elevation);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0, elevation * 0.5),
        Radius.circular(r),
      ),
      shadow,
    );

    // 배경
    canvas.drawRRect(rRect, Paint()..color = faceColor);

    // 테두리
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // pips
    final pips = _pipLayouts[value.clamp(1, 6)] ?? [];
    final pipR = size.width * 0.085;
    final pipPaint = Paint()..color = pipColor;

    for (final rel in pips) {
      final center = Offset(rel.dx * size.width, rel.dy * size.height);
      // pip 그림자
      canvas.drawCircle(
        center.translate(0, 1),
        pipR,
        Paint()..color = pipColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(center, pipR, pipPaint);
    }
  }

  @override
  bool shouldRepaint(DicePainter old) =>
      old.value != value || old.faceColor != faceColor;
}

// ─── Dice widget ──────────────────────────────────────────────────────────────

/// 단일 주사위 위젯.
///
/// [value] 1~6. [size] 한 변의 길이(정사각형).
class DiceWidget extends StatelessWidget {
  final int value;
  final double size;
  final Color faceColor;
  final Color pipColor;

  const DiceWidget({
    super.key,
    required this.value,
    this.size = 80.0,
    this.faceColor = Colors.white,
    this.pipColor = const Color(0xFF1A1A2E),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DicePainter(
          value: value.clamp(1, 6),
          faceColor: faceColor,
          pipColor: pipColor,
        ),
      ),
    );
  }
}

// ─── Throwing animation ───────────────────────────────────────────────────────

/// 주사위 1~2개를 우측에서 던져 포물선으로 날아와 착지하는 애니메이션 위젯.
///
/// [diceCount]  : 1 또는 2.
/// [diceValues] : 최종 주사위 눈 목록 (길이 == diceCount).
/// [onLanded]   : 모든 주사위가 착지 완료된 후 콜백.
class DiceThrowWidget extends StatefulWidget {
  final int diceCount;
  final List<int> diceValues;
  final VoidCallback? onLanded;
  final double diceSize;

  const DiceThrowWidget({
    super.key,
    required this.diceCount,
    required this.diceValues,
    this.onLanded,
    this.diceSize = 72.0,
  }) : assert(diceCount >= 1 && diceCount <= 2);

  @override
  State<DiceThrowWidget> createState() => _DiceThrowWidgetState();
}

class _DiceThrowWidgetState extends State<DiceThrowWidget>
    with TickerProviderStateMixin {
  // 각 주사위당 컨트롤러 2개: 비행 + 회전
  late final List<AnimationController> _flyCtrl;
  late final List<AnimationController> _rotCtrl;
  late final List<Animation<double>> _xAnim;
  late final List<Animation<double>> _yAnim;
  late final List<Animation<double>> _rotAnim;
  late final List<Animation<double>> _scaleAnim;

  // 착지 중 보여줄 눈 (비행 중에는 랜덤하게 바뀜)
  late final List<ValueNotifier<int>> _displayValue;

  final _rng = math.Random();
  int _landedCount = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.diceCount;
    _flyCtrl = List.generate(n, (i) => AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 700 + i * 180),
        ));
    _rotCtrl = List.generate(n, (i) => AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 650 + i * 180),
        ));
    _displayValue = List.generate(
        n, (i) => ValueNotifier<int>(widget.diceValues[i]));

    _xAnim = List.generate(n, (i) {
      // 우측에서 날아와 중앙 근처에 착지
      // i=0 왼쪽, i=1 오른쪽으로 약간 분리
      final targetX = n == 1 ? 0.0 : (i == 0 ? -50.0 : 50.0);
      return Tween<double>(begin: 340.0, end: targetX).animate(
        CurvedAnimation(parent: _flyCtrl[i], curve: Curves.easeOutCubic),
      );
    });

    _yAnim = List.generate(n, (i) {
      // 포물선: 위로 살짝 올랐다 떨어지며 바운스
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: -80.0, end: 60.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 60.0, end: -20.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: -20.0, end: 8.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 13,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 8.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 12,
        ),
      ]).animate(_flyCtrl[i]);
    });

    _rotAnim = List.generate(n, (i) {
      // 비행 중 2.5바퀴 회전 → 착지 후 마지막 0.1바퀴 정렬
      return Tween<double>(begin: 0.0, end: math.pi * 5.0).animate(
        CurvedAnimation(parent: _rotCtrl[i], curve: Curves.easeOutCubic),
      );
    });

    _scaleAnim = List.generate(n, (i) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.7, end: 1.1),
          weight: 70,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.1, end: 1.0),
          weight: 30,
        ),
      ]).animate(
        CurvedAnimation(parent: _flyCtrl[i], curve: Curves.easeOut),
      );
    });

    // 각 주사위 비행 시작 (두 번째는 약간 늦게)
    for (int i = 0; i < n; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (!mounted) return;
        _startThrow(i);
      });
    }
  }

  void _startThrow(int i) {
    // 비행 중 눈을 랜덤하게 바꿔 텀블링 효과
    _tickFace(i);
    _flyCtrl[i].forward().then((_) {
      if (!mounted) return;
      // 착지: 최종 값으로 고정
      _displayValue[i].value = widget.diceValues[i];
      setState(() {}); // 착지 효과
      _landedCount++;
      if (_landedCount == widget.diceCount) {
        widget.onLanded?.call();
      }
    });
    _rotCtrl[i].forward();
  }

  void _tickFace(int i) {
    if (!mounted) return;
    if (_flyCtrl[i].isCompleted) return;
    _displayValue[i].value = _rng.nextInt(6) + 1;
    // 비행 진행률에 따라 전환 속도 감소
    final progress = _flyCtrl[i].value;
    final delay = (60 + (progress * 120)).round();
    Future.delayed(Duration(milliseconds: delay), () => _tickFace(i));
  }

  @override
  void dispose() {
    for (final c in _flyCtrl) {
      c.dispose();
    }
    for (final c in _rotCtrl) {
      c.dispose();
    }
    for (final v in _displayValue) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.diceCount;
    return SizedBox(
      width: 220,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < n; i++) _buildDie(i),
        ],
      ),
    );
  }

  Widget _buildDie(int i) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flyCtrl[i], _rotCtrl[i]]),
      builder: (_, __) {
        final x = _xAnim[i].value;
        final y = _yAnim[i].value;
        final rot = _rotAnim[i].value;
        final scale = _scaleAnim[i].value;

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rot,
              child: ValueListenableBuilder<int>(
                valueListenable: _displayValue[i],
                builder: (_, val, __) => DiceWidget(
                  value: val,
                  size: widget.diceSize,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
