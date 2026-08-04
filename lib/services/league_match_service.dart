import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/league_enums.dart';
import '../models/match_join_response.dart';
import 'match_service.dart';
import 'token_storage.dart';

/// 리그전 매칭 큐 서비스 (`/api/v1/league-match`)
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
  /// - 200 MATCHED: 즉시 성사 (`matchSessionId` 포함)
  /// - 202 WAITING: 대기 (`matchSessionId` null) → WS로 성사 알림
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
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return MatchJoinResponse.fromJson(data);
      }
      // 202에 body가 비는 경우 대비
      return const MatchJoinResponse(
        status: MatchJoinStatus.waiting,
        matchSessionId: null,
      );
    }

    final error = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage:
          _messageFor(response.statusCode, null) ?? '리그 매칭에 실패했습니다.',
    );
    throw MatchException(
      _messageFor(response.statusCode, error.code) ?? error.message,
      isAuthError: error.isAuthError,
      code: error.code,
    );
  }

  /// 리그 매칭 큐 취소 → 204
  Future<void> cancelQueue() async {
    try {
      final options = await _authOptions();
      final response = await _dio.delete(
        '/api/v1/league-match/queue/cancel',
        options: options,
      );
      if (response.statusCode == 204 ||
          response.statusCode == 200 ||
          response.statusCode == 404) {
        return;
      }
    } catch (_) {
      // 이미 매칭됐거나 큐에 없는 경우 무시
    }
  }

  String? _messageFor(int? status, String? code) {
    if (code == 'LEAGUE_MATCH_NOT_READY') {
      return '출전 로스터 또는 구종 선택이 완료되지 않았습니다.';
    }
    if (code == 'LEAGUE_MATCH_TIER_MISMATCH') {
      return '현재 리그 티어와 맞지 않거나 리그에 참가하지 않았습니다.';
    }
    if (code == 'TEAM_FORBIDDEN') {
      return '팀 리더만 리그 매칭을 시작할 수 있습니다.';
    }
    return switch (status) {
      400 => '출전 로스터 또는 구종 선택이 완료되지 않았습니다.',
      403 => '팀 리더만 리그 매칭을 시작할 수 있습니다.',
      404 => '소속 팀 또는 리그 정보가 없습니다.',
      409 => '이미 매칭 대기 중입니다.',
      401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
      _ => null,
    };
  }
}
