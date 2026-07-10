/// POST /api/v1/auth/login/{provider} 응답 모델
///
/// TODO: 백엔드 LoginResponse 실제 필드명과 일치 여부 확인 후 수정
class LoginResponse {
  final String accessToken;
  final String refreshToken;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  @override
  String toString() =>
      'LoginResponse(accessToken: ${accessToken.substring(0, 10)}..., '
      'refreshToken: ${refreshToken.substring(0, 10)}...)';
}
