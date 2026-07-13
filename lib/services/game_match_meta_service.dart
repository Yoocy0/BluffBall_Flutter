import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/double_judgment_config.dart';

/// 매치 메타 정보 조회 (2루타 조건 등).
///
/// 현재는 game-test API를 통해 Redis에 저장된 값을 읽는다.
/// 추후 `/api/v1/game/{matchSessionId}/double-judgment` 등 정식 API로 교체 예정.
class GameMatchMetaService {
  final _dio = ApiClient().dio;

  /// 2루타 판정 조건 조회. 미설정·조회 실패 시 null.
  Future<DoubleJudgmentConfig?> fetchDoubleJudgment(String matchSessionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/game-test/api/match/$matchSessionId/setup-numbers',
      );
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }
      return DoubleJudgmentConfig.fromSetupNumbersJson(response.data!);
    } on FormatException {
      return null;
    } on DioException {
      return null;
    }
  }
}
