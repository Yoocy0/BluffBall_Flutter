import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 설명 대상 영역.
enum TutorialSpotlight {
  none,
  setupSummary,
  setupDefense,
  setupOffense,
  setupStepChip,
  setupGrid,
  pitchHand,
  pitchActions,
  pitcherHand,
  pitcherGrid,
  batterHeader,
  batterGrid,
  batterTiming,
}

/// 패널에 붙이는 GlobalKey 묶음.
class TutorialAnchorKeys {
  final summary = GlobalKey();
  final defense = GlobalKey();
  final offense = GlobalKey();
  final stepChip = GlobalKey();
  final numberGrid = GlobalKey();
  final pitchHand = GlobalKey();
  final pitchActions = GlobalKey();
  final pitcherHand = GlobalKey();
  final pitcherGrid = GlobalKey();
  final batterHeader = GlobalKey();
  final batterGrid = GlobalKey();
  final batterTiming = GlobalKey();

  GlobalKey? keyFor(TutorialSpotlight spot) => switch (spot) {
        TutorialSpotlight.setupSummary => summary,
        TutorialSpotlight.setupDefense => defense,
        TutorialSpotlight.setupOffense => offense,
        TutorialSpotlight.setupStepChip => stepChip,
        TutorialSpotlight.setupGrid => numberGrid,
        TutorialSpotlight.pitchHand => pitchHand,
        TutorialSpotlight.pitchActions => pitchActions,
        TutorialSpotlight.pitcherHand => pitcherHand,
        TutorialSpotlight.pitcherGrid => pitcherGrid,
        TutorialSpotlight.batterHeader => batterHeader,
        TutorialSpotlight.batterGrid => batterGrid,
        TutorialSpotlight.batterTiming => batterTiming,
        TutorialSpotlight.none => null,
      };
}

/// 인게임 위 코치 레이어.
///
/// - 설명 모드: 대상만 뚫린 딤 + 옆 말풍선 + 화살표. 탭하면 다음.
/// - 실습 모드: 딤 없음(화면 밝음) + 상단 얇은 안내만.
class TutorialCoachLayer extends StatefulWidget {
  final String text;
  final String? badge;
  final bool interactive;
  final VoidCallback? onTapAdvance;
  final TutorialSpotlight spotlight;
  final TutorialAnchorKeys anchors;

  const TutorialCoachLayer({
    super.key,
    required this.text,
    required this.anchors,
    this.badge,
    this.interactive = false,
    this.onTapAdvance,
    this.spotlight = TutorialSpotlight.none,
  });

  @override
  State<TutorialCoachLayer> createState() => _TutorialCoachLayerState();
}

class _TutorialCoachLayerState extends State<TutorialCoachLayer> {
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant TutorialCoachLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotlight != widget.spotlight ||
        oldWidget.text != widget.text ||
        oldWidget.interactive != widget.interactive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted || widget.interactive) return;
    final key = widget.anchors.keyFor(widget.spotlight);
    final rect = _globalRect(key);
    if (rect != _hole) setState(() => _hole = rect);
  }

  Rect? _globalRect(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return (offset & box.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.interactive) {
      return _PracticeBanner(text: widget.text, badge: widget.badge);
    }

    final media = MediaQuery.of(context);
    final safe = media.padding;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTapAdvance,
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _SpotlightPainter(
            hole: _hole,
            dimColor: Colors.black.withValues(alpha: 0.62),
          ),
          child: Stack(
            children: [
              if (_hole != null)
                _Callout(
                  hole: _hole!,
                  text: widget.text,
                  badge: widget.badge,
                  screenSize: media.size,
                  safeTop: safe.top,
                  safeBottom: safe.bottom,
                )
              else
                Positioned(
                  left: 16,
                  right: 16,
                  top: safe.top + 56,
                  child: _Bubble(
                    text: widget.text,
                    badge: widget.badge,
                    showTapHint: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeBanner extends StatelessWidget {
  final String text;
  final String? badge;

  const _PracticeBanner({required this.text, this.badge});

  @override
  Widget build(BuildContext context) {
    // 딤 없음 — 터치 통과, 상단 SafeArea 안에만 안내
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _Bubble(
              text: text,
              badge: badge ?? '실습',
              showTapHint: false,
              compact: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  final Rect hole;
  final String text;
  final String? badge;
  final Size screenSize;
  final double safeTop;
  final double safeBottom;

  const _Callout({
    required this.hole,
    required this.text,
    required this.screenSize,
    required this.safeTop,
    required this.safeBottom,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const bubbleW = 220.0;
    final preferRight = hole.center.dx < screenSize.width * 0.45;
    final topMin = safeTop + 8;
    final topMax = screenSize.height - safeBottom - 160;

    double bubbleLeft;
    if (preferRight) {
      bubbleLeft = (hole.right + 14).clamp(12.0, screenSize.width - bubbleW - 12);
      // 오른쪽에 공간 부족하면 왼쪽
      if (hole.right + 14 + bubbleW > screenSize.width - 8) {
        bubbleLeft = (hole.left - bubbleW - 14).clamp(12.0, screenSize.width - bubbleW - 12);
      }
    } else {
      bubbleLeft = (hole.left - bubbleW - 14).clamp(12.0, screenSize.width - bubbleW - 12);
      if (hole.left - 14 - bubbleW < 8) {
        bubbleLeft = (hole.right + 14).clamp(12.0, screenSize.width - bubbleW - 12);
      }
    }

    var bubbleTop = (hole.center.dy - 48).clamp(topMin, topMax);
    // 구멍과 너무 겹치면 위/아래로
    final bubbleRect = Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleW, 120);
    if (bubbleRect.overlaps(hole.inflate(8))) {
      if (hole.bottom + 12 < topMax) {
        bubbleTop = hole.bottom + 12;
      } else {
        bubbleTop = (hole.top - 130).clamp(topMin, topMax);
      }
    }

    final bubbleAnchor = Offset(bubbleLeft + bubbleW / 2, bubbleTop + 40);
    final toward = bubbleAnchor - hole.center;
    final holeEdge = _edgePoint(hole, toward);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ArrowPainter(from: holeEdge, to: bubbleAnchor),
          ),
        ),
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleW,
          child: _Bubble(
            text: text,
            badge: badge,
            showTapHint: true,
          ),
        ),
        // 하이라이트 테두리
        Positioned(
          left: hole.left,
          top: hole.top,
          width: hole.width,
          height: hole.height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Offset _edgePoint(Rect r, Offset dir) {
    if (dir.distance < 0.1) return r.center;
    final n = dir / dir.distance;
    // ray from center
    final dx = n.dx == 0 ? 1e9 : (n.dx > 0 ? r.right - r.center.dx : r.left - r.center.dx) / n.dx;
    final dy = n.dy == 0 ? 1e9 : (n.dy > 0 ? r.bottom - r.center.dy : r.top - r.center.dy) / n.dy;
    final t = math.min(dx.abs(), dy.abs());
    return r.center + n * t;
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final Color dimColor;

  _SpotlightPainter({required this.hole, required this.dimColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (hole != null) {
      path.addRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(12)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = dimColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.hole != hole || old.dimColor != dimColor;
}

class _ArrowPainter extends CustomPainter {
  final Offset from;
  final Offset to;

  _ArrowPainter({required this.from, required this.to});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(from, to, paint);

    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const head = 10.0;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - head * math.cos(angle - 0.4),
        to.dy - head * math.sin(angle - 0.4),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - head * math.cos(angle + 0.4),
        to.dy - head * math.sin(angle + 0.4),
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.from != from || old.to != to;
}

class _Bubble extends StatelessWidget {
  final String text;
  final String? badge;
  final bool showTapHint;
  final bool compact;

  const _Bubble({
    required this.text,
    this.badge,
    this.showTapHint = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, compact ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A220E).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_rounded,
                    color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    badge ?? '튜토리얼',
                    style: TextStyle(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.95),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (showTapHint)
                  Text(
                    '탭',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: compact ? 13 : 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
