import 'package:flutter/material.dart';

import 'card_info.dart';

/// GET /api/v1/users/me/pitch-cards · enhance 응답.
class UserPitchCard {
  final int userPitchCardId;
  final int cardId;
  final String name;
  final String direction;
  final int baseChangeAmount;
  final int effectiveChangeAmount;
  final bool changeAmountEnhanced;
  final String baseTiming;
  final String effectiveTiming;
  final String timingEnhancement;
  final int cost;

  const UserPitchCard({
    required this.userPitchCardId,
    required this.cardId,
    required this.name,
    required this.direction,
    required this.baseChangeAmount,
    required this.effectiveChangeAmount,
    required this.changeAmountEnhanced,
    required this.baseTiming,
    required this.effectiveTiming,
    required this.timingEnhancement,
    required this.cost,
  });

  String get displayName => CardInfo.shortPitchName(name);

  String get directionArrow => CardInfo.directionArrowFor(direction);

  String get timingLabel => CardInfo.timingLabelFor(effectiveTiming);

  Color get timingColor => CardInfo.timingColorFor(effectiveTiming);

  bool get timingEnhanced =>
      timingEnhancement.toUpperCase() != 'NONE' &&
      timingEnhancement.isNotEmpty;

  /// 변화량·타이밍 중 하나라도 강화된 경우 (되돌리기 가능).
  bool get isEnhanced => changeAmountEnhanced || timingEnhanced;

  factory UserPitchCard.fromJson(Map<String, dynamic> json) => UserPitchCard(
        userPitchCardId: (json['userPitchCardId'] as num).toInt(),
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        direction: json['direction'] as String? ?? '',
        baseChangeAmount: (json['baseChangeAmount'] as num?)?.toInt() ?? 0,
        effectiveChangeAmount:
            (json['effectiveChangeAmount'] as num?)?.toInt() ?? 0,
        changeAmountEnhanced: json['changeAmountEnhanced'] as bool? ?? false,
        baseTiming: json['baseTiming'] as String? ?? '',
        effectiveTiming: json['effectiveTiming'] as String? ?? '',
        timingEnhancement: json['timingEnhancement'] as String? ?? 'NONE',
        cost: (json['cost'] as num?)?.toInt() ?? 1,
      );
}
