/// 경기 시작 시 서버가 랜덤 설정하는 2루타 판정 조건.
///
/// [targetFace]     : 목표 주사위 눈금 (1~6)
/// [useFrontDice]   : true = 1번째(앞) 주사위, false = 2번째(뒤) 주사위
class DoubleJudgmentConfig {
  final int targetFace;
  final bool useFrontDice;

  const DoubleJudgmentConfig({
    required this.targetFace,
    required this.useFrontDice,
  });

  /// 카드에 표시할 주사위 번호 (1 또는 2)
  int get diceNumber => useFrontDice ? 1 : 2;

  /// HUD 표시용 — 1번째(좌) = L, 2번째(우) = R
  String get diceSideLetter => useFrontDice ? 'L' : 'R';

  String get diceLabel => useFrontDice ? '1번째 주사위' : '2번째 주사위';

  /// 셋업 요약 바용 라벨 (예: "2루타 L3")
  String get hudLabel => '2루타 $diceSideLetter$targetFace';

  factory DoubleJudgmentConfig.fromSetupNumbersJson(Map<String, dynamic> json) {
    final face = (json['doubleJudgmentTargetFace'] as num?)?.toInt() ?? 0;
    if (face < 1 || face > 6) {
      throw FormatException('doubleJudgmentTargetFace not configured: $face');
    }
    return DoubleJudgmentConfig(
      targetFace: face,
      useFrontDice: json['doubleJudgmentUseFrontDice'] as bool? ?? true,
    );
  }
}
