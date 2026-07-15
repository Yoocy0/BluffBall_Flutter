import 'package:flutter/material.dart';
import '../models/card_info.dart';
import '../models/double_judgment_config.dart';
import '../models/game_mode.dart';
import '../models/turn_result_event.dart';
import '../navigation/app_navigator.dart';
import '../screens/batter_game_screen.dart';
import '../screens/game_over_screen.dart';
import '../screens/pitcher_game_screen.dart';
import '../screens/turn_result_screen.dart';
import 'game_websocket_service.dart';
import 'match_session_storage.dart';

/// 인게임 세션 컨텍스트 (턴 결과 수신 시 화면 전환에 사용).
class GameSessionContext {
  final GameMode gameMode;
  final String matchSessionId;
  final Map<String, List<int>> setupNumbers;
  final DoubleJudgmentConfig? doubleJudgment;
  final int currentUserId;
  final int initialPitcherUserId;
  final List<CardInfo> handCards;

  const GameSessionContext({
    required this.gameMode,
    required this.matchSessionId,
    required this.setupNumbers,
    this.doubleJudgment,
    required this.currentUserId,
    required this.initialPitcherUserId,
    required this.handCards,
  });

  GameSessionContext copyWith({
    int? initialPitcherUserId,
    List<CardInfo>? handCards,
    DoubleJudgmentConfig? doubleJudgment,
  }) =>
      GameSessionContext(
        gameMode: gameMode,
        matchSessionId: matchSessionId,
        setupNumbers: setupNumbers,
        doubleJudgment: doubleJudgment ?? this.doubleJudgment,
        currentUserId: currentUserId,
        initialPitcherUserId: initialPitcherUserId ?? this.initialPitcherUserId,
        handCards: handCards ?? this.handCards,
      );
}

/// TurnResultEvent 수신 → 주사위/결과 → 다음 턴 화면까지 중앙 네비게이션.
class GameFlowController {
  GameFlowController._();
  static final GameFlowController instance = GameFlowController._();

  GameSessionContext? _session;
  TurnResultEvent? _pendingResult;

  GameSessionContext? get session => _session;

  /// 매치 진입 시 세션 등록 + 결과 토픽 구독.
  void registerSession(GameSessionContext ctx) {
    _session = ctx;
    GameWebSocketService.instance.refreshResultTopicSubscription(ctx.matchSessionId);
    _tryDeliverPending();
  }

  void updateSession(GameSessionContext ctx) {
    _session = ctx;
    GameWebSocketService.instance.refreshResultTopicSubscription(ctx.matchSessionId);
    _tryDeliverPending();
  }

  /// WS 재연결·앱 복귀 시 결과 토픽 구독을 다시 맞춥니다.
  void refreshSubscriptions() {
    if (_session == null) return;
    GameWebSocketService.instance
        .refreshResultTopicSubscription(_session!.matchSessionId);
    _tryDeliverPending();
  }

  void clearSession() {
    _session = null;
    _pendingResult = null;
    MatchSessionCoordinator.onSessionEnd();
  }

  /// 공수 교대(RoleChangedEvent) 시 세션의 투수 ID만 갱신.
  void onRoleChanged(int pitcherUserId) {
    if (_session == null) return;
    _session = _session!.copyWith(initialPitcherUserId: pitcherUserId);
    // ignore: avoid_print
    print('[GameFlow] RoleChanged → pitcherUserId=$pitcherUserId');
  }

  /// WebSocket에서 TurnResultEvent 수신 시 호출.
  void onTurnResult(TurnResultEvent event) {
    // ignore: avoid_print
    print('[GameFlow] TurnResult 수신 → ${event.turnResult} 주사위=${event.diceResults}');
    final nav = rootNavigatorKey.currentState;
    if (nav == null || _session == null) {
      // ignore: avoid_print
      print('[GameFlow] Navigator/세션 없음 — pending 저장');
      _pendingResult = event;
      return;
    }
    _navigateToTurnResult(nav, event);
  }

  void _tryDeliverPending() {
    if (_pendingResult == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null || _session == null) return;
    final pending = _pendingResult!;
    _pendingResult = null;
    _navigateToTurnResult(nav, pending);
  }

  /// TurnResultScreen으로 전환.
  /// (주사위 0/1/2개 분기는 TurnResultScreen 내부 phase 로 처리)
  void _navigateToTurnResult(NavigatorState nav, TurnResultEvent event) {
    final ctx = _session!;
    nav.pushReplacement(PageRouteBuilder(
      pageBuilder: (context, anim1, anim2) => TurnResultScreen(
        gameMode: ctx.gameMode,
        matchSessionId: ctx.matchSessionId,
        event: event,
        setupNumbers: ctx.setupNumbers,
        currentUserId: ctx.currentUserId,
        myHandCards: ctx.handCards,
      ),
      transitionsBuilder: (context, anim, secAnim, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  /// 결과 3초 표시 후 다음 화면 (TurnResultScreen에서 호출).
  void navigateAfterResultCountdown(
    NavigatorState nav,
    GameSessionContext ctx,
    TurnResultEvent ev,
  ) {
    _session = ctx.copyWith(
      initialPitcherUserId: ev.pitcherUserId,
    );

    if (ev.gameOver) {
      final isHomeTeam = ev.isTop == (ev.pitcherUserId == ctx.currentUserId);
      final myScore = isHomeTeam ? ev.homeScore : ev.awayScore;
      final opponentScore = isHomeTeam ? ev.awayScore : ev.homeScore;

      nav.pushReplacement(MaterialPageRoute(
        builder: (_) => GameOverScreen(
          gameMode: ctx.gameMode,
          myScore: myScore,
          opponentScore: opponentScore,
          didWin: myScore > opponentScore,
        ),
      ));
      clearSession();
      return;
    }

    // 싱글모드: 구종 선택/멀리건은 게임 시작 시 1회만.
    // 이닝 전환(halfInningChanged) 시에도 역할에 맞는 게임 화면으로 바로 이동.
    final amIPitcher = ev.pitcherUserId == ctx.currentUserId;

    if (amIPitcher) {
      nav.pushReplacement(PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => PitcherGameScreen(
          gameMode: ctx.gameMode,
          matchSessionId: ctx.matchSessionId,
          setupNumbers: ctx.setupNumbers,
          doubleJudgment: ctx.doubleJudgment,
          handCards: ctx.handCards,
          currentUserId: ctx.currentUserId,
          initialPitcherUserId: ev.pitcherUserId,
          lastResultEvent: ev,
        ),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    } else {
      nav.pushReplacement(PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => BatterGameScreen(
          gameMode: ctx.gameMode,
          matchSessionId: ctx.matchSessionId,
          setupNumbers: ctx.setupNumbers,
          doubleJudgment: ctx.doubleJudgment,
          handCards: ctx.handCards,
          currentUserId: ctx.currentUserId,
          initialPitcherUserId: ev.pitcherUserId,
          lastResultEvent: ev,
        ),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    }
  }
}
