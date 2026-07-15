import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/api_client.dart';
import '../models/batter_card_select_request.dart';
import '../models/card_hand_event.dart';
import '../models/game_end_event.dart';
import '../models/mulligan_request.dart';
import '../models/pitcher_card_select_request.dart';
import '../models/pitcher_ready_event.dart';
import '../models/presence_event.dart';
import '../models/setup_number_request.dart';
import '../models/turn_result_event.dart';
import '../navigation/app_navigator.dart';
import '../screens/game_over_screen.dart';
import '../screens/home_screen.dart';
import 'game_flow_controller.dart';
import 'game_presence_controller.dart';

const _kStompPath = '/ws/websocket';
const _kHeartbeatInterval = Duration(seconds: 20);

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
  StompUnsubscribe? _resultTopicUnsub;
  StompUnsubscribe? _endTopicUnsub;
  StompUnsubscribe? _presenceTopicUnsub;
  String? _resultMatchSessionId;
  String? _endMatchSessionId;
  String? _presenceMatchSessionId;
  String? _heartbeatMatchSessionId;
  Timer? _heartbeatTimer;
  Timer? _pendingGameEndTimer;
  bool _gameEndHandled = false;
  String? _gameTopicMatchSessionId;
  int? _gameTopicUserId;
  String? _lastAccessToken;
  void Function()? _onConnectedCallback;
  void Function(String message)? _onErrorCallback;

  /// 구독 전 도착한 CardHandEvent (away 등 늦게 PitchSelection 진입 시 복구용)
  final Map<int, CardHandEvent> _cardHandBuffer = {};

  // 게임 토픽 콜백 (화면 전환 후에도 유지)
  void Function(CardHandEvent event)? _onCardHand;
  void Function(bool allReady)? _onAllMulliganReady;
  void Function(PitcherReadyEvent event)? _onPitcherReady;

  bool get isConnected => _client?.connected ?? false;

  /// TurnResult(gameOver) 흐름이 종료 화면을 처리했음을 표시합니다.
  void markGameEndHandled() {
    _gameEndHandled = true;
    _pendingGameEndTimer?.cancel();
    _pendingGameEndTimer = null;
  }

  void _resetGameEndState() {
    _gameEndHandled = false;
    _pendingGameEndTimer?.cancel();
    _pendingGameEndTimer = null;
  }

  /// JWT로 WS 연결 완료까지 대기 (재접속 복원용).
  Future<void> connectAndWait({required String accessToken}) async {
    if (isConnected && _lastAccessToken == accessToken) return;

    final completer = Completer<void>();
    connect(
      accessToken: accessToken,
      onConnected: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (msg) {
        if (!completer.isCompleted) completer.completeError(msg);
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw TimeoutException('WebSocket 연결 시간 초과'),
    );
  }

  // ── connect ──────────────────────────────────────────────────────────────

  void connect({
    required String accessToken,
    required void Function() onConnected,
    required void Function(String message) onError,
  }) {
    _resetGameEndState();
    _lastAccessToken = accessToken;
    _onConnectedCallback = onConnected;
    _onErrorCallback = onError;

    // 재연결 시 이전 STOMP 구독 핸들은 무효 — 토픽 ID는 유지하고 onConnect에서 재구독
    _gameTopicUnsub?.call();
    _gameTopicUnsub = null;
    _resultTopicUnsub?.call();
    _resultTopicUnsub = null;
    _endTopicUnsub?.call();
    _endTopicUnsub = null;
    _presenceTopicUnsub?.call();
    _presenceTopicUnsub = null;
    _stopPresenceHeartbeat();
    _client?.deactivate();

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
        onConnect: (_) {
          _onConnectedCallback?.call();
          _resubscribeTopicsAfterConnect();
        },
        onDisconnect: (_) {
          _gameTopicUnsub = null;
          _resultTopicUnsub = null;
          _endTopicUnsub = null;
          _presenceTopicUnsub = null;
          _stopPresenceHeartbeat();
        },
        onStompError: (frame) => _onErrorCallback?.call(
          frame.body?.isNotEmpty == true ? frame.body! : 'STOMP 오류',
        ),
        onWebSocketError: (error) =>
            _onErrorCallback?.call('연결 오류: $error'),
      ),
    );
    _client!.activate();
  }

  /// 앱 복귀 등 — 연결·구독 상태를 다시 맞춥니다.
  void refreshConnectionAndSubscriptions() {
    if (_lastAccessToken == null) return;
    if (isConnected) {
      _resubscribeTopicsAfterConnect();
      return;
    }
    connect(
      accessToken: _lastAccessToken!,
      onConnected: _onConnectedCallback ?? () {},
      onError: _onErrorCallback ?? (_) {},
    );
  }

  void _resubscribeTopicsAfterConnect() {
    final gameId = _gameTopicMatchSessionId;
    final userId = _gameTopicUserId;
    if (gameId != null &&
        userId != null &&
        _onCardHand != null &&
        _onAllMulliganReady != null) {
      _gameTopicUnsub = null;
      subscribeGameTopic(
        matchSessionId: gameId,
        currentUserId: userId,
        onEvent: _onCardHand!,
        onAllReady: _onAllMulliganReady!,
        onPitcherReady: _onPitcherReady,
      );
    }

    final resultId =
        _resultMatchSessionId ?? GameFlowController.instance.session?.matchSessionId;
    if (resultId != null && resultId.isNotEmpty) {
      refreshResultTopicSubscription(resultId);
    }

    final endId = _endMatchSessionId ?? resultId;
    if (endId != null && endId.isNotEmpty) {
      ensureEndTopicSubscription(endId);
    }

    final presenceId = _presenceMatchSessionId ?? endId;
    if (presenceId != null && presenceId.isNotEmpty) {
      ensurePresenceTopicSubscription(presenceId);
      startPresenceHeartbeat(presenceId);
    }
  }

  /// 매치 진입 시 presence/end/result 구독 + heartbeat 시작.
  void bootstrapMatchSession(String matchSessionId) {
    _resultMatchSessionId = matchSessionId;
    _endMatchSessionId = matchSessionId;
    _presenceMatchSessionId = matchSessionId;
    if (isConnected) {
      refreshResultTopicSubscription(matchSessionId);
      ensureEndTopicSubscription(matchSessionId);
      ensurePresenceTopicSubscription(matchSessionId);
      startPresenceHeartbeat(matchSessionId);
    }
  }

  /// 재접속 준비 — 토픽 ID를 미리 등록해 onConnect 시 재구독되게 합니다.
  void primeReconnectTopics({required String matchSessionId}) {
    bootstrapMatchSession(matchSessionId);
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

  /// 버퍼에 저장된 CardHandEvent를 꺼냅니다 (없으면 null).
  CardHandEvent? takeBufferedCardHand(int userId) =>
      _cardHandBuffer.remove(userId);

  /// 게임 토픽 STOMP 구독 + 콜백 등록.
  ///
  /// 같은 [matchSessionId]면 STOMP 재구독 없이 콜백만 갱신합니다.
  void subscribeGameTopic({
    required String matchSessionId,
    required int currentUserId,
    required void Function(CardHandEvent event) onEvent,
    required void Function(bool allReady) onAllReady,
    void Function(PitcherReadyEvent event)? onPitcherReady,
  }) {
    _onCardHand = onEvent;
    _onAllMulliganReady = onAllReady;
    _onPitcherReady = onPitcherReady;
    _gameTopicUserId = currentUserId;

    if (_gameTopicUnsub != null &&
        _gameTopicMatchSessionId == matchSessionId) {
      return;
    }

    _gameTopicUnsub?.call();
    _gameTopicMatchSessionId = matchSessionId;

    final destination = '$_kGameTopic$matchSessionId';
    // ignore: avoid_print
    print('[WS] subscribeGameTopic → $destination (myUserId=$currentUserId)');

    _gameTopicUnsub = _client?.subscribe(
      destination: destination,
      callback: _handleGameTopicFrame,
    );
  }

  void _handleGameTopicFrame(StompFrame frame) {
    final body = frame.body;
    // ignore: avoid_print
    print('[WS] 수신 raw: $body');
    if (body == null || body.isEmpty) return;

    final userId = _gameTopicUserId;
    if (userId == null) return;

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (json.containsKey('startCoordinateNumber')) {
        final event = PitcherReadyEvent.fromJson(json);
        // ignore: avoid_print
        print('[WS] PitcherReadyEvent → startCoord=${event.startCoordinateNumber}');
        _onPitcherReady?.call(event);
        return;
      }

      if (json.containsKey('cards')) {
        final event = CardHandEvent.fromJson(json);
        // ignore: avoid_print
        print('[WS] CardHandEvent → targetUserId=${event.targetUserId}'
            ' fromMulligan=${event.fromMulligan}'
            ' allReady=${event.allMulliganReady}'
            ' cards=${event.cardInfos.length}장');

        _cardHandBuffer[event.targetUserId] = event;

        if (event.targetUserId == userId) {
          _onCardHand?.call(event);
          if (event.allMulliganReady) {
            _onAllMulliganReady?.call(true);
          }
        } else {
          // ignore: avoid_print
          print('[WS] ⚠️ userId 불일치: 수신=${event.targetUserId} / 내 userId=$userId');
        }
        return;
      }

      // RoleChangedEvent (공수 교대 — 멀리건/드로우 없음)
      if (json.containsKey('pitcherUserId') &&
          !json.containsKey('turnResult')) {
        final pitcherId = (json['pitcherUserId'] as num).toInt();
        // ignore: avoid_print
        print('[WS] RoleChangedEvent → pitcherUserId=$pitcherId');
        GameFlowController.instance.onRoleChanged(pitcherId);
        return;
      }

      // ignore: avoid_print
      print('[WS] 알 수 없는 이벤트 타입: $json');
    } catch (e) {
      // ignore: avoid_print
      print('[WS] ⚠️ 파싱 오류: $e / body=$body');
    }
  }

  void unsubscribeGameTopic() {
    _gameTopicUnsub?.call();
    _gameTopicUnsub = null;
    _gameTopicMatchSessionId = null;
    _gameTopicUserId = null;
    _onCardHand = null;
    _onAllMulliganReady = null;
    _onPitcherReady = null;
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

  // ── Phase 5: 타자 카드 선택 ───────────────────────────────────────────────

  /// 타자의 예측 좌표 + 타이밍을 서버에 전송합니다.
  ///
  /// [responseTimeSec] : PitcherReadyEvent 수신 후 경과 시간(초). 5초 초과 = 스윙 미발동
  bool sendBatterSelectCard({
    required String matchSessionId,
    required double responseTimeSec,
    required int batterCoordinateNumber,
    required String timing, // 'TOO_EARLY' | 'EARLY' | 'NORMAL' | 'LATE' | 'TOO_LATE'
  }) {
    if (!isConnected) return false;
    final req = BatterCardSelectRequest(
      responseTimeSec: responseTimeSec,
      batterCoordinateNumber: batterCoordinateNumber,
      timing: timing,
    );
    _client!.send(
      destination: '/app/game/$matchSessionId/batter/select-card',
      body: req.toJsonString(),
      headers: {'content-type': 'application/json'},
    );
    return true;
  }

  // ── Phase 4: 투수 카드 선택 ───────────────────────────────────────────────

  /// 투수의 구종 카드 + 시작 좌표 카드를 서버에 전송합니다.
  ///
  /// [pitchCardId]   : 선택한 구종 카드 ID (CardInfo.cardId)
  /// [coordinateCardId] : 선택한 좌표 카드 ID (CoordinateCard.id)
  bool sendPitcherSelectCard({
    required String matchSessionId,
    required int pitchCardId,
    required int coordinateCardId,
  }) {
    if (!isConnected) return false;
    final req = PitcherCardSelectRequest(
      pitchCardId: pitchCardId,
      coordinateCardId: coordinateCardId,
    );
    _client!.send(
      destination: '/app/game/$matchSessionId/pitcher/select-card',
      body: req.toJsonString(),
      headers: {'content-type': 'application/json'},
    );
    return true;
  }

  // ── 결과 토픽 구독 (/topic/game/{id}/result) ──────────────────────────────

  /// 결과 토픽 STOMP 구독을 보장합니다 (매치당 1회).
  void ensureResultTopicSubscription(String matchSessionId) {
    _resultMatchSessionId = matchSessionId;
    if (!isConnected) {
      // ignore: avoid_print
      print('[WS] ⚠️ ensureResultTopicSubscription: WS 미연결 (pending=$matchSessionId)');
      return;
    }
    if (_resultTopicUnsub != null &&
        _resultMatchSessionId == matchSessionId) {
      return;
    }

    _resultTopicUnsub?.call();

    final destination = '$_kGameTopic$matchSessionId/result';
    // ignore: avoid_print
    print('[WS] ensureResultTopicSubscription → $destination');

    _resultTopicUnsub = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body;
        // ignore: avoid_print
        print('[WS] 결과 수신 raw: $body');
        if (body == null || body.isEmpty) return;
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final event = TurnResultEvent.fromJson(json);
          // ignore: avoid_print
          print('[WS] TurnResultEvent → ${event.turnResult} 주사위=${event.diceResults}');
          GameFlowController.instance.onTurnResult(event);
        } catch (e, st) {
          // ignore: avoid_print
          print('[WS] ⚠️ 결과 파싱 오류: $e / body=$body\n$st');
        }
      },
    );

    if (_resultTopicUnsub == null) {
      // ignore: avoid_print
      print('[WS] ⚠️ 결과 토픽 구독 실패 (client=${_client != null})');
    }
  }

  /// 재연결 후 stale 구독을 피하기 위해 결과 토픽을 강제 재구독합니다.
  void refreshResultTopicSubscription(String matchSessionId) {
    _resultTopicUnsub?.call();
    _resultTopicUnsub = null;
    ensureResultTopicSubscription(matchSessionId);
  }

  /// 경기 종료 토픽 STOMP 구독을 보장합니다.
  void ensureEndTopicSubscription(String matchSessionId) {
    _endMatchSessionId = matchSessionId;
    if (!isConnected) {
      // ignore: avoid_print
      print('[WS] ⚠️ ensureEndTopicSubscription: WS 미연결 (pending=$matchSessionId)');
      return;
    }
    if (_endTopicUnsub != null && _endMatchSessionId == matchSessionId) {
      return;
    }

    _endTopicUnsub?.call();

    final destination = '$_kGameTopic$matchSessionId/end';
    // ignore: avoid_print
    print('[WS] ensureEndTopicSubscription → $destination');

    _endTopicUnsub = _client?.subscribe(
      destination: destination,
      callback: _handleEndTopicFrame,
    );
  }

  void _handleEndTopicFrame(StompFrame frame) {
    final body = frame.body;
    // ignore: avoid_print
    print('[WS] 경기 종료 수신 raw: $body');
    if (body == null || body.isEmpty) return;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final event = GameEndEvent.fromJson(json);
      _scheduleGameEndNavigation(() => _navigateToGameEnd(event), event);
    } catch (e) {
      // ignore: avoid_print
      print('[WS] GameEndEvent 파싱 실패, raw payload 사용: $e');
      _scheduleGameEndNavigation(
        () => _navigateToGameEndFromPayload(body),
        null,
      );
    }
  }

  /// /result 턴 결과가 먼저 도착할 시간을 주고, 미처리 시 /end 로 GameOver 로 폴백합니다.
  void _scheduleGameEndNavigation(
    void Function() navigate,
    GameEndEvent? event,
  ) {
    if (_gameEndHandled) return;

    final hasActiveSession = GameFlowController.instance.session != null;
    final immediate = event?.isForfeit == true || !hasActiveSession;

    if (immediate) {
      navigate();
      return;
    }

    _pendingGameEndTimer?.cancel();
    _pendingGameEndTimer = Timer(const Duration(seconds: 4), () {
      if (!_gameEndHandled) navigate();
    });
  }

  void _navigateToGameEnd(GameEndEvent event) {
    if (_gameEndHandled) return;
    _gameEndHandled = true;
    _pendingGameEndTimer?.cancel();
    _pendingGameEndTimer = null;

    final nav = rootNavigatorKey.currentState;
    final ctx = GameFlowController.instance.session;
    if (nav == null) return;

    final gameMode = event.gameMode ?? ctx?.gameMode;
    final myUserId = ctx?.currentUserId;

    if (gameMode == null || myUserId == null) {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      Future.microtask(disconnect);
      return;
    }

    final myScore = event.scoreForUser(myUserId);
    final opponentScore = event.opponentScoreForUser(myUserId);

    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameOverScreen(
          gameMode: gameMode,
          myScore: myScore,
          opponentScore: opponentScore,
          didWin: myScore > opponentScore,
          endReason: event.reason,
          isForfeit: event.isForfeit,
        ),
      ),
    );
    Future.microtask(disconnect);
  }

  void _navigateToGameEndFromPayload(String? body) {
    if (_gameEndHandled) return;
    _gameEndHandled = true;
    _pendingGameEndTimer?.cancel();
    _pendingGameEndTimer = null;

    final nav = rootNavigatorKey.currentState;
    final ctx = GameFlowController.instance.session;
    if (nav == null) return;

    final gameMode = ctx?.gameMode;
    final myUserId = ctx?.currentUserId;
    var homeScore = 0;
    var awayScore = 0;
    var isHomeTeam = true;
    final participants = <int>[];

    if (body != null && body.isNotEmpty) {
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final board = json['board'] as Map<String, dynamic>?;
        if (board != null) {
          homeScore = (board['homeScore'] as num?)?.toInt() ?? 0;
          awayScore = (board['awayScore'] as num?)?.toInt() ?? 0;
        } else {
          homeScore = (json['homeScore'] as num?)?.toInt() ?? 0;
          awayScore = (json['awayScore'] as num?)?.toInt() ?? 0;
        }
        final ids = json['participantUserIds'];
        if (ids is List) {
          participants.addAll(ids.map((e) => (e as num).toInt()));
        }
        final payloadUserId = (json['myUserId'] as num?)?.toInt();
        if (participants.length >= 2) {
          final uid = payloadUserId ?? myUserId;
          if (uid != null) isHomeTeam = uid == participants.first;
        }
      } catch (_) {}
    }

    if (ctx == null || gameMode == null || myUserId == null) {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      Future.microtask(disconnect);
      return;
    }

    final myScore = isHomeTeam ? homeScore : awayScore;
    final opponentScore = isHomeTeam ? awayScore : homeScore;

    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameOverScreen(
          gameMode: gameMode,
          myScore: myScore,
          opponentScore: opponentScore,
          didWin: myScore > opponentScore,
        ),
      ),
    );
    Future.microtask(disconnect);
  }

  void refreshEndTopicSubscription(String matchSessionId) {
    _endTopicUnsub?.call();
    _endTopicUnsub = null;
    ensureEndTopicSubscription(matchSessionId);
  }

  // ── presence 토픽 (/topic/game/{id}/presence) ─────────────────────────────

  void ensurePresenceTopicSubscription(String matchSessionId) {
    _presenceMatchSessionId = matchSessionId;
    if (!isConnected) {
      // ignore: avoid_print
      print('[WS] ⚠️ ensurePresenceTopicSubscription: WS 미연결 (pending=$matchSessionId)');
      return;
    }
    if (_presenceTopicUnsub != null &&
        _presenceMatchSessionId == matchSessionId) {
      return;
    }

    _presenceTopicUnsub?.call();

    final destination = '$_kGameTopic$matchSessionId/presence';
    // ignore: avoid_print
    print('[WS] ensurePresenceTopicSubscription → $destination');

    _presenceTopicUnsub = _client?.subscribe(
      destination: destination,
      callback: _handlePresenceTopicFrame,
    );
  }

  void _handlePresenceTopicFrame(StompFrame frame) {
    final body = frame.body;
    // ignore: avoid_print
    print('[WS] presence 수신 raw: $body');
    if (body == null || body.isEmpty) return;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final event = parsePresenceEvent(json);
      if (event != null) {
        GamePresenceController.instance.handlePresenceEvent(event);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[WS] ⚠️ presence 파싱 오류: $e / body=$body');
    }
  }

  void refreshPresenceTopicSubscription(String matchSessionId) {
    _presenceTopicUnsub?.call();
    _presenceTopicUnsub = null;
    ensurePresenceTopicSubscription(matchSessionId);
  }

  // ── heartbeat (/app/game/{id}/presence/heartbeat) ─────────────────────────

  void startPresenceHeartbeat(String matchSessionId) {
    _heartbeatMatchSessionId = matchSessionId;
    _heartbeatTimer?.cancel();
    sendPresenceHeartbeat(matchSessionId);
    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) {
      final id = _heartbeatMatchSessionId;
      if (id != null && isConnected) sendPresenceHeartbeat(id);
    });
  }

  void _stopPresenceHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatMatchSessionId = null;
  }

  bool sendPresenceHeartbeat(String matchSessionId) {
    if (!isConnected) return false;
    _client!.send(
      destination: '/app/game/$matchSessionId/presence/heartbeat',
      body: '{}',
      headers: {'content-type': 'application/json'},
    );
    return true;
  }

  void unsubscribeResultTopic() {
    _resultTopicUnsub?.call();
    _resultTopicUnsub = null;
    _resultMatchSessionId = null;
  }

  // ── disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    _pendingGameEndTimer?.cancel();
    _pendingGameEndTimer = null;
    _stopPresenceHeartbeat();
    GamePresenceController.instance.clear();
    _gameTopicUnsub?.call();
    _gameTopicUnsub = null;
    _gameTopicMatchSessionId = null;
    _gameTopicUserId = null;
    _onCardHand = null;
    _onAllMulliganReady = null;
    _onPitcherReady = null;
    _cardHandBuffer.clear();
    _resultTopicUnsub?.call();
    _resultTopicUnsub = null;
    _resultMatchSessionId = null;
    _endTopicUnsub?.call();
    _endTopicUnsub = null;
    _endMatchSessionId = null;
    _presenceTopicUnsub?.call();
    _presenceTopicUnsub = null;
    _presenceMatchSessionId = null;
    GameFlowController.instance.clearSession();
    _lastAccessToken = null;
    _onConnectedCallback = null;
    _onErrorCallback = null;
    _client?.deactivate();
    _client = null;
  }
}
