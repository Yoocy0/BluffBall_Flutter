import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/league.dart';
import '../models/league_enums.dart';
import '../models/team_league_progress.dart';
import 'token_storage.dart';

/// 리그 카탈로그·진행 상태 API
class LeagueService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  LeagueException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    return LeagueException(err.message, code: err.code, status: err.status);
  }

  /// 리그 카탈로그
  Future<List<League>> getLeagues({
    LeagueFormat? format,
    LeagueTier? tier,
  }) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/leagues',
      queryParameters: {
        if (format != null) 'format': format.apiValue,
        if (tier != null) 'tier': tier.apiValue,
      },
      options: options,
    );
    if (response.statusCode != 200) {
      throw _error(response, '리그 목록 조회에 실패했습니다.');
    }
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(League.fromJson)
        .toList();
  }

  /// 리그 상세
  Future<League> getLeague(int leagueId) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/leagues/$leagueId',
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return League.fromJson(response.data as Map<String, dynamic>);
    }
    throw _error(response, '리그 상세 조회에 실패했습니다.');
  }

  /// 내 팀 Compact/Full 진행 상태. 미진입이면 [].
  Future<List<TeamLeagueProgress>> getMyProgress() async {
    final options = await _authOptions();
    final response = await _dio.get('/api/v1/leagues/me', options: options);

    if (response.statusCode != 200) {
      throw _error(response, '리그 진행 상태 조회에 실패했습니다.');
    }

    final data = response.data;
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(TeamLeagueProgress.fromJson)
        .toList();
  }

  /// 포맷별 진행 상태. 미진입이면 null.
  Future<TeamLeagueProgress?> getProgress(LeagueFormat format) async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/leagues/progress',
      queryParameters: {'format': format.apiValue},
      options: options,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamLeagueProgress.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw _error(response, '리그 진행 상태 조회에 실패했습니다.');
  }

  /// 특정 포맷의 현재 티어. 미진입이면 null.
  Future<LeagueTier?> getCurrentTier(LeagueFormat format) async {
    final list = await getMyProgress();
    for (final item in list) {
      if (item.format == format) return item.currentTier;
    }
    return null;
  }

  /// 아마 4부 최초 진입 (리더)
  Future<TeamLeagueProgress> enter(LeagueFormat format) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/leagues/enter',
      queryParameters: {'format': format.apiValue},
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamLeagueProgress.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw _error(response, '리그 참가에 실패했습니다.');
  }

  /// 상위 티어 승급 (리더)
  Future<TeamLeagueProgress> promote({
    required LeagueFormat format,
    required LeagueTier targetTier,
  }) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/leagues/promote',
      queryParameters: {
        'format': format.apiValue,
        'targetTier': targetTier.apiValue,
      },
      options: options,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TeamLeagueProgress.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw _error(response, '리그 승급에 실패했습니다.');
  }
}
