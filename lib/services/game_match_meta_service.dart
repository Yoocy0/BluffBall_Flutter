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
    final json = await _fetchSetupNumbersJson(matchSessionId);
    if (json == null) return null;
    try {
      return DoubleJudgmentConfig.fromSetupNumbersJson(json);
    } on FormatException {
      return null;
    }
  }

  /// 셋업 숫자 맵 조회. 실패 시 빈 맵.
  Future<Map<String, List<int>>> fetchSetupNumbers(String matchSessionId) async {
    final json = await _fetchSetupNumbersJson(matchSessionId);
    if (json == null) return {};
    return {
      '아웃': _intList(json['outNumList']),
      '병살': _intList(json['dpNumList']),
      '3루타': _intList(json['tripleNumList']),
      '홈런': _intList(json['hrNumList']),
    };
  }

  Future<Map<String, dynamic>?> _fetchSetupNumbersJson(
    String matchSessionId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/game-test/api/match/$matchSessionId/setup-numbers',
      );
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }
      return response.data;
    } on DioException {
      return null;
    }
  }

  List<int> _intList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => (e as num).toInt()).toList();
  }
}
