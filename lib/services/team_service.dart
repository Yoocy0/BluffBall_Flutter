import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/team.dart';
import '../models/team_pitch_cards.dart';
import 'token_storage.dart';

/// 팀(클랜) API
class TeamService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  TeamException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    return TeamException(err.message, code: err.code, status: err.status);
  }

  /// 내 소속 팀 조회. 미소속(404)이면 null.
  Future<Team?> getMyTeam() async {
    final options = await _authOptions();
    final response = await _dio.get('/api/v1/teams/me', options: options);

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return Team.fromJson(response.data as Map<String, dynamic>);
    }
    if (response.statusCode == 404) return null;
    throw _error(response, '팀 조회에 실패했습니다.');
  }

  /// 소속 팀 존재 여부. 네트워크 오류 시 false.
  Future<bool> hasMyTeam() async {
    try {
      return await getMyTeam() != null;
    } catch (_) {
      return false;
    }
  }

  /// 팀 창단
  Future<Team> createTeam({required String name, String? logoUrl}) async {
    final options = await _authOptions();
    final body = <String, dynamic>{'name': name};
    if (logoUrl != null && logoUrl.isNotEmpty) {
      body['logoUrl'] = logoUrl;
    }

    final response = await _dio.post(
      '/api/v1/teams',
      data: body,
      options: options,
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return Team.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '팀 창단에 실패했습니다.');
  }

  /// 팀 이름 검색 (부분 일치)
  Future<List<Team>> searchTeams({String? name}) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams',
      queryParameters: {
        if (name != null && name.isNotEmpty) 'name': name,
      },
      options: options,
    );

    if (response.statusCode != 200) {
      throw _error(response, '팀 검색에 실패했습니다.');
    }

    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Team.fromJson)
        .toList();
  }

  /// 팀 상세
  Future<Team> getTeam(int teamId) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams/$teamId',
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return Team.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '팀 상세 조회에 실패했습니다.');
  }

  /// 팀 가입
  Future<Team> joinTeam(int teamId) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/teams/$teamId/join',
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return Team.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '팀 가입에 실패했습니다.');
  }

  /// 팀 탈퇴
  Future<void> leaveTeam(int teamId) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/teams/$teamId/leave',
      options: options,
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw _error(response, '팀 탈퇴에 실패했습니다.');
  }

  /// 팀 삭제 (리더)
  Future<void> deleteTeam(int teamId) async {
    final options = await _authOptions();
    final response = await _dio.delete(
      '/api/v1/teams/$teamId',
      options: options,
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw _error(response, '팀 삭제에 실패했습니다.');
  }

  /// 멤버 강제 탈퇴 (리더)
  Future<void> kickMember(int teamId, int userId) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/teams/$teamId/members/$userId/kick',
      options: options,
    );
    if (response.statusCode == 204 || response.statusCode == 200) return;
    throw _error(response, '강제 탈퇴에 실패했습니다.');
  }

  /// 멤버 계급 변경 (리더). role: LEADER | MEMBER
  Future<TeamMember> updateMemberRole({
    required int teamId,
    required int userId,
    required String role,
  }) async {
    final options = await _authOptions();
    final response = await _dio.patch(
      '/api/v1/teams/$teamId/members/$userId/role',
      data: {'role': role},
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamMember.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '계급 변경에 실패했습니다.');
  }

  /// 멤버 목록
  Future<List<TeamMember>> getMembers(int teamId) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams/$teamId/members',
      options: options,
    );
    if (response.statusCode != 200) {
      throw _error(response, '멤버 목록 조회에 실패했습니다.');
    }
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(TeamMember.fromJson)
        .toList();
  }

  /// 리그 전적
  Future<List<TeamRecordItem>> getRecords(
    int teamId, {
    String? format,
    String? tier,
    bool aggregate = false,
  }) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams/$teamId/records',
      queryParameters: {
        if (format != null) 'format': format,
        if (tier != null) 'tier': tier,
        'aggregate': aggregate,
      },
      options: options,
    );
    if (response.statusCode != 200) {
      throw _error(response, '전적 조회에 실패했습니다.');
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) return const [];
    final records = data['records'];
    if (records is! List) return const [];
    return records
        .whereType<Map<String, dynamic>>()
        .map(TeamRecordItem.fromJson)
        .toList();
  }

  /// 팀 금고 조회
  Future<TeamTreasury> getTreasury(int teamId) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams/$teamId/treasury',
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamTreasury.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '금고 조회에 실패했습니다.');
  }

  /// 팀 금고 기부
  Future<TeamTreasury> donate(int teamId, int amount) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/teams/$teamId/donate',
      data: {'amount': amount},
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamTreasury.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '기부에 실패했습니다.');
  }

  /// 출전 로스터 조회. 없으면 null.
  Future<TeamLineup?> getLineup(int teamId, String format) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams/$teamId/lineups/$format',
      options: options,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamLineup.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '로스터 조회에 실패했습니다.');
  }

  /// 출전 로스터 저장 (리더)
  Future<TeamLineup> upsertLineup({
    required int teamId,
    required String format,
    required List<int> userIds,
    required int startingPitcherUserId,
  }) async {
    final options = await _authOptions();
    final response = await _dio.put(
      '/api/v1/teams/$teamId/lineups/$format',
      data: {
        'userIds': userIds,
        'startingPitcherUserId': startingPitcherUserId,
      },
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamLineup.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '로스터 저장에 실패했습니다.');
  }

  /// 구종·강화 사전 선택 조회. 없으면 null.
  Future<TeamPitchCards?> getPitchCards(int teamId, String format) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/teams/$teamId/lineups/$format/pitch-cards',
      options: options,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamPitchCards.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '구종 카드 조회에 실패했습니다.');
  }

  /// 구종·강화 사전 선택 저장 (리더, 전체 교체)
  Future<TeamPitchCards> upsertPitchCards({
    required int teamId,
    required String format,
    required List<MemberPitchSelection> selections,
  }) async {
    final options = await _authOptions();
    final response = await _dio.put(
      '/api/v1/teams/$teamId/lineups/$format/pitch-cards',
      data: {
        'selections': selections.map((s) => s.toJson()).toList(),
      },
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamPitchCards.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '구종 카드 저장에 실패했습니다.');
  }

  /// 온/오프라인 heartbeat
  Future<void> heartbeat(int teamId) async {
    try {
      final options = await _authOptions();
      await _dio.post(
        '/api/v1/teams/$teamId/presence/heartbeat',
        options: options,
      );
    } catch (_) {
      // heartbeat 실패는 무시
    }
  }
}
