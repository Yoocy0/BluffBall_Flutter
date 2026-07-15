import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/game_mode.dart';

/// 로컬에 저장된 진행 중 매치 정보.
class SavedMatchSession {
  final String matchSessionId;
  final GameMode gameMode;

  const SavedMatchSession({
    required this.matchSessionId,
    required this.gameMode,
  });
}

/// 진행 중인 [matchSessionId]를 기기 보안 저장소에 저장·조회·삭제.
class MatchSessionStorage {
  static const _kMatchSessionId = 'match_session_id';
  static const _kGameMode = 'match_session_game_mode';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(SavedMatchSession session) async {
    await Future.wait([
      _storage.write(key: _kMatchSessionId, value: session.matchSessionId),
      _storage.write(key: _kGameMode, value: session.gameMode.name),
    ]);
  }

  Future<SavedMatchSession?> load() async {
    final matchSessionId = await _storage.read(key: _kMatchSessionId);
    final gameModeName = await _storage.read(key: _kGameMode);
    if (matchSessionId == null ||
        matchSessionId.isEmpty ||
        gameModeName == null ||
        gameModeName.isEmpty) {
      return null;
    }

    final gameMode = GameMode.values
        .where((mode) => mode.name == gameModeName)
        .firstOrNull;
    if (gameMode == null) return null;

    return SavedMatchSession(
      matchSessionId: matchSessionId,
      gameMode: gameMode,
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kMatchSessionId),
      _storage.delete(key: _kGameMode),
    ]);
  }
}

/// 저장/삭제/복원 시점을 한곳에서 처리.
class MatchSessionCoordinator {
  MatchSessionCoordinator._();

  static final _storage = MatchSessionStorage();

  /// 매칭 성공 시 호출.
  static Future<void> onMatchFound({
    required String? matchSessionId,
    required GameMode gameMode,
  }) async {
    if (matchSessionId == null || matchSessionId.isEmpty) return;
    await _storage.save(SavedMatchSession(
      matchSessionId: matchSessionId,
      gameMode: gameMode,
    ));
  }

  /// 새 매칭 큐 진입 시 이전 세션 제거.
  static Future<void> onQueueJoin() => _storage.clear();

  /// 게임 종료·로그아웃 등 세션 종료 시 호출.
  static Future<void> onSessionEnd() => _storage.clear();

  /// 앱 재시작 후 홈 진입 시 복원할 세션이 있으면 반환.
  static Future<SavedMatchSession?> tryRestore() => _storage.load();
}
