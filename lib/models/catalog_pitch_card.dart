/// GET /api/v1/cards/pitch 항목
class CatalogPitchCard {
  final int cardId;
  final String name;
  final int changeAmount;
  final String direction;
  final String timing;

  const CatalogPitchCard({
    required this.cardId,
    required this.name,
    required this.changeAmount,
    required this.direction,
    required this.timing,
  });

  factory CatalogPitchCard.fromJson(Map<String, dynamic> json) =>
      CatalogPitchCard(
        cardId: (json['cardId'] as num).toInt(),
        name: json['name'] as String? ?? '',
        changeAmount: (json['changeAmount'] as num?)?.toInt() ?? 0,
        direction: json['direction']?.toString() ?? '',
        timing: json['timing']?.toString() ?? '',
      );

  String get changeLabel => changeAmount == 0
      ? '±0'
      : (changeAmount > 0 ? '+$changeAmount' : '$changeAmount');
}
