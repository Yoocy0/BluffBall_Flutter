import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/presence_event.dart';

/// 상대 disconnect/reconnect UI 상태 (120초 카운트다운).
class GamePresenceController extends ChangeNotifier {
  GamePresenceController._();
  static final GamePresenceController instance = GamePresenceController._();

  bool _visible = false;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  bool get isOpponentDisconnectedVisible => _visible;
  int get remainingSeconds => _remainingSeconds;

  void handlePresenceEvent(PresenceEvent event) {
    switch (event) {
      case OpponentDisconnectedEvent(:final remainingSeconds):
        _showCountdown(remainingSeconds);
      case OpponentReconnectedEvent():
        _hideCountdown();
    }
  }

  void _showCountdown(int seconds) {
    _countdownTimer?.cancel();
    _visible = true;
    _remainingSeconds = seconds.clamp(0, 999);
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        _remainingSeconds = 0;
        timer.cancel();
      } else {
        _remainingSeconds--;
      }
      notifyListeners();
    });
  }

  void _hideCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _visible = false;
    _remainingSeconds = 0;
    notifyListeners();
  }

  void clear() => _hideCountdown();
}
