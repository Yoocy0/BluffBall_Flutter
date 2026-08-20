import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import 'token_storage.dart';

/// 튜토리얼 완료 여부 + complete API.
///
/// 현재는 로컬 boolean을 우선 사용한다.
/// 이후 로그인/앱 실행 시 백엔드 `tutorialCompleted`로 교체하면 된다.
class TutorialService {
  static const _kLocalCompleted = 'tutorial_completed';

  final _storage = const FlutterSecureStorage();
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  /// 로컬(및 향후 서버) 기준 튜토리얼 완료 여부.
  Future<bool> isCompleted() async {
    final local = await _storage.read(key: _kLocalCompleted);
    return local == 'true';
  }

  /// 백엔드 연동 전용 훅 — 서버 boolean을 받아 로컬에 반영.
  Future<void> syncFromServer(bool completed) async {
    await _storage.write(
      key: _kLocalCompleted,
      value: completed ? 'true' : 'false',
    );
  }

  Future<void> markCompletedLocally() async {
    await _storage.write(key: _kLocalCompleted, value: 'true');
  }

  /// 첫 완료 시 호출. 선택 구종 2개 + 포심 지급을 서버에 요청한다.
  ///
  /// [selectedPitchKeys]: `CURVE` | `SLIDER` | `FORK`
  Future<void> complete({required List<String> selectedPitchKeys}) async {
    if (selectedPitchKeys.length != 2) {
      throw TutorialException('변화구는 정확히 2개를 선택해야 합니다.');
    }

    try {
      final token = await _tokenStorage.getAccessToken();
      final response = await _dio.post(
        '/api/v1/tutorial/complete',
        data: {'selectedPitchTypes': selectedPitchKeys},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      // 엔드포인트가 아직 없으면(404 등) 로컬만 완료 처리하고 넘어간다.
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204 ||
          response.statusCode == 404 ||
          response.statusCode == 501) {
        await markCompletedLocally();
        return;
      }

      throw TutorialException(
        '튜토리얼 완료 처리에 실패했습니다. (${response.statusCode})',
      );
    } on TutorialException {
      rethrow;
    } catch (_) {
      // 네트워크 오류여도 로컬 완료는 허용 (오프라인/미구현 API)
      await markCompletedLocally();
    }
  }
}

class TutorialException implements Exception {
  final String message;
  const TutorialException(this.message);

  @override
  String toString() => message;
}
