import 'package:flutter/material.dart';

import '../models/double_judgment_config.dart';
import '../models/game_session_state.dart';
import '../models/turn_result_event.dart';
import '../screens/batter_game_screen.dart';
import '../screens/game_over_screen.dart';
import '../screens/pitch_selection_screen.dart';
import '../screens/pitcher_game_screen.dart';
import '../screens/setup_screen.dart';
import 'game_flow_controller.dart';
import 'game_match_meta_service.dart';
import 'game_session_state_service.dart';
import 'game_websocket_service.dart';
import 'match_session_storage.dart';
import 'token_storage.dart';

/// 서버 state API 기준으로 재접속 화면을 복원합니다.
class GameSessionRestoreService {
  final _stateService = GameSessionStateService();
  final _metaService = GameMatchMetaService();
  final _tokenStorage = TokenStorage();
  final _ws = GameWebSocketService.instance;

  /// 로컬 [matchSessionId]로 상태를 조회하고 복원할 화면을 반환합니다.
  Future<Widget?> buildRestorePage(String matchSessionId) async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }

    // ignore: avoid_print
    print('[Restore] state API 조회 matchSessionId=$matchSessionId');
    final state = await _stateService.fetchState(matchSessionId);
    // ignore: avoid_print
    print('[Restore] phase=${state.phase.name} myRole=${state.myRole.name}');

    await MatchSessionCoordinator.onMatchFound(
      matchSessionId: state.matchSessionId,
      gameMode: state.gameMode,
    );

    if (state.phase == GameSessionPhase.ended) {
      await MatchSessionCoordinator.onSessionEnd();
      return GameOverScreen(
        gameMode: state.gameMode,
        myScore: state.myScore,
        opponentScore: state.opponentScore,
        didWin: state.myScore > state.opponentScore,
      );
    }

    // ignore: avoid_print
    print('[Restore] WS 연결 시작');
    await _ws.connectAndWait(accessToken: token);
    _ws.bootstrapMatchSession(state.matchSessionId);
    // ignore: avoid_print
    print('[Restore] WS 연결 완료 + 토픽 bootstrap');

    final setupNumbers = await _metaService.fetchSetupNumbers(state.matchSessionId);
    final doubleJudgment =
        await _metaService.fetchDoubleJudgment(state.matchSessionId);
    final lastResult = state.toLastTurnResultEvent();

    return switch (state.phase) {
      GameSessionPhase.setupNumbers => SetupScreen(
          gameMode: state.gameMode,
          matchSessionId: state.matchSessionId,
        ),
      GameSessionPhase.mulligan when state.allMulliganDone => _buildInGameScreen(
          state: state,
          setupNumbers: setupNumbers,
          doubleJudgment: doubleJudgment,
          lastResult: lastResult,
        ),
      GameSessionPhase.mulligan => PitchSelectionScreen(
          gameMode: state.gameMode,
          matchSessionId: state.matchSessionId,
          setupNumbers: setupNumbers,
          initialHandCards: state.myCardHand,
          myMulliganDone: state.myMulliganDone,
        ),
      GameSessionPhase.pitcherSelect ||
      GameSessionPhase.batterSelect =>
        _buildInGameScreen(
          state: state,
          setupNumbers: setupNumbers,
          doubleJudgment: doubleJudgment,
          lastResult: lastResult,
          restoredStartCoordinateNumber: state.phase == GameSessionPhase.batterSelect
              ? state.turn.startCoordinateNumber
              : null,
        ),
      GameSessionPhase.ended => null,
    };
  }

  Widget _buildInGameScreen({
    required GameSessionState state,
    required Map<String, List<int>> setupNumbers,
    required DoubleJudgmentConfig? doubleJudgment,
    required TurnResultEvent? lastResult,
    int? restoredStartCoordinateNumber,
  }) {
    final pitcherUserId = state.turn.pitcherUserId != 0
        ? state.turn.pitcherUserId
        : state.pitcherUserId;
    final handCards = state.myCardHand;
    final isPitcher = state.myRole == GameSessionRole.pitcher;

    GameFlowController.instance.registerSession(GameSessionContext(
      gameMode: state.gameMode,
      matchSessionId: state.matchSessionId,
      setupNumbers: setupNumbers,
      doubleJudgment: doubleJudgment,
      currentUserId: state.myUserId,
      initialPitcherUserId: pitcherUserId,
      handCards: handCards,
    ));

    _ws.subscribeGameTopic(
      matchSessionId: state.matchSessionId,
      currentUserId: state.myUserId,
      onEvent: (_) {},
      onAllReady: (_) {},
      onPitcherReady: isPitcher ? null : (_) {},
    );

    if (isPitcher) {
      return PitcherGameScreen(
        gameMode: state.gameMode,
        matchSessionId: state.matchSessionId,
        setupNumbers: setupNumbers,
        doubleJudgment: doubleJudgment,
        handCards: handCards,
        currentUserId: state.myUserId,
        initialPitcherUserId: pitcherUserId,
        lastResultEvent: lastResult,
      );
    }

    return BatterGameScreen(
      gameMode: state.gameMode,
      matchSessionId: state.matchSessionId,
      setupNumbers: setupNumbers,
      doubleJudgment: doubleJudgment,
      handCards: handCards,
      currentUserId: state.myUserId,
      initialPitcherUserId: pitcherUserId,
      lastResultEvent: lastResult,
      restoredStartCoordinateNumber: restoredStartCoordinateNumber,
    );
  }
}
