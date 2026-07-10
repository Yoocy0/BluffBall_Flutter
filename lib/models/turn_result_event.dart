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

  factory TurnResultEvent.fromJson(Map<String, dynamic> json) =>
      TurnResultEvent(
        turnResult: json['turnResult'] as String,
        finalCoordinateNumber:
            (json['finalCoordinateNumber'] as num).toInt(),
        pitchTiming: json['pitchTiming'] as String,
        pitchCardName: json['pitchCardName'] as String,
        diceResults: (json['diceResults'] as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList(),
        inning: (json['inning'] as num).toInt(),
        isTop: json['isTop'] as bool,
        homeScore: (json['homeScore'] as num).toInt(),
        awayScore: (json['awayScore'] as num).toInt(),
        balls: (json['balls'] as num).toInt(),
        strikes: (json['strikes'] as num).toInt(),
        outs: (json['outs'] as num).toInt(),
        firstBase: json['firstBase'] as bool,
        secondBase: json['secondBase'] as bool,
        thirdBase: json['thirdBase'] as bool,
        pitcherUserId: (json['pitcherUserId'] as num).toInt(),
        halfInningChanged: json['halfInningChanged'] as bool,
        gameOver: json['gameOver'] as bool,
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
