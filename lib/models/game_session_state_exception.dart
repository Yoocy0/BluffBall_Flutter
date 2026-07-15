/// GET /api/v1/game/{matchSessionId}/state 오류.
class GameSessionStateException implements Exception {
  final int? status;
  final String code;
  final String message;

  const GameSessionStateException({
    required this.status,
    required this.code,
    required this.message,
  });

  bool get shouldClearLocalSession => switch (status) {
        403 => true,
        404 => true,
        _ => false,
      };

  factory GameSessionStateException.fromResponse({
    required int? statusCode,
    required dynamic data,
  }) {
    if (data is Map<String, dynamic>) {
      return GameSessionStateException(
        status: (data['status'] as num?)?.toInt() ?? statusCode,
        code: (data['code'] as String?) ?? 'UNKNOWN',
        message: (data['message'] as String?) ?? _defaultMessage(statusCode),
      );
    }
    return GameSessionStateException(
      status: statusCode,
      code: 'UNKNOWN',
      message: _defaultMessage(statusCode),
    );
  }

  static String _defaultMessage(int? status) => switch (status) {
        401 => '로그인이 만료되었습니다. 다시 로그인해주세요.',
        403 => '이 매치에 참가하지 않은 계정입니다.',
        404 => '진행 중인 게임을 찾을 수 없습니다.',
        _ => '게임 상태를 불러오지 못했습니다.',
      };

  @override
  String toString() => message;
}
