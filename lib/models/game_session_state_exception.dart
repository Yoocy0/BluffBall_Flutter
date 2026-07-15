import '../models/api_error.dart';

/// GET /api/v1/game/{matchSessionId}/state 오류.
class GameSessionStateException implements Exception {
  final ApiError error;

  GameSessionStateException(this.error);

  int? get status => error.status;
  String get code => error.code;
  String get message => error.message;

  bool get shouldClearLocalSession => error.shouldClearMatchSession;

  factory GameSessionStateException.fromResponse({
    required int? statusCode,
    required dynamic data,
  }) =>
      GameSessionStateException(
        ApiError.fromResponse(
          statusCode: statusCode,
          data: data,
          fallbackMessage: '게임 상태를 불러오지 못했습니다.',
        ),
      );

  @override
  String toString() => message;
}
