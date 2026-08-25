import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/enhancement_card.dart';
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

  /// GET /api/v1/users/me/enhancement-cards
  Future<List<EnhancementCard>> fetchEnhancementCards() async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/users/me/enhancement-cards',
      options: options,
    );

    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(EnhancementCard.fromJson)
          .toList();
    }

    throw _error(response, '강화 카드를 불러오지 못했습니다.');
  }

  /// GET /api/v1/cards/enhancement (마스터 카탈로그)
  Future<List<EnhancementCard>> fetchEnhancementCatalog() async {
    final options = await _authOptions();
    final response = await _dio.get(
      '/api/v1/cards/enhancement',
      options: options,
    );

    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(EnhancementCard.fromJson)
          .toList();
    }

    throw _error(response, '강화 카드 목록을 불러오지 못했습니다.');
  }

  /// POST /api/v1/users/me/pitch-cards/{id}/enhance
  Future<UserPitchCard> enhancePitchCard({
    required int userPitchCardId,
    required int enhancementCardId,
  }) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/users/me/pitch-cards/$userPitchCardId/enhance',
      data: {'enhancementCardId': enhancementCardId},
      options: options,
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return UserPitchCard.fromJson(response.data as Map<String, dynamic>);
    }

    throw _error(response, '강화에 실패했습니다.');
  }

  /// POST .../enhance/revert/change-amount | timing
  Future<UserPitchCard> revertEnhancement({
    required int userPitchCardId,
    required EnhanceRevertKind kind,
  }) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/users/me/pitch-cards/$userPitchCardId/enhance/revert/${kind.pathSuffix}',
      options: options,
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return UserPitchCard.fromJson(response.data as Map<String, dynamic>);
    }

    throw _error(response, '강화 되돌리기에 실패했습니다.');
  }

  InventoryException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    final message = switch (err.code) {
      'USER_PITCH_CARD_NOT_FOUND' => '보유하지 않은 구종입니다.',
      'USER_PITCH_CARD_ALREADY_ENHANCED' => '이미 해당 강화가 적용되어 있습니다.',
      'USER_ENHANCEMENT_CARD_INSUFFICIENT' => '강화 카드가 부족합니다.',
      'USER_PITCH_CARD_TIMING_BOUNDARY' => '타이밍 강화 범위를 초과합니다.',
      'USER_PITCH_CARD_NOT_ENHANCED' => '되돌릴 강화가 없습니다.',
      _ => err.message.isNotEmpty ? err.message : fallback,
    };
    return InventoryException(
      message,
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
