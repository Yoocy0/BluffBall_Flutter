import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/api_client.dart';
import '../models/card_hand_event.dart';
import '../models/mulligan_request.dart';
import '../models/setup_number_request.dart';

const _kStompPath = '/ws/websocket';

/// 게임 브로드캐스트 토픽 prefix
const _kGameTopic = '/topic/game/';

enum WsStatus { disconnected, connecting, connected, error }

/// 게임 세션 전체에서 유지되는 STOMP WebSocket 서비스.
///
/// 사용 흐름:
///   1. [connect] → onConnected / onError 콜백
///   2. [sendSetupNumbers] 로 셋업 숫자 제출
///   3. [subscribeGameTopic] 로 카드 이벤트 구독 시작
///   4. [sendMulligan] 으로 멀리건(교체/확정) 요청
///   5. 게임 종료 시 [disconnect]
class GameWebSocketService {
  GameWebSocketService._();
  static final GameWebSocketService instance = GameWebSocketService._();

  StompClient? _client;
  StompUnsubscribe? _gameTopicUnsub;

  bool get isConnected => _client?.connected ?? false;

  // ── connect ──────────────────────────────────────────────────────────────

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

  // ── Phase 2: 셋업 숫자 ────────────────────────────────────────────────────

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

  // ── Phase 3: 카드 구독 ────────────────────────────────────────────────────

  /// 게임 토픽을 구독해 [CardHandEvent]를 수신합니다.
  ///
  /// 이미 구독 중이면 기존 구독을 해제하고 재구독합니다.
  /// [currentUserId]와 이벤트의 targetUserId가 일치하는 메시지만 [onEvent]로 전달합니다.
  void subscribeGameTopic({
    required String matchSessionId,
    required int currentUserId,
    required void Function(CardHandEvent event) onEvent,
    required void Function(bool allReady) onAllReady,
  }) {
    _gameTopicUnsub?.call();

    final destination = '$_kGameTopic$matchSessionId';
    // ignore: avoid_print
    print('[WS] subscribeGameTopic → $destination (myUserId=$currentUserId)');

    _gameTopicUnsub = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body;
        // ignore: avoid_print
        print('[WS] 수신 raw: $body');
        if (body == null || body.isEmpty) return;
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final event = CardHandEvent.fromJson(json);
          // ignore: avoid_print
          print('[WS] CardHandEvent → targetUserId=${event.targetUserId}'
              ' fromMulligan=${event.fromMulligan}'
              ' allReady=${event.allMulliganReady}'
              ' cards=${event.cardInfos.length}장');
          if (event.targetUserId == currentUserId) {
            onEvent(event);
            if (event.allMulliganReady) {
              onAllReady(true);
            }
          } else {
            // ignore: avoid_print
            print('[WS] ⚠️ userId 불일치: 수신=${ event.targetUserId} / 내 userId=$currentUserId');
          }
        } catch (e) {
          // ignore: avoid_print
          print('[WS] ⚠️ 파싱 오류: $e / body=$body');
        }
      },
    );
  }

  void unsubscribeGameTopic() {
    _gameTopicUnsub?.call();
    _gameTopicUnsub = null;
  }

  // ── Phase 3: 멀리건 ───────────────────────────────────────────────────────

  /// 멀리건(교체) 요청.
  ///
  /// [cardIdsToSwap] 이 빈 리스트이면 현재 패를 그대로 확정합니다.
  bool sendMulligan({
    required String matchSessionId,
    required List<int> cardIdsToSwap,
  }) {
    if (!isConnected) return false;
    final req = MulliganRequest(cardIdsToSwap: cardIdsToSwap);
    _client!.send(
      destination: '/app/game/$matchSessionId/cards/mulligan',
      body: req.toJsonString(),
      headers: {'content-type': 'application/json'},
    );
    return true;
  }

  // ── disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    _gameTopicUnsub?.call();
    _gameTopicUnsub = null;
    _client?.deactivate();
    _client = null;
  }
}
