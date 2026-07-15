import 'package:dio/dio.dart';

import '../models/api_error.dart';
import '../services/auth_session_manager.dart';

/// API 401(AUTH_INVALID 등) 수신 시 로컬 토큰을 정리하고 로그인으로 보냅니다.
class AuthInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 401 &&
        response.requestOptions.headers.containsKey('Authorization')) {
      final data = response.data;
      final error = ApiError.fromResponse(
        statusCode: response.statusCode,
        data: data,
        fallbackMessage: '로그인이 만료되었습니다. 다시 로그인해주세요.',
      );
      AuthSessionManager.instance.handleUnauthorized(message: error.message);
    }
    handler.next(response);
  }
}
