import 'league_enums.dart';

/// GET /api/v1/leagues/me 항목
class TeamLeagueProgress {
  final int teamId;
  final LeagueFormat format;
  final LeagueTier currentTier;
  final int rating;
  final int ratingFloor;
  final int ratingCeil;
  final bool promoteReady;
  final LeagueTier? nextTier;
  final int wins;
  final int losses;
  final int runDiff;

  const TeamLeagueProgress({
    required this.teamId,
    required this.format,
    required this.currentTier,
    required this.rating,
    required this.ratingFloor,
    required this.ratingCeil,
    required this.promoteReady,
    this.nextTier,
    required this.wins,
    required this.losses,
    required this.runDiff,
  });

  factory TeamLeagueProgress.fromJson(Map<String, dynamic> json) {
    final format = LeagueFormat.fromApi(json['format'] as String?);
    final tier = LeagueTier.fromApi(json['currentTier'] as String?);
    if (format == null || tier == null) {
      throw const FormatException('Invalid league progress payload');
    }
    return TeamLeagueProgress(
      teamId: (json['teamId'] as num).toInt(),
      format: format,
      currentTier: tier,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      ratingFloor: (json['ratingFloor'] as num?)?.toInt() ?? 0,
      ratingCeil: (json['ratingCeil'] as num?)?.toInt() ?? 0,
      promoteReady: json['promoteReady'] as bool? ?? false,
      nextTier: LeagueTier.fromApi(json['nextTier'] as String?),
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      runDiff: (json['runDiff'] as num?)?.toInt() ?? 0,
    );
  }
}
