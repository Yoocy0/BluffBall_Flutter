import 'package:flutter/material.dart';

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
