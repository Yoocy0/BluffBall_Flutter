/// 강화 카드 effect.
enum EnhancementEffect {
  changeAmountPlus1,
  timingFaster,
  timingSlower,
  unknown;

  static EnhancementEffect fromApi(String? raw) =>
      switch ((raw ?? '').toUpperCase()) {
        'CHANGE_AMOUNT_PLUS_1' => EnhancementEffect.changeAmountPlus1,
        'TIMING_FASTER' => EnhancementEffect.timingFaster,
        'TIMING_SLOWER' => EnhancementEffect.timingSlower,
        _ => EnhancementEffect.unknown,
      };

  String get label => switch (this) {
        EnhancementEffect.changeAmountPlus1 => '변화량 +1',
        EnhancementEffect.timingFaster => '타이밍 빠르게',
        EnhancementEffect.timingSlower => '타이밍 느리게',
        EnhancementEffect.unknown => '강화',
      };

  bool get isChangeAmount => this == EnhancementEffect.changeAmountPlus1;

  bool get isTiming =>
      this == EnhancementEffect.timingFaster ||
      this == EnhancementEffect.timingSlower;
}

/// GET /api/v1/cards/enhancement · GET /users/me/enhancement-cards
class EnhancementCard {
  final int cardId;
  final String name;
  final EnhancementEffect effect;
  final int quantity;

  const EnhancementCard({
    required this.cardId,
    required this.name,
    required this.effect,
    this.quantity = 0,
  });

  factory EnhancementCard.fromJson(Map<String, dynamic> json) =>
      EnhancementCard(
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        effect: EnhancementEffect.fromApi(json['effect'] as String?),
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      );
}

/// 되돌리기 종류.
enum EnhanceRevertKind {
  changeAmount,
  timing;

  String get pathSuffix => switch (this) {
        EnhanceRevertKind.changeAmount => 'change-amount',
        EnhanceRevertKind.timing => 'timing',
      };

  String get label => switch (this) {
        EnhanceRevertKind.changeAmount => '변화량 강화 되돌리기',
        EnhanceRevertKind.timing => '타이밍 강화 되돌리기',
      };
}
