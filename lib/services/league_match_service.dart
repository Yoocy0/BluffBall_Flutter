import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/league_enums.dart';
import '../models/match_join_response.dart';
import 'match_service.dart';
import 'token_storage.dart';

/// 리그전 매칭 큐 서비스
class LeagueMatchService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  /// 리그 매칭 큐 진입
  ///
  /// - 200: 즉시 매칭 (MATCHED)
  /// - 202: 대기 중 (WAITING)
  Future<MatchJoinResponse> joinQueue({
    required LeagueFormat format,
    required LeagueTier tier,
  }) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/league-match/queue/join',
      data: {
        'format': format.apiValue,
        'tier': tier.apiValue,
      },
      options: options,
    );

    if (response.statusCode == 200 || response.statusCode == 202) {
      return MatchJoinResponse.fromJson(response.data as Map<String, dynamic>);
    }

    final error = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: _messageForStatus(response.statusCode),
    );
    throw MatchException(
      error.message,
      isAuthError: error.isAuthError,
      code: error.code,
    );
  }

  /// 리그 매칭 큐 취소
  Future<void> cancelQueue() async {
    try {
      final options = await _authOptions();
      await _dio.delete(
        '/api/v1/league-match/queue/cancel',
        options: options,
      );
    } catch (_) {
      // 이미 매칭됐거나 큐에 없는 경우 무시
    }
  }

  String _messageForStatus(int? status) => switch (status) {
        400 => '출전 로스터 또는 구종 선택이 완료되지 않았습니다.',
        403 => '팀 리더만 리그 매칭을 시작할 수 있습니다.',
        404 => '소속 팀 또는 리그 정보가 없습니다.',
        409 => '이미 매칭 대기 중입니다.',
        401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
        _ => '리그 매칭에 실패했습니다. 잠시 후 다시 시도해주세요.',
      };
}
