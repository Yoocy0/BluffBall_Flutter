import '../models/game_mode.dart';

/// /topic/game/{matchSessionId}/end 수신 이벤트
class GameEndEvent {
  final int homeScore;
  final int awayScore;
  final String? reason;
  final int? winnerUserId;
  final List<int> participantUserIds;
  final GameMode? gameMode;

  const GameEndEvent({
    required this.homeScore,
    required this.awayScore,
    this.reason,
    this.winnerUserId,
    this.participantUserIds = const [],
    this.gameMode,
  });

  bool get isForfeit =>
      reason != null &&
      (reason!.toUpperCase().contains('FORFEIT') ||
          reason!.toUpperCase().contains('WALKOVER') ||
          reason!.toUpperCase().contains('DISCONNECT'));

  factory GameEndEvent.fromJson(Map<String, dynamic> json) {
    final board = json['board'] as Map<String, dynamic>?;
    final participantsJson = json['participantUserIds'];
    final participants = participantsJson is List
        ? participantsJson.map((e) => (e as num).toInt()).toList()
        : <int>[];

    return GameEndEvent(
      homeScore: _int(board?['homeScore'] ?? json['homeScore']),
      awayScore: _int(board?['awayScore'] ?? json['awayScore']),
      reason: (json['reason'] ?? json['endReason']) as String?,
      winnerUserId: _intOrNull(json['winnerUserId']),
      participantUserIds: participants,
      gameMode: _gameModeFromApi(json['gameMode'] as String?),
    );
  }

  int scoreForUser(int userId) {
    if (participantUserIds.length >= 2) {
      final isHome = userId == participantUserIds.first;
      return isHome ? homeScore : awayScore;
    }
    return homeScore;
  }

  int opponentScoreForUser(int userId) {
    if (participantUserIds.length >= 2) {
      final isHome = userId == participantUserIds.first;
      return isHome ? awayScore : homeScore;
    }
    return awayScore;
  }
}

int _int(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

int? _intOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

GameMode? _gameModeFromApi(String? value) => switch (value) {
      'SHOWDOWN' || 'GENERAL' => GameMode.single,
      'FULL_LEAGUE' || 'CLAN_GENERAL' => GameMode.teamRegular,
      'COMPACT_LEAGUE' || 'CLAN_MINI' => GameMode.teamMini,
      'CUSTOM' => GameMode.custom,
      _ => null,
    };
