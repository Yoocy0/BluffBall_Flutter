import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/team.dart';
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

  /// 내 소속 팀 조회. 미소속(404)이면 null.
  Future<Team?> getMyTeam() async {
    final options = await _authOptions();
    final response = await _dio.get('/api/v1/teams/me', options: options);

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return Team.fromJson(response.data as Map<String, dynamic>);
    }
    if (response.statusCode == 404) return null;

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: '팀 조회에 실패했습니다.',
    );
  }

  /// 소속 팀 존재 여부. 네트워크 오류 시 false.
  Future<bool> hasMyTeam() async {
    try {
      final team = await getMyTeam();
      return team != null;
    } catch (_) {
      return false;
    }
  }
}
