sealed class PresenceEvent {
  const PresenceEvent();
}

class OpponentDisconnectedEvent extends PresenceEvent {
  final int opponentUserId;
  final int remainingSeconds;

  const OpponentDisconnectedEvent({
    required this.opponentUserId,
    required this.remainingSeconds,
  });

  factory OpponentDisconnectedEvent.fromJson(Map<String, dynamic> json) {
    final remaining = _int(json['remainingSeconds']) ??
        _int(json['reconnectRemainingSeconds']) ??
        _int(json['gracePeriodSeconds']) ??
        120;
    return OpponentDisconnectedEvent(
      opponentUserId: _int(json['opponentUserId']) ?? _int(json['userId']) ?? 0,
      remainingSeconds: remaining,
    );
  }
}

class OpponentReconnectedEvent extends PresenceEvent {
  final int opponentUserId;

  const OpponentReconnectedEvent({required this.opponentUserId});

  factory OpponentReconnectedEvent.fromJson(Map<String, dynamic> json) =>
      OpponentReconnectedEvent(
        opponentUserId: _int(json['opponentUserId']) ?? _int(json['userId']) ?? 0,
      );
}

PresenceEvent? parsePresenceEvent(Map<String, dynamic> json) {
  final type = (json['eventType'] ?? json['type'] ?? json['event'] ?? '')
      .toString()
      .toUpperCase();

  if (type.contains('OPPONENT_DISCONNECTED') ||
      (type.contains('DISCONNECTED') &&
          (json.containsKey('remainingSeconds') ||
              json.containsKey('reconnectRemainingSeconds')))) {
    return OpponentDisconnectedEvent.fromJson(json);
  }
  if (type.contains('OPPONENT_RECONNECTED') || type.contains('RECONNECTED')) {
    return OpponentReconnectedEvent.fromJson(json);
  }
  if (json.containsKey('remainingSeconds') || json.containsKey('reconnectRemainingSeconds')) {
    return OpponentDisconnectedEvent.fromJson(json);
  }
  return null;
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
