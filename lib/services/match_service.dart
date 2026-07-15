import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/match_join_response.dart';
import 'token_storage.dart';

/// 싱글 모드 매칭 큐 서비스
class MatchService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  /// 싱글 모드 매칭 큐 진입
  ///
  /// - 200: 즉시 매칭 (MATCHED + matchSessionId)
  /// - 202: 대기 중 (WAITING)
  Future<MatchJoinResponse> joinQueue() async {
    final options = await _authOptions();
    final response = await _dio.post('/api/v1/match/queue/join', options: options);

    if (response.statusCode == 200 || response.statusCode == 202) {
      return MatchJoinResponse.fromJson(response.data as Map<String, dynamic>);
    }

    final error = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: _messageForStatus(response.statusCode),
    );
    throw MatchException(error.message, isAuthError: error.isAuthError);
  }

  /// 싱글 모드 매칭 큐 취소
  Future<void> cancelQueue() async {
    try {
      final options = await _authOptions();
      await _dio.delete('/api/v1/match/queue/cancel', options: options);
    } catch (_) {
      // 취소 실패는 조용히 무시 (이미 매칭됐거나 큐에 없는 경우)
    }
  }

  /// JWT payload에서 sub(userId) 추출
  static String? extractUserIdFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  String _messageForStatus(int? status) => switch (status) {
        409 => '이미 매칭 대기 중입니다.',
        401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
        _ => '매칭에 실패했습니다. 잠시 후 다시 시도해주세요.',
      };
}

class MatchException implements Exception {
  final String message;
  final bool isAuthError;

  const MatchException(this.message, {this.isAuthError = false});

  @override
  String toString() => message;
}
