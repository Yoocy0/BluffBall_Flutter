/// GET /api/v1/tutorial/status · complete 응답용 구종 요약.
class TutorialPitchOption {
  final int cardId;
  final String name;

  const TutorialPitchOption({
    required this.cardId,
    required this.name,
  });

  factory TutorialPitchOption.fromJson(Map<String, dynamic> json) =>
      TutorialPitchOption(
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );
}

/// GET /api/v1/tutorial/status
class TutorialStatus {
  final bool completed;
  final TutorialPitchOption? fixedStarterPitch;
  final List<TutorialPitchOption> selectableStarterPitches;
  final int selectableCount;

  const TutorialStatus({
    required this.completed,
    required this.fixedStarterPitch,
    required this.selectableStarterPitches,
    required this.selectableCount,
  });

  factory TutorialStatus.fromJson(Map<String, dynamic> json) {
    final fixed = json['fixedStarterPitch'];
    final selectable = json['selectableStarterPitches'];
    return TutorialStatus(
      completed: json['completed'] as bool? ?? false,
      fixedStarterPitch: fixed is Map<String, dynamic>
          ? TutorialPitchOption.fromJson(fixed)
          : null,
      selectableStarterPitches: selectable is List
          ? selectable
              .whereType<Map<String, dynamic>>()
              .map(TutorialPitchOption.fromJson)
              .toList()
          : const [],
      selectableCount: (json['selectableCount'] as num?)?.toInt() ?? 2,
    );
  }
}

/// POST /api/v1/tutorial/complete 지급 결과 한 장.
class GrantedPitchCard {
  final int userPitchCardId;
  final int cardId;
  final String name;
  final String? direction;
  final int? baseChangeAmount;
  final int? effectiveChangeAmount;
  final String? baseTiming;
  final String? effectiveTiming;

  const GrantedPitchCard({
    required this.userPitchCardId,
    required this.cardId,
    required this.name,
    this.direction,
    this.baseChangeAmount,
    this.effectiveChangeAmount,
    this.baseTiming,
    this.effectiveTiming,
  });

  factory GrantedPitchCard.fromJson(Map<String, dynamic> json) =>
      GrantedPitchCard(
        userPitchCardId: (json['userPitchCardId'] as num?)?.toInt() ?? 0,
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        direction: json['direction'] as String?,
        baseChangeAmount: (json['baseChangeAmount'] as num?)?.toInt(),
        effectiveChangeAmount: (json['effectiveChangeAmount'] as num?)?.toInt(),
        baseTiming: json['baseTiming'] as String?,
        effectiveTiming: json['effectiveTiming'] as String?,
      );
}

/// POST /api/v1/tutorial/complete
class TutorialCompleteResult {
  final List<GrantedPitchCard> grantedPitchCards;

  const TutorialCompleteResult({required this.grantedPitchCards});

  factory TutorialCompleteResult.fromJson(Map<String, dynamic> json) {
    final list = json['grantedPitchCards'];
    return TutorialCompleteResult(
      grantedPitchCards: list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(GrantedPitchCard.fromJson)
              .toList()
          : const [],
    );
  }
}
