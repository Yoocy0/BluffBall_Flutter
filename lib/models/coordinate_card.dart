/// GET /api/v1/cards/coordinate 응답 DTO
class CoordinateCard {
  final int id;
  final int coordinateNumber; // 1~25 (0은 타자 전용 폭투존)
  final String name;
  final bool isStrike;

  const CoordinateCard({
    required this.id,
    required this.coordinateNumber,
    required this.name,
    required this.isStrike,
  });

  factory CoordinateCard.fromJson(Map<String, dynamic> json) => CoordinateCard(
        id: (json['id'] as num?)?.toInt() ?? 0,
        coordinateNumber: (json['coordinateNumber'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        isStrike: (json['isStrike'] as bool?) ?? false,
      );
}
