import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/tutorial_models.dart';
import 'token_storage.dart';

/// 튜토리얼 상태 조회 · 완료(구종 지급) API.
class TutorialService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  /// GET /api/v1/tutorial/status
  Future<TutorialStatus> fetchStatus() async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/tutorial/status',
      options: options,
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return TutorialStatus.fromJson(response.data as Map<String, dynamic>);
    }

    throw _error(response, '튜토리얼 상태를 불러오지 못했습니다.');
  }

  /// POST /api/v1/tutorial/complete
  ///
  /// [selectedPitchCardIds]: status의 selectableStarterPitches.cardId 중
  /// [expectedCount]개(기본 2). 포심은 요청에 넣지 않음.
  Future<TutorialCompleteResult> complete({
    required List<int> selectedPitchCardIds,
    int expectedCount = 2,
  }) async {
    if (selectedPitchCardIds.length != expectedCount) {
      throw TutorialException('변화구는 정확히 $expectedCount개를 선택해야 합니다.');
    }
    if (selectedPitchCardIds.toSet().length != selectedPitchCardIds.length) {
      throw const TutorialException('같은 구종을 중복 선택할 수 없습니다.');
    }

    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/tutorial/complete',
      data: {'selectedPitchCardIds': selectedPitchCardIds},
      options: options,
    );

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        response.data is Map<String, dynamic>) {
      return TutorialCompleteResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    throw _error(response, '튜토리얼 완료 처리에 실패했습니다.');
  }

  TutorialException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    final message = switch (response.statusCode) {
      400 => err.message.isNotEmpty
          ? err.message
          : '선택한 구종이 올바르지 않습니다.',
      401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
      409 => '이미 튜토리얼을 완료했습니다.',
      _ => err.message.isNotEmpty ? err.message : fallback,
    };
    return TutorialException(
      message,
      status: response.statusCode,
      code: err.code,
    );
  }
}

class TutorialException implements Exception {
  final String message;
  final int? status;
  final String? code;

  const TutorialException(this.message, {this.status, this.code});

  bool get isAuthError => status == 401 || code == 'AUTH_INVALID';
  bool get isAlreadyCompleted => status == 409;

  @override
  String toString() => message;
}
