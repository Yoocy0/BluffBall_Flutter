import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/game_session_state.dart';
import '../models/game_session_state_exception.dart';
import 'token_storage.dart';

/// 인게임 재접속 시 세션 상태 조회 API.
class GameSessionStateService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<GameSessionState> fetchState(String matchSessionId) async {
    final token = await _tokenStorage.getAccessToken();
    final response = await _dio.get<dynamic>(
      '/api/v1/game/$matchSessionId/state',
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return GameSessionState.fromJson(response.data as Map<String, dynamic>);
    }

    throw GameSessionStateException.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
    );
  }
}
