import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/user_pitch_card.dart';
import 'token_storage.dart';

/// 유저 보유 구종·강화 카드 인벤토리.
class UserInventoryService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  /// GET /api/v1/users/me/pitch-cards
  Future<List<UserPitchCard>> fetchPitchCards() async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/users/me/pitch-cards',
      options: options,
    );

    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(UserPitchCard.fromJson)
          .toList();
    }

    throw _error(response, '보유 구종을 불러오지 못했습니다.');
  }

  InventoryException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    return InventoryException(
      err.message.isNotEmpty ? err.message : fallback,
      status: response.statusCode,
      code: err.code,
    );
  }
}

class InventoryException implements Exception {
  final String message;
  final int? status;
  final String? code;

  const InventoryException(this.message, {this.status, this.code});

  bool get isAuthError => status == 401 || code == 'AUTH_INVALID';

  @override
  String toString() => message;
}
