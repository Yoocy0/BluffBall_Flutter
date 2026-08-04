/// GET/PUT /api/v1/teams/{teamId}/lineups/{format}/pitch-cards
class TeamPitchCards {
  final int teamId;
  final String format;
  final List<MemberPitchSelection> selections;

  const TeamPitchCards({
    required this.teamId,
    required this.format,
    required this.selections,
  });

  factory TeamPitchCards.fromJson(Map<String, dynamic> json) => TeamPitchCards(
        teamId: (json['teamId'] as num).toInt(),
        format: json['format'] as String? ?? '',
        selections: (json['selections'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MemberPitchSelection.fromJson)
            .toList(),
      );
}

class MemberPitchSelection {
  final int userId;
  final List<int> cardIds;
  final int dropCardId;

  const MemberPitchSelection({
    required this.userId,
    required this.cardIds,
    required this.dropCardId,
  });

  factory MemberPitchSelection.fromJson(Map<String, dynamic> json) =>
      MemberPitchSelection(
        userId: (json['userId'] as num).toInt(),
        cardIds: (json['cardIds'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        dropCardId: (json['dropCardId'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'cardIds': cardIds,
        'dropCardId': dropCardId,
      };
}
