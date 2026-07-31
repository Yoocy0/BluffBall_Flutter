/// GET /api/v1/teams/me 응답
class Team {
  final int teamId;
  final String name;
  final String? logoUrl;
  final int leaderUserId;
  final int treasury;
  final int? currentLeagueId;

  const Team({
    required this.teamId,
    required this.name,
    this.logoUrl,
    required this.leaderUserId,
    required this.treasury,
    this.currentLeagueId,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        teamId: (json['teamId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        logoUrl: json['logoUrl'] as String?,
        leaderUserId: (json['leaderUserId'] as num).toInt(),
        treasury: (json['treasury'] as num?)?.toInt() ?? 0,
        currentLeagueId: (json['currentLeagueId'] as num?)?.toInt(),
      );
}
