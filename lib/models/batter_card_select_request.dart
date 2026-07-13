import 'dart:convert';

/// /app/game/{matchSessionId}/batter/select-card 송신 DTO.
///
/// PitcherReadyEvent 수신 후 5초 이내에 전송해야 한다.
/// 5초 초과 시 서버는 스윙 미발동으로 처리한다.
class BatterCardSelectRequest {
  /// PitcherReadyEvent 수신 후 선택까지 경과 시간(초). 5초 초과 = 스윙 미발동
  final double responseTimeSec;

  /// 타자가 예측한 투수 공의 최종 좌표 (1~25, 폭투 존 0)
  final int batterCoordinateNumber;

  /// 타자가 선택한 타이밍 슬롯
  /// "TOO_EARLY" | "EARLY" | "NORMAL" | "LATE" | "TOO_LATE"
  final String timing;

  const BatterCardSelectRequest({
    required this.responseTimeSec,
    required this.batterCoordinateNumber,
    required this.timing,
  });

  Map<String, dynamic> toJson() => {
        'responseTimeSec': responseTimeSec,
        'batterCoordinateNumber': batterCoordinateNumber,
        'timing': timing,
      };

  String toJsonString() => jsonEncode(toJson());
}
