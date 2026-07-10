import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/api_client.dart';
import '../models/setup_number_request.dart';

/// Spring Boot STOMP WebSocket 엔드포인트 경로.
///
/// 백엔드 WebSocketMessageBrokerConfigurer.registerStompEndpoints()에서
/// 등록한 경로와 일치해야 함 (예: registry.addEndpoint("/ws"))
const _kStompPath = '/ws/websocket';

enum WsStatus { disconnected, connecting, connected, error }

/// 게임 세션 동안 유지되는 STOMP WebSocket 서비스.
///
/// 사용 흐름:
///   1. [connect] 호출 → onConnected / onError 콜백 수신
///   2. [sendSetupNumbers] 로 셋업 숫자 제출
///   3. 화면 종료 시 [disconnect] 호출
class GameWebSocketService {
  GameWebSocketService._();
  static final GameWebSocketService instance = GameWebSocketService._();

  StompClient? _client;

  bool get isConnected => _client?.connected ?? false;

  // ── connect ──────────────────────────────────────────────────────────────

  /// WebSocket 연결을 시작합니다.
  ///
  /// [accessToken] : 인증 JWT  
  /// [onConnected] : 연결 성공 시 호출  
  /// [onError]     : 연결/STOMP 오류 시 호출 (메시지 포함)
  void connect({
    required String accessToken,
    required void Function() onConnected,
    required void Function(String message) onError,
  }) {
    final url = '${ApiClient.wsBaseUrl}$_kStompPath';

    _client = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
          'ngrok-skip-browser-warning': 'true',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
          'ngrok-skip-browser-warning': 'true',
        },
        connectionTimeout: const Duration(seconds: 10),
        // 게임 중에는 자동 재연결 하지 않음 (세션 만료 방지)
        reconnectDelay: Duration.zero,
        onConnect: (_) => onConnected(),
        onDisconnect: (_) {},
        onStompError: (frame) =>
            onError(frame.body?.isNotEmpty == true ? frame.body! : 'STOMP 오류'),
        onWebSocketError: (error) => onError('연결 오류: $error'),
      ),
    );

    _client!.activate();
  }

  // ── send ──────────────────────────────────────────────────────────────────

  /// Phase 2: 셋업 숫자 제출
  ///
  /// [matchSessionId] : 매치 세션 ID  
  /// [request]        : 카테고리별 번호 목록
  ///
  /// 연결이 되어 있지 않으면 [false]를 반환합니다.
  bool sendSetupNumbers({
    required String matchSessionId,
    required SetupNumberRequest request,
  }) {
    if (!isConnected) return false;

    _client!.send(
      destination: '/app/game/$matchSessionId/setup-numbers',
      body: request.toJsonString(),
      headers: {'content-type': 'application/json'},
    );
    return true;
  }

  // ── disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}
