import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/league_enums.dart';
import '../models/team_league_progress.dart';
import 'token_storage.dart';

/// 리그 진행 상태 API
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

  /// 내 팀의 Compact/Full 리그 진행 상태 목록
  Future<List<TeamLeagueProgress>> getMyProgress() async {
    final options = await _authOptions();
    final response = await _dio.get('/api/v1/leagues/me', options: options);

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '리그 진행 상태 조회에 실패했습니다.',
      );
    }

    final data = response.data;
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(TeamLeagueProgress.fromJson)
        .toList();
  }

  /// 특정 포맷의 현재 티어. 미진입이면 null.
  Future<LeagueTier?> getCurrentTier(LeagueFormat format) async {
    final list = await getMyProgress();
    for (final item in list) {
      if (item.format == format) return item.currentTier;
    }
    return null;
  }
}
