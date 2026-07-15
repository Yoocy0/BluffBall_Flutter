import 'package:flutter/material.dart';

import '../navigation/app_navigator.dart';
import '../screens/login_screen.dart';
import 'game_websocket_service.dart';
import 'token_storage.dart';

/// 401 등 인증 만료 시 로컬 세션 정리 + 로그인 화면 이동.
class AuthSessionManager {
  AuthSessionManager._();
  static final AuthSessionManager instance = AuthSessionManager._();

  bool _handling = false;

  Future<void> handleUnauthorized({String? message}) async {
    if (_handling) return;
    _handling = true;
    try {
      await TokenStorage().clear();
      // matchSessionId는 유지 — 재로그인 후 재접속 배너에서 복원 가능.
      GameWebSocketService.instance.disconnect();

      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

      if (message != null && message.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx == null) return;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: const Color(0xFF3A1A05),
            ),
          );
        });
      }
    } finally {
      _handling = false;
    }
  }
}
