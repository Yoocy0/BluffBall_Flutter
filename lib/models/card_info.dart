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

  // ── Direction → 화살표 ──────────────────────────────────────────────────

  String get directionArrow => switch (direction.toUpperCase()) {
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

  String get timingLabel => switch (timing.toUpperCase()) {
        'EARLY' => '이른',
        'NORMAL' => '보통',
        'LATE' => '늦은',
        _ => timing,
      };

  Color get timingColor => switch (timing.toUpperCase()) {
        'EARLY' => const Color(0xFF4CAF50),
        'LATE' => const Color(0xFFFF5252),
        _ => const Color(0xFFFFB300),
      };

  // ── JSON ───────────────────────────────────────────────────────────────

  factory CardInfo.fromJson(Map<String, dynamic> json) => CardInfo(
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String,
        changeAmount: (json['changeAmount'] as num).toInt(),
        direction: json['direction'] as String,
        timing: json['timing'] as String,
      );
}
