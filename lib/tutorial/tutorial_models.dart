import 'package:flutter/material.dart';

/// 완료 보상으로 고를 수 있는 변화구 (포심은 자동 지급).
enum TutorialRewardPitch {
  curve(
    key: 'CURVE',
    name: '커브',
    direction: 'DOWN',
    timing: 'LATE',
    changeAmount: 3,
    accent: Color(0xFF7B68EE),
  ),
  slider(
    key: 'SLIDER',
    name: '슬라이더',
    direction: 'SIDE',
    timing: 'EARLY',
    changeAmount: 3,
    accent: Color(0xFF42A5F5),
  ),
  fork(
    key: 'FORK',
    name: '포크',
    direction: 'DOWN',
    timing: 'LATE',
    changeAmount: 4,
    accent: Color(0xFFFF7043),
  );

  final String key;
  final String name;
  final String direction;
  final String timing;
  final int changeAmount;
  final Color accent;

  const TutorialRewardPitch({
    required this.key,
    required this.name,
    required this.direction,
    required this.timing,
    required this.changeAmount,
    required this.accent,
  });
}

/// 타자 타이밍 (실전 5슬롯).
enum TutorialTiming {
  tooEarly('너무\n이른', 'TOO_EARLY', Color(0xFF7B68EE)),
  early('이른', 'EARLY', Color(0xFF4CAF50)),
  normal('보통', 'NORMAL', Color(0xFFFFB300)),
  late('늦은', 'LATE', Color(0xFFFF7043)),
  tooLate('너무\n늦은', 'TOO_LATE', Color(0xFFEF5350));

  final String label;
  final String apiValue;
  final Color color;
  const TutorialTiming(this.label, this.apiValue, this.color);
}
