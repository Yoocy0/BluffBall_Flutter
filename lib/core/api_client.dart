import 'package:dio/dio.dart';

/// Dio 싱글턴 클라이언트
///
/// baseUrl 설정:
///   - Android 에뮬레이터 → 'http://10.0.2.2:8080'
///   - iOS 시뮬레이터     → 'http://localhost:8080'
///   - 실 기기(개발)      → 'http://{PC_로컬_IP}:8080'
///   - 운영 서버          → 'https://api.bluffball.com'  (TODO: 실제 도메인으로 교체)
class ApiClient {
  static const String baseUrl = 'https://zula-unelidible-thea.ngrok-free.dev';

  /// STOMP WebSocket 엔드포인트 (https → wss)
  static const String wsUrl = 'wss://zula-unelidible-thea.ngrok-free.dev/ws';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          // ngrok 무료 티어 브라우저 경고 페이지 스킵
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, logPrint: _log),
    );
  }

  void _log(Object object) {
    // ignore: avoid_print
    print('[API] $object');
  }
}
