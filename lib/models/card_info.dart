import 'package:flutter/material.dart';

/// 백엔드 CardInfo record 대응 모델.
///
/// direction : ChangeDirection enum name (예: "DOWN", "DOWN_LEFT" …)
/// timing    : Timing enum name (예: "EARLY", "NORMAL", "LATE")
class CardInfo {
  final int cardId;
  final String name;
  final int changeAmount;
  final String direction;
  final String timing;

  const CardInfo({
    required this.cardId,
    required this.name,
    required this.changeAmount,
    required this.direction,
    required this.timing,
  });

  /// UI 표시용. 「포심 패스트볼」→「포심」처럼 끝의 「패스트볼」은 뺀다.
  String get displayName => shortPitchName(name);

  /// 「OO 패스트볼」/「OO패스트볼」이면 앞부분만, 그 외는 그대로.
  static String shortPitchName(String name) {
    final trimmed = name.trim();
    final stripped =
        trimmed.replaceFirst(RegExp(r'\s*패스트볼\s*$'), '').trim();
    return stripped.isEmpty ? trimmed : stripped;
  }

  // ── Direction → 화살표 ──────────────────────────────────────────────────

  String get directionArrow => directionArrowFor(direction);

  static String directionArrowFor(String direction) =>
      switch (direction.toUpperCase()) {
        'UP' => '↑',
        'DOWN' => '↓',
        'SIDE' => '→',
        'REVERSE' => '←',
        'LEFT' => '←',
        'RIGHT' => '→',
        'UP_LEFT' => '↖',
        'UP_RIGHT' => '↗',
        'DOWN_LEFT' => '↙',
        'DOWN_RIGHT' => '↘',
        'STRAIGHT' || 'CENTER' || 'NONE' => '→',
        _ => direction,
      };

  // ── Timing → 한국어 ────────────────────────────────────────────────────

  String get timingLabel => timingLabelFor(timing);

  static String timingLabelFor(String timing) =>
      switch (timing.toUpperCase()) {
        'EARLY' || 'FAST' || 'FASTER' || 'TOO_EARLY' => '이른',
        'NORMAL' => '보통',
        'LATE' || 'SLOW' || 'SLOWER' || 'TOO_LATE' => '늦은',
        _ => timing,
      };

  Color get timingColor => timingColorFor(timing);

  static Color timingColorFor(String timing) =>
      switch (timing.toUpperCase()) {
        'EARLY' || 'FAST' || 'FASTER' || 'TOO_EARLY' =>
          const Color(0xFF4CAF50),
        'LATE' || 'SLOW' || 'SLOWER' || 'TOO_LATE' =>
          const Color(0xFFFF5252),
        _ => const Color(0xFFFFB300),
      };

  // ── JSON ───────────────────────────────────────────────────────────────

  factory CardInfo.fromJson(Map<String, dynamic> json) => CardInfo(
        cardId: (json['cardId'] as num?)?.toInt() ??
            (json['id'] as num?)?.toInt() ??
            0,
        name: json['name'] as String? ?? '',
        changeAmount: (json['changeAmount'] as num?)?.toInt() ??
            (json['baseChangeAmount'] as num?)?.toInt() ??
            0,
        direction: json['direction'] as String? ?? '',
        timing: (json['timing'] as String?) ??
            (json['baseTiming'] as String?) ??
            '',
      );
}
