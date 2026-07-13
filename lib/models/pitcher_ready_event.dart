/// /topic/game/{matchSessionId} 으로 수신되는 투수 준비 완료 이벤트.
///
/// 투수가 구종·좌표를 선택하면 서버가 타자에게 이 이벤트를 발행한다.
/// 타자는 이 이벤트를 수신한 시각부터 5초 이내에 응답해야 한다.
/// 심리전을 위해 투수의 시작 좌표만 공개된다 (최종 좌표는 구종 변화 후 결정).
class PitcherReadyEvent {
  /// 투수가 선택한 시작 좌표 번호 (1~25)
  final int startCoordinateNumber;

  const PitcherReadyEvent({required this.startCoordinateNumber});

  factory PitcherReadyEvent.fromJson(Map<String, dynamic> json) =>
      PitcherReadyEvent(
        startCoordinateNumber:
            (json['startCoordinateNumber'] as num).toInt(),
      );
}
