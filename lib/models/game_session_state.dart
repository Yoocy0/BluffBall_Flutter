import 'card_info.dart';
import 'game_mode.dart';
import 'turn_result_event.dart';

enum GameSessionPhase {
  setupNumbers,
  mulligan,
  pitcherSelect,
  batterSelect,
  ended;

  static GameSessionPhase? fromApi(String? value) => switch (value) {
        'SETUP_NUMBERS' => GameSessionPhase.setupNumbers,
        'MULLIGAN' => GameSessionPhase.mulligan,
        'PITCHER_SELECT' => GameSessionPhase.pitcherSelect,
        'BATTER_SELECT' => GameSessionPhase.batterSelect,
        'ENDED' => GameSessionPhase.ended,
        _ => null,
      };
}

enum GameSessionRole {
  pitcher,
  batter;

  static GameSessionRole? fromApi(String? value) => switch (value) {
        'PITCHER' => GameSessionRole.pitcher,
        'BATTER' => GameSessionRole.batter,
        _ => null,
      };
}

class GameBoardState {
  final int turnNumber;
  final int totalInnings;
  final int inning;
  final bool isTop;
  final int homeScore;
  final int awayScore;
  final int balls;
  final int strikes;
  final int outs;
  final bool firstBase;
  final bool secondBase;
  final bool thirdBase;
  final bool initialized;
  final bool gameOver;

  const GameBoardState({
    required this.turnNumber,
    required this.totalInnings,
    required this.inning,
    required this.isTop,
    required this.homeScore,
    required this.awayScore,
    required this.balls,
    required this.strikes,
    required this.outs,
    required this.firstBase,
    required this.secondBase,
    required this.thirdBase,
    required this.initialized,
    required this.gameOver,
  });

  factory GameBoardState.fromJson(Map<String, dynamic> json) => GameBoardState(
        turnNumber: _int(json['turnNumber']),
        totalInnings: _int(json['totalInnings']),
        inning: _int(json['inning'], fallback: 1),
        isTop: _bool(json['isTop'], fallback: true),
        homeScore: _int(json['homeScore']),
        awayScore: _int(json['awayScore']),
        balls: _int(json['balls']),
        strikes: _int(json['strikes']),
        outs: _int(json['outs']),
        firstBase: _bool(json['firstBase']),
        secondBase: _bool(json['secondBase']),
        thirdBase: _bool(json['thirdBase']),
        initialized: _bool(json['initialized']),
        gameOver: _bool(json['gameOver']),
      );
}

class GameTurnState {
  final int turnNumber;
  final int pitcherUserId;
  final int batterUserId;
  final bool pitcherSelectionComplete;
  final bool batterSelectionComplete;
  final int startCoordinateNumber;

  const GameTurnState({
    required this.turnNumber,
    required this.pitcherUserId,
    required this.batterUserId,
    required this.pitcherSelectionComplete,
    required this.batterSelectionComplete,
    required this.startCoordinateNumber,
  });

  factory GameTurnState.fromJson(Map<String, dynamic> json) => GameTurnState(
        turnNumber: _int(json['turnNumber']),
        pitcherUserId: _int(json['pitcherUserId']),
        batterUserId: _int(json['batterUserId']),
        pitcherSelectionComplete: _bool(json['pitcherSelectionComplete']),
        batterSelectionComplete: _bool(json['batterSelectionComplete']),
        startCoordinateNumber: _int(json['startCoordinateNumber']),
      );
}

class LastTurnResultState {
  final int turnNumber;
  final String turnResult;
  final int finalCoordinateNumber;
  final String pitchTiming;
  final String pitchCardName;
  final List<int> diceResults;

  const LastTurnResultState({
    required this.turnNumber,
    required this.turnResult,
    required this.finalCoordinateNumber,
    required this.pitchTiming,
    required this.pitchCardName,
    required this.diceResults,
  });

  factory LastTurnResultState.fromJson(Map<String, dynamic> json) =>
      LastTurnResultState(
        turnNumber: _int(json['turnNumber']),
        turnResult: (json['turnResult'] as String?) ?? '',
        finalCoordinateNumber: _int(json['finalCoordinateNumber']),
        pitchTiming: (json['pitchTiming'] as String?) ?? '',
        pitchCardName: (json['pitchCardName'] as String?) ?? '',
        diceResults: _intList(json['diceResults']),
      );
}

/// GET /api/v1/game/{matchSessionId}/state 응답.
class GameSessionState {
  final String matchSessionId;
  final GameMode gameMode;
  final GameSessionPhase phase;
  final GameSessionRole myRole;
  final int myUserId;
  final int pitcherUserId;
  final int batterUserId;
  final int opponentUserId;
  final List<int> participantUserIds;
  final bool setupComplete;
  final bool myMulliganDone;
  final bool allMulliganDone;
  final List<CardInfo> myCardHand;
  final GameBoardState board;
  final GameTurnState turn;
  final LastTurnResultState? lastTurnResult;

  const GameSessionState({
    required this.matchSessionId,
    required this.gameMode,
    required this.phase,
    required this.myRole,
    required this.myUserId,
    required this.pitcherUserId,
    required this.batterUserId,
    required this.opponentUserId,
    required this.participantUserIds,
    required this.setupComplete,
    required this.myMulliganDone,
    required this.allMulliganDone,
    required this.myCardHand,
    required this.board,
    required this.turn,
    this.lastTurnResult,
  });

  factory GameSessionState.fromJson(Map<String, dynamic> json) {
    final phase = GameSessionPhase.fromApi(json['phase'] as String?);
    final role = GameSessionRole.fromApi(json['myRole'] as String?);
    if (phase == null || role == null) {
      throw const FormatException('Invalid game session state payload');
    }

    final handJson = json['myCardHand'];
    final handCards = handJson is List
        ? handJson
            .map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
            .toList()
        : <CardInfo>[];

    final participantsJson = json['participantUserIds'];
    final participants = participantsJson is List
        ? participantsJson.map((e) => (e as num).toInt()).toList()
        : <int>[];

    final boardJson = json['board'] as Map<String, dynamic>? ?? {};
    final turnJson = json['turn'] as Map<String, dynamic>? ?? {};
    final lastJson = json['lastTurnResult'] as Map<String, dynamic>?;

    return GameSessionState(
      matchSessionId: (json['matchSessionId'] as String?) ?? '',
      gameMode: _gameModeFromApi(json['gameMode'] as String?),
      phase: phase,
      myRole: role,
      myUserId: _int(json['myUserId']),
      pitcherUserId: _int(json['pitcherUserId']),
      batterUserId: _int(json['batterUserId']),
      opponentUserId: _int(json['opponentUserId']),
      participantUserIds: participants,
      setupComplete: _bool(json['setupComplete']),
      myMulliganDone: _bool(json['myMulliganDone']),
      allMulliganDone: _bool(json['allMulliganDone']),
      myCardHand: handCards,
      board: GameBoardState.fromJson(boardJson),
      turn: GameTurnState.fromJson(turnJson),
      lastTurnResult:
          lastJson != null ? LastTurnResultState.fromJson(lastJson) : null,
    );
  }

  TurnResultEvent? toLastTurnResultEvent() {
    final last = lastTurnResult;
    if (last == null) return null;
    return TurnResultEvent(
      turnResult: last.turnResult,
      finalCoordinateNumber: last.finalCoordinateNumber,
      pitchTiming: last.pitchTiming,
      pitchCardName: last.pitchCardName,
      diceResults: last.diceResults,
      inning: board.inning,
      isTop: board.isTop,
      homeScore: board.homeScore,
      awayScore: board.awayScore,
      balls: board.balls,
      strikes: board.strikes,
      outs: board.outs,
      firstBase: board.firstBase,
      secondBase: board.secondBase,
      thirdBase: board.thirdBase,
      pitcherUserId: turn.pitcherUserId != 0 ? turn.pitcherUserId : pitcherUserId,
      halfInningChanged: false,
      gameOver: board.gameOver,
    );
  }

  bool get isHomeTeam {
    if (participantUserIds.length >= 2) {
      return myUserId == participantUserIds.first;
    }
    return !board.isTop;
  }

  int get myScore => isHomeTeam ? board.homeScore : board.awayScore;
  int get opponentScore => isHomeTeam ? board.awayScore : board.homeScore;
}

GameMode _gameModeFromApi(String? value) => switch (value) {
      'GENERAL' => GameMode.single,
      'CLAN_GENERAL' => GameMode.teamRegular,
      'CLAN_MINI' => GameMode.teamMini,
      'CUSTOM' => GameMode.custom,
      _ => GameMode.single,
    };

int _int(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  return fallback;
}

List<int> _intList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => (e as num).toInt()).toList();
}
