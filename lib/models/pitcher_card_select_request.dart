import 'dart:convert';

/// /app/game/{matchSessionId}/pitcher/select-card 송신 DTO
class PitcherCardSelectRequest {
  final int pitchCardId;
  final int coordinateCardId;

  const PitcherCardSelectRequest({
    required this.pitchCardId,
    required this.coordinateCardId,
  });

  Map<String, dynamic> toJson() => {
        'pitchCardId': pitchCardId,
        'coordinateCardId': coordinateCardId,
      };

  String toJsonString() => jsonEncode(toJson());
}
