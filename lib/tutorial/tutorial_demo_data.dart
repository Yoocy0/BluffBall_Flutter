import '../models/card_info.dart';
import 'tutorial_coach_overlay.dart';
import 'tutorial_coord_math.dart';
import 'tutorial_models.dart';

/// 튜토리얼 데모 수치 (실전 규칙에 맞춤).
abstract final class TutorialDemoData {
  /// 커브: ↓ 변화 3. 퀴즈 목표 최종 17 → 정답 시작 2.
  static const curve = CardInfo(
    cardId: 9001,
    name: '커브',
    changeAmount: 3,
    direction: 'DOWN',
    timing: 'LATE',
  );

  static const foursam = CardInfo(
    cardId: 9000,
    name: '포심 패스트볼',
    changeAmount: 0,
    direction: 'STRAIGHT',
    timing: 'EARLY',
  );

  static const slider = CardInfo(
    cardId: 9002,
    name: '슬라이더',
    changeAmount: 3,
    direction: 'SIDE',
    timing: 'EARLY',
  );

  static const fork = CardInfo(
    cardId: 9003,
    name: '포크',
    changeAmount: 4,
    direction: 'DOWN',
    timing: 'LATE',
  );

  /// 구종 선택 화면에 나오는 랜덤 3장(데모 고정).
  static const dealtHand = [foursam, curve, slider];

  /// 투수 퀴즈: 최종 좌표 목표 (커브 ↓3 기준 정답 시작은 2).
  static const pitcherQuizTargetFinal = 17;

  /// 타자 연습: 투수가 포심을 이 시작 좌표에 둠.
  static const batterStartCoord = 13;

  /// 포심 변화 0 → 최종 = 시작 좌표. 맞춰야 할 타이밍은 카드의 EARLY.
  static int get batterCorrectCoord => tutorialApplyMove(
        start: batterStartCoord,
        direction: foursam.direction,
        changeAmount: foursam.changeAmount,
      );

  static TutorialTiming get batterCorrectTiming => switch (foursam.timing) {
        'TOO_EARLY' => TutorialTiming.tooEarly,
        'EARLY' => TutorialTiming.early,
        'LATE' => TutorialTiming.late,
        'TOO_LATE' => TutorialTiming.tooLate,
        _ => TutorialTiming.normal,
      };

  static const forcedHomerunNumber = 12;

  static bool isStrike(int n) =>
      const {7, 8, 9, 12, 13, 14, 17, 18, 19}.contains(n);
}

/// 화면 위 코치 문구 한 줄(탭으로 다음).
class CoachBeat {
  final String text;
  final TutorialSpotlight spotlight;

  const CoachBeat({
    required this.text,
    this.spotlight = TutorialSpotlight.none,
  });
}

enum TutorialStage {
  setupDefense,
  setupOffense,
  pitchSelect,
  pitcherLesson,
  batterLesson,
  reward,
  finished,
}

extension TutorialStageX on TutorialStage {
  String get title => switch (this) {
        TutorialStage.setupDefense => '셋업 · 수비',
        TutorialStage.setupOffense => '셋업 · 공격',
        TutorialStage.pitchSelect => '구종 선택',
        TutorialStage.pitcherLesson => '투수 투구',
        TutorialStage.batterLesson => '타자 타격',
        TutorialStage.reward => '시작 구종',
        TutorialStage.finished => '완료',
      };
}
