import 'package:flutter/material.dart';

/// 투수의 구종 카드 데이터.
///
/// 백엔드에서 실제 카드 목록을 수신하면 [fromJson]으로 파싱.
class PitchCardData {
  final String id;

  /// 구종 이름 (예: "포심 패스트볼")
  final String name;

  /// 공의 이동 방향 유니코드 화살표 (예: "↓" "↘" "↙")
  final String direction;

  /// 변화량 (-3 ~ +3, 0은 직구)
  final int change;

  /// 타이밍 ("이른" | "보통" | "늦은")
  final String timing;

  const PitchCardData({
    required this.id,
    required this.name,
    required this.direction,
    required this.change,
    required this.timing,
  });

  // ── Derived helpers ─────────────────────────────────────────────────────

  Color get timingColor => switch (timing) {
        '이른' => const Color(0xFF4CAF50),  // 초록: 투수 유리
        '늦은' => const Color(0xFFFF5252),  // 빨강: 타자 유리
        _ => const Color(0xFFFFB300),        // 노랑: 보통
      };

  String get changeLabel =>
      change == 0 ? '±0' : (change > 0 ? '+$change' : '$change');

  // ── Serialization ───────────────────────────────────────────────────────

  factory PitchCardData.fromJson(Map<String, dynamic> json) => PitchCardData(
        id: json['id'] as String,
        name: json['name'] as String,
        direction: json['direction'] as String,
        change: json['change'] as int,
        timing: json['timing'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'direction': direction,
        'change': change,
        'timing': timing,
      };

  PitchCardData copyWith({
    String? id,
    String? name,
    String? direction,
    int? change,
    String? timing,
  }) =>
      PitchCardData(
        id: id ?? this.id,
        name: name ?? this.name,
        direction: direction ?? this.direction,
        change: change ?? this.change,
        timing: timing ?? this.timing,
      );
}
