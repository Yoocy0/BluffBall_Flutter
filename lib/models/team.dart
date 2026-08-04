/// GET /api/v1/teams/me, 검색·상세 공통 응답
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

enum TeamMemberRole { leader, member }

/// GET /api/v1/teams/{teamId}/members 항목
class TeamMember {
  final int userId;
  final String nickname;
  final TeamMemberRole role;
  final bool online;
  final DateTime? joinedAt;

  const TeamMember({
    required this.userId,
    required this.nickname,
    required this.role,
    required this.online,
    this.joinedAt,
  });

  bool get isLeader => role == TeamMemberRole.leader;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String?)?.toUpperCase();
    return TeamMember(
      userId: (json['userId'] as num).toInt(),
      nickname: json['nickname'] as String? ?? '',
      role: roleStr == 'LEADER' ? TeamMemberRole.leader : TeamMemberRole.member,
      online: json['online'] as bool? ?? false,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString())
          : null,
    );
  }
}

/// GET /api/v1/teams/{teamId}/records 항목
class TeamRecordItem {
  final int leagueId;
  final String format; // FULL | COMPACT
  final String tier;
  final int wins;
  final int losses;
  final int runDiff;
  final int rating;

  const TeamRecordItem({
    required this.leagueId,
    required this.format,
    required this.tier,
    required this.wins,
    required this.losses,
    required this.runDiff,
    required this.rating,
  });

  factory TeamRecordItem.fromJson(Map<String, dynamic> json) => TeamRecordItem(
        leagueId: (json['leagueId'] as num?)?.toInt() ?? 0,
        format: json['format'] as String? ?? '',
        tier: json['tier'] as String? ?? '',
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        runDiff: (json['runDiff'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toInt() ?? 0,
      );
}

/// GET/PUT /api/v1/teams/{teamId}/lineups/{format}
class TeamLineup {
  final int teamId;
  final String format;
  final List<int> userIds;
  final int? startingPitcherUserId;

  const TeamLineup({
    required this.teamId,
    required this.format,
    required this.userIds,
    this.startingPitcherUserId,
  });

  factory TeamLineup.fromJson(Map<String, dynamic> json) => TeamLineup(
        teamId: (json['teamId'] as num).toInt(),
        format: json['format'] as String? ?? '',
        userIds: (json['userIds'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        startingPitcherUserId: (json['startingPitcherUserId'] as num?)?.toInt(),
      );
}

/// GET /api/v1/teams/{teamId}/treasury
class TeamTreasury {
  final int treasury;

  const TeamTreasury({required this.treasury});

  factory TeamTreasury.fromJson(Map<String, dynamic> json) => TeamTreasury(
        treasury: (json['treasury'] as num?)?.toInt() ?? 0,
      );
}

class TeamException implements Exception {
  final String message;
  final String? code;
  final int? status;

  const TeamException(this.message, {this.code, this.status});

  @override
  String toString() => message;
}

/// 창단 비용 표시용 (실제 차감은 서버 정책 — UI 표시만)
const int kTeamCreateCost = 5000;
const int kTeamMaxMembers = 50;
