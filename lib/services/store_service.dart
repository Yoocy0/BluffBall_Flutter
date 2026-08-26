import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/card_info.dart';
import '../models/store_models.dart';
import 'token_storage.dart';

/// /api/v1/store — 상점 카탈로그·구매.
class StoreService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  /// GET /api/v1/store/catalog
  ///
  /// 구종 스탯은 [fetchPitchMasters]와 cardId로 병합한다.
  Future<StoreCatalog> fetchCatalog() async {
    final options = await _authOptions();
    final results = await Future.wait([
      _dio.get('/api/v1/store/catalog', options: options),
      _dio.get('/api/v1/cards/pitch', options: options),
    ]);

    final catalogRes = results[0];
    final pitchRes = results[1];

    if (catalogRes.statusCode != 200 ||
        catalogRes.data is! Map<String, dynamic>) {
      throw _error(catalogRes, '상점 목록을 불러오지 못했습니다.');
    }

    var catalog = StoreCatalog.fromJson(
      catalogRes.data as Map<String, dynamic>,
    );

    if (pitchRes.statusCode == 200 && pitchRes.data is List) {
      final masters = <int, CardInfo>{};
      for (final item in pitchRes.data as List) {
        if (item is! Map<String, dynamic>) continue;
        final card = CardInfo.fromJson(item);
        if (card.cardId != 0) masters[card.cardId] = card;
      }
      catalog = catalog.enrichedWithPitchMasters(masters);
    }

    return catalog;
  }

  /// POST /api/v1/store/pitch/purchase
  Future<PitchPurchaseResult> purchasePitch(int cardId) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/store/pitch/purchase',
      data: {'cardId': cardId},
      options: options,
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return PitchPurchaseResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    throw _error(response, '구종 구매에 실패했습니다.');
  }

  /// POST /api/v1/store/enhancement/purchase
  Future<EnhancementPurchaseResult> purchaseEnhancement(
    int enhancementCardId,
  ) async {
    final options = await _authOptions();
    final response = await _dio.post(
      '/api/v1/store/enhancement/purchase',
      data: {'enhancementCardId': enhancementCardId},
      options: options,
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return EnhancementPurchaseResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    throw _error(response, '강화 카드 구매에 실패했습니다.');
  }

  StoreException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    final message = switch (err.code) {
      'STORE_PITCH_ALREADY_OWNED' => '이미 보유한 구종입니다.',
      'STORE_INSUFFICIENT_CURRENCY' ||
      'INSUFFICIENT_CURRENCY' ||
      'USER_CURRENCY_INSUFFICIENT' =>
        '재화가 부족합니다.',
      _ => response.statusCode == 400 &&
              (err.message.contains('재화') ||
                  err.message.toLowerCase().contains('currency'))
          ? '재화가 부족합니다.'
          : (err.message.isNotEmpty ? err.message : fallback),
    };
    return StoreException(
      message,
      status: response.statusCode,
      code: err.code,
      isInsufficientCurrency: message.contains('재화가 부족') ||
          err.code.contains('INSUFFICIENT') ||
          err.code.contains('CURRENCY'),
    );
  }
}

class StoreException implements Exception {
  final String message;
  final int? status;
  final String? code;
  final bool isInsufficientCurrency;

  const StoreException(
    this.message, {
    this.status,
    this.code,
    this.isInsufficientCurrency = false,
  });

  bool get isAuthError => status == 401 || code == 'AUTH_INVALID';

  @override
  String toString() => message;
}
