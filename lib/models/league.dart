import 'league_enums.dart';

/// GET /api/v1/leagues 카탈로그 항목
class League {
  final int leagueId;
  final LeagueFormat format;
  final LeagueTier tier;
  final String name;
  final int entryFee;
  final int firstPlacePrize;

  const League({
    required this.leagueId,
    required this.format,
    required this.tier,
    required this.name,
    required this.entryFee,
    required this.firstPlacePrize,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    final format = LeagueFormat.fromApi(json['format'] as String?);
    final tier = LeagueTier.fromApi(json['tier'] as String?);
    if (format == null || tier == null) {
      throw const FormatException('Invalid league payload');
    }
    return League(
      leagueId: (json['leagueId'] as num).toInt(),
      format: format,
      tier: tier,
      name: json['name'] as String? ?? '',
      entryFee: (json['entryFee'] as num?)?.toInt() ?? 0,
      firstPlacePrize: (json['firstPlacePrize'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeagueException implements Exception {
  final String message;
  final String? code;
  final int? status;

  const LeagueException(this.message, {this.code, this.status});

  @override
  String toString() => message;
}
