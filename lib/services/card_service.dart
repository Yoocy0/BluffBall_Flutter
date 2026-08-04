import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/api_error.dart';
import '../models/catalog_pitch_card.dart';
import 'token_storage.dart';

class CardServiceException implements Exception {
  final String message;
  final String? code;
  final int? status;

  const CardServiceException(this.message, {this.code, this.status});

  @override
  String toString() => message;
}

/// 카드 카탈로그 API
class CardService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  Future<Options> _authOptions() async {
    final token = await _tokenStorage.getAccessToken();
    return Options(
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  CardServiceException _error(Response response, String fallback) {
    final err = ApiError.fromResponse(
      statusCode: response.statusCode,
      data: response.data,
      fallbackMessage: fallback,
    );
    return CardServiceException(err.message, code: err.code, status: err.status);
  }

  /// 구종 카드 목록
  Future<List<CatalogPitchCard>> getPitchCards() async {
    final options = await _authOptions();
    final response = await _dio.get('/api/v1/cards/pitch', options: options);
    if (response.statusCode != 200) {
      throw _error(response, '구종 카드 목록 조회에 실패했습니다.');
    }
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CatalogPitchCard.fromJson)
        .toList();
  }
}
