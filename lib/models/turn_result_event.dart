import 'package:flutter/material.dart';

/// /topic/game/{matchSessionId}/result 로 수신되는 턴 결과 이벤트
class TurnResultEvent {
  final String turnResult;       // TurnResult enum name
  final int finalCoordinateNumber;
  final String pitchTiming;     // Timing enum name
  final String pitchCardName;
  final List<int> diceResults;  // 주사위 결과 목록 (0~2개)
  final int inning;
  final bool isTop;
  final int homeScore;
  final int awayScore;
  final int balls;
  final int strikes;
  final int outs;
  final bool firstBase;
  final bool secondBase;
  final bool thirdBase;
  final int pitcherUserId;
  final bool halfInningChanged;
  final bool gameOver;

  const TurnResultEvent({
    required this.turnResult,
    required this.finalCoordinateNumber,
    required this.pitchTiming,
    required this.pitchCardName,
    required this.diceResults,
    required this.inning,
    required this.isTop,
    required this.homeScore,
    required this.awayScore,
    required this.balls,
    required this.strikes,
    required this.outs,
    required this.firstBase,
    required this.secondBase,
    required this.thirdBase,
    required this.pitcherUserId,
    required this.halfInningChanged,
    required this.gameOver,
  });

  static const _turnResultsByOrdinal = [
    'STRIKE',
    'BALL',
    'SINGLE',
    'DOUBLE',
    'TRIPLE',
    'HOMERUN',
    'WALK',
    'STRIKE_OUT',
    'OUT',
    'DOUBLE_PLAY',
    'WILD_PITCH',
  ];

  static String _enumName(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is num) {
      final i = value.toInt();
      if (i >= 0 && i < _turnResultsByOrdinal.length) {
        return _turnResultsByOrdinal[i];
      }
    }
    if (value is Map) {
      final name = value['name'];
      if (name is String) return name;
    }
    return value.toString();
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _bool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    return fallback;
  }

  static List<int> _diceList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => (e as num).toInt()).toList();
  }

  factory TurnResultEvent.fromJson(Map<String, dynamic> json) =>
      TurnResultEvent(
        turnResult: _enumName(json['turnResult']),
        finalCoordinateNumber: _int(json['finalCoordinateNumber']),
        pitchTiming: _enumName(json['pitchTiming']),
        pitchCardName: (json['pitchCardName'] as String?) ?? '',
        diceResults: _diceList(json['diceResults']),
        inning: _int(json['inning'], fallback: 1),
        isTop: _bool(json['isTop'] ?? json['top'], fallback: true),
        homeScore: _int(json['homeScore']),
        awayScore: _int(json['awayScore']),
        balls: _int(json['balls']),
        strikes: _int(json['strikes']),
        outs: _int(json['outs']),
        firstBase: _bool(json['firstBase']),
        secondBase: _bool(json['secondBase']),
        thirdBase: _bool(json['thirdBase']),
        pitcherUserId: _int(json['pitcherUserId']),
        halfInningChanged: _bool(json['halfInningChanged']),
        gameOver: _bool(json['gameOver']),
      );

  // ── 결과 분류 ──────────────────────────────────────────────────────────────

  /// 공격 유리 결과 (초록색)
  static const _offensiveFavorable = {
    'SINGLE', 'DOUBLE', 'TRIPLE', 'HOMERUN', 'BALL', 'WALK', 'WILD_PITCH'
  };

  /// 수비 유리 결과 (빨간색)
  static const _defensiveFavorable = {
    'STRIKE', 'STRIKE_OUT', 'OUT', 'DOUBLE_PLAY'
  };

  bool get isOffensive => _offensiveFavorable.contains(turnResult);
  bool get isDefensive => _defensiveFavorable.contains(turnResult);

  Color get resultColor {
    if (isOffensive) return const Color(0xFF00C853); // 초록
    if (isDefensive) return const Color(0xFFFF1744); // 빨강
    return const Color(0xFFFFAB00);                  // 중립 (폭투 등)
  }

  String get resultLabel => switch (turnResult) {
        'STRIKE' => '스트라이크',
        'BALL' => '볼',
        'SINGLE' => '안타',
        'DOUBLE' => '2루타',
        'TRIPLE' => '3루타',
        'HOMERUN' => '홈런',
        'WALK' => '볼넷',
        'STRIKE_OUT' => '삼진',
        'OUT' => '아웃',
        'DOUBLE_PLAY' => '병살',
        'WILD_PITCH' => '폭투',
        _ => turnResult,
      };

  String get resultEmoji => switch (turnResult) {
        'STRIKE' => '✕',
        'BALL' => '○',
        'SINGLE' => '◎',
        'DOUBLE' => '◎◎',
        'TRIPLE' => '◎◎◎',
        'HOMERUN' => '★',
        'WALK' => '→',
        'STRIKE_OUT' => 'K',
        'OUT' => '↓',
        'DOUBLE_PLAY' => 'DP',
        'WILD_PITCH' => '!',
        _ => '',
      };
}
