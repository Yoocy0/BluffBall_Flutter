import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/game_mode.dart';
import '../navigation/app_navigator.dart';
import '../screens/game_over_screen.dart';
import 'game_websocket_service.dart';
import 'match_session_storage.dart';

/// 인게임 자진 포기(몰수패) 처리.
class GameForfeitService {
  GameForfeitService._();
  static final GameForfeitService instance = GameForfeitService._();

  bool _isProcessing = false;

  Future<void> leaveMatchWithForfeit({
    required GameMode gameMode,
    required String matchSessionId,
  }) async {
    if (_isProcessing || matchSessionId.isEmpty) return;
    _isProcessing = true;

    try {
      GameWebSocketService.instance.markGameEndHandled();
      try {
        await ApiClient().dio.post('/api/v1/game/$matchSessionId/forfeit');
      } catch (e) {
        // ignore: avoid_print
        print('[Forfeit] API 실패 — WS disconnect로 몰수 처리 시도: $e');
      }

      final nav = rootNavigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => GameOverScreen(
              gameMode: gameMode,
              myScore: 0,
              opponentScore: 10,
              didWin: false,
              isForfeit: true,
            ),
          ),
          (_) => false,
        );
      }

      Future.microtask(GameWebSocketService.instance.disconnect);
      await MatchSessionCoordinator.onSessionEnd();
    } finally {
      _isProcessing = false;
    }
  }
}
