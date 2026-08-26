import 'package:flutter/material.dart';

import 'card_info.dart';
import 'enhancement_card.dart';
import 'user_pitch_card.dart';

/// GET /api/v1/store/catalog — 구종 오퍼.
class StorePitchOffer {
  final int cardId;
  final String name;
  final int price;
  final bool hasBaseCopy;
  final bool purchasable;
  final String direction;
  final int changeAmount;
  final String timing;

  const StorePitchOffer({
    required this.cardId,
    required this.name,
    required this.price,
    required this.hasBaseCopy,
    required this.purchasable,
    required this.direction,
    required this.changeAmount,
    required this.timing,
  });

  String get displayName => CardInfo.shortPitchName(name);

  String get directionArrow => CardInfo.directionArrowFor(direction);

  String get timingLabel => CardInfo.timingLabelFor(timing);

  Color get timingColor => CardInfo.timingColorFor(timing);

  bool get hasStats => direction.isNotEmpty || timing.isNotEmpty;

  StorePitchOffer withMaster(CardInfo master) {
    final useMaster = !hasStats;
    return StorePitchOffer(
      cardId: cardId,
      name: name.isNotEmpty ? name : master.name,
      price: price,
      hasBaseCopy: hasBaseCopy,
      purchasable: purchasable,
      direction: useMaster ? master.direction : direction,
      changeAmount: useMaster ? master.changeAmount : changeAmount,
      timing: useMaster ? master.timing : timing,
    );
  }

  factory StorePitchOffer.fromJson(Map<String, dynamic> json) =>
      StorePitchOffer(
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toInt() ?? 100,
        hasBaseCopy: json['hasBaseCopy'] as bool? ?? false,
        purchasable: json['purchasable'] as bool? ?? false,
        direction: (json['direction'] as String?) ?? '',
        changeAmount: (json['changeAmount'] as num?)?.toInt() ??
            (json['baseChangeAmount'] as num?)?.toInt() ??
            0,
        timing: (json['timing'] as String?) ??
            (json['baseTiming'] as String?) ??
            '',
      );
}

/// GET /api/v1/store/catalog — 강화 오퍼.
class StoreEnhancementOffer {
  final int cardId;
  final String name;
  final EnhancementEffect effect;
  final int price;
  final int ownedQty;

  const StoreEnhancementOffer({
    required this.cardId,
    required this.name,
    required this.effect,
    required this.price,
    required this.ownedQty,
  });

  factory StoreEnhancementOffer.fromJson(Map<String, dynamic> json) =>
      StoreEnhancementOffer(
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        effect: EnhancementEffect.fromApi(json['effect'] as String?),
        price: (json['price'] as num?)?.toInt() ?? 80,
        ownedQty: (json['ownedQty'] as num?)?.toInt() ?? 0,
      );
}

/// GET /api/v1/store/catalog
class StoreCatalog {
  final int currency;
  final List<StorePitchOffer> pitchOffers;
  final List<StoreEnhancementOffer> enhancementOffers;

  const StoreCatalog({
    required this.currency,
    required this.pitchOffers,
    required this.enhancementOffers,
  });

  factory StoreCatalog.fromJson(Map<String, dynamic> json) {
    final pitches = json['pitchOffers'];
    final enhancements = json['enhancementOffers'];
    return StoreCatalog(
      currency: (json['currency'] as num?)?.toInt() ??
          (json['gold'] as num?)?.toInt() ??
          0,
      pitchOffers: pitches is List
          ? pitches
              .whereType<Map<String, dynamic>>()
              .map(StorePitchOffer.fromJson)
              .toList()
          : const [],
      enhancementOffers: enhancements is List
          ? enhancements
              .whereType<Map<String, dynamic>>()
              .map(StoreEnhancementOffer.fromJson)
              .toList()
          : const [],
    );
  }

  StoreCatalog copyWithCurrency(int currency) => StoreCatalog(
        currency: currency,
        pitchOffers: pitchOffers,
        enhancementOffers: enhancementOffers,
      );

  /// GET /cards/pitch 마스터를 cardId로 병합.
  StoreCatalog enrichedWithPitchMasters(Map<int, CardInfo> masters) {
    if (masters.isEmpty) return this;
    return StoreCatalog(
      currency: currency,
      pitchOffers: pitchOffers
          .map((o) => masters.containsKey(o.cardId)
              ? o.withMaster(masters[o.cardId]!)
              : o)
          .toList(),
      enhancementOffers: enhancementOffers,
    );
  }
}

/// POST /api/v1/store/pitch/purchase
class PitchPurchaseResult {
  final int remainingCurrency;
  final UserPitchCard purchasedCard;

  const PitchPurchaseResult({
    required this.remainingCurrency,
    required this.purchasedCard,
  });

  factory PitchPurchaseResult.fromJson(Map<String, dynamic> json) =>
      PitchPurchaseResult(
        remainingCurrency: (json['remainingCurrency'] as num?)?.toInt() ?? 0,
        purchasedCard: UserPitchCard.fromJson(
          json['purchasedCard'] as Map<String, dynamic>,
        ),
      );
}

/// POST /api/v1/store/enhancement/purchase
class EnhancementPurchaseResult {
  final int remainingCurrency;
  final EnhancementCard purchasedCard;

  const EnhancementPurchaseResult({
    required this.remainingCurrency,
    required this.purchasedCard,
  });

  factory EnhancementPurchaseResult.fromJson(Map<String, dynamic> json) {
    final card = json['purchasedCard'];
    return EnhancementPurchaseResult(
      remainingCurrency: (json['remainingCurrency'] as num?)?.toInt() ?? 0,
      purchasedCard: card is Map<String, dynamic>
          ? EnhancementCard.fromJson(card)
          : const EnhancementCard(
              cardId: 0,
              name: '',
              effect: EnhancementEffect.unknown,
            ),
    );
  }
}
