enum MatchJoinStatus { waiting, matched }

class MatchJoinResponse {
  final MatchJoinStatus status;
  final String? matchSessionId;

  const MatchJoinResponse({
    required this.status,
    this.matchSessionId,
  });

  bool get isWaiting => status == MatchJoinStatus.waiting;
  bool get isMatched => status == MatchJoinStatus.matched;

  factory MatchJoinResponse.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String?) ?? '';
    final status = statusStr == 'MATCHED'
        ? MatchJoinStatus.matched
        : MatchJoinStatus.waiting;
    return MatchJoinResponse(
      status: status,
      matchSessionId: json['matchSessionId'] as String?,
    );
  }
}
