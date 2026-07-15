/// 백엔드 공통 에러 응답 { code, message, status }
class ApiError implements Exception {
  final int status;
  final String code;
  final String message;

  const ApiError({
    required this.status,
    required this.code,
    required this.message,
  });

  factory ApiError.fromResponse({
    required int? statusCode,
    required dynamic data,
    String fallbackMessage = '요청에 실패했습니다.',
  }) {
    if (data is Map<String, dynamic>) {
      return ApiError(
        status: (data['status'] as num?)?.toInt() ?? statusCode ?? 0,
        code: (data['code'] as String?) ?? 'UNKNOWN',
        message: (data['message'] as String?) ??
            _defaultMessage(statusCode, fallbackMessage),
      );
    }
    return ApiError(
      status: statusCode ?? 0,
      code: 'UNKNOWN',
      message: _defaultMessage(statusCode, fallbackMessage),
    );
  }

  static String _defaultMessage(int? status, String fallback) =>
      switch (status) {
        401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
        403 => '접근 권한이 없습니다.',
        404 => '요청한 리소스를 찾을 수 없습니다.',
        _ => fallback,
      };

  bool get isAuthError => status == 401 || code == 'AUTH_REQUIRED' || code == 'AUTH_INVALID';

  bool get shouldClearMatchSession =>
      status == 403 ||
      status == 404 ||
      code == 'MATCH_NOT_PARTICIPANT' ||
      code == 'MATCH_SESSION_NOT_FOUND' ||
      code == 'GAME_STATE_NOT_FOUND';

  @override
  String toString() => message;
}
