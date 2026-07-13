import 'dart:math' as math;

import 'package:flutter/material.dart';

const _kGold = Color(0xFFFFD700);
const _kPanelBorder = Color(0xFF5A6E30);

/// 메인 화면 패널 크기 계산 (Hero 전환 시 동일 크기 유지용)
class BoardGameBoxLayout {
  static const mainPadding = EdgeInsets.fromLTRB(20, 32, 20, 32);
  static const mainHeightFactor = 0.88;

  static Size mainPanelSize(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final screenW = media.size.width;

    const topBarH = 58.0;
    const bottomNavH = 72.0;
    const bottomGapH = 8.0;
    const matchButtonsH = 88.0;

    final expandedH = screenH
        - media.padding.top
        - media.padding.bottom
        - topBarH
        - matchButtonsH
        - bottomGapH
        - bottomNavH;

    final innerW = screenW - mainPadding.horizontal;
    final innerH = expandedH - mainPadding.vertical;

    return Size(innerW, innerH * mainHeightFactor);
  }
}

class BoardGameBox extends StatelessWidget {
  static const heroTag = 'board-game-box';

  final EdgeInsets padding;
  final double heightFactor;
  final Size? lockedPanelSize;
  final String? heroTagOverride;

  const BoardGameBox({
    super.key,
    this.padding = BoardGameBoxLayout.mainPadding,
    this.heightFactor = BoardGameBoxLayout.mainHeightFactor,
    this.lockedPanelSize,
    this.heroTagOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelSize = lockedPanelSize ??
                Size(
                  constraints.maxWidth,
                  constraints.maxHeight * heightFactor,
                );

            final panel = SizedBox(
              width: panelSize.width,
              height: panelSize.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: const _BoardGamePanelPainter(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Image.asset(
                      'assets/images/board_game_box.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            );

            final heroChild = heroTagOverride != null
                ? Hero(
                    tag: heroTagOverride!,
                    createRectTween: _createRectTween,
                    flightShuttleBuilder: _buildFlightShuttle,
                    child: Material(
                      type: MaterialType.transparency,
                      child: panel,
                    ),
                  )
                : panel;

            return heroChild;
          },
        ),
      ),
    );
  }

  /// 전환 중 메인 화면 패널 크기를 유지하고 위치만 이동
  static Tween<Rect?> _createRectTween(Rect? begin, Rect? end) {
    if (begin == null || end == null) {
      return RectTween(begin: begin, end: end);
    }
    final size = begin.size;
    return RectTween(
      begin: begin,
      end: Rect.fromCenter(
        center: end.center,
        width: size.width,
        height: size.height,
      ),
    );
  }

  static Widget _buildFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final shuttle = flightDirection == HeroFlightDirection.push
        ? fromHeroContext.widget
        : toHeroContext.widget;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(animation.value);
        final floatY = -math.sin(t * math.pi) * 16;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: child,
        );
      },
      child: shuttle,
    );
  }
}

class _BoardGamePanelPainter extends CustomPainter {
  const _BoardGamePanelPainter();

  static const _radius = 20.0;
  static const _glowDepth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2810), Color(0xFF2D3A15), Color(0xFF3A2208)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    void drawEdgeGlow({
      required Alignment begin,
      required Alignment end,
      required Rect glowRect,
    }) {
      canvas.drawRect(
        glowRect,
        Paint()
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: [
              _kGold.withValues(alpha: 0.28),
              _kGold.withValues(alpha: 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 1.0],
          ).createShader(glowRect),
      );
    }

    drawEdgeGlow(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      glowRect: Rect.fromLTWH(0, 0, size.width, _glowDepth),
    );
    drawEdgeGlow(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      glowRect: Rect.fromLTWH(0, size.height - _glowDepth, size.width, _glowDepth),
    );
    drawEdgeGlow(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      glowRect: Rect.fromLTWH(0, 0, _glowDepth, size.height),
    );
    drawEdgeGlow(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      glowRect: Rect.fromLTWH(size.width - _glowDepth, 0, _glowDepth, size.height),
    );

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _kPanelBorder.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
