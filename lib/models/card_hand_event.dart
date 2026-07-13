import 'card_info.dart';

/// 백엔드 CardHandEvent 대응 모델.
///
/// [targetUserId]    : 이 카드 패의 소유자 userId
/// [pitcherUserId]   : 투수 userId
/// [allMulliganReady]: 양측 모두 멀리건 완료 여부
/// [fromMulligan]    : 멀리건 처리 후 발행된 이벤트면 true, 초기 딜이면 false
class CardHandEvent {
  final List<CardInfo> cardInfos;
  final int pitcherUserId;
  final int targetUserId;
  final bool allMulliganReady;
  final bool fromMulligan;

  const CardHandEvent({
    required this.cardInfos,
    required this.pitcherUserId,
    required this.targetUserId,
    required this.allMulliganReady,
    required this.fromMulligan,
  });

  factory CardHandEvent.fromJson(Map<String, dynamic> json) => CardHandEvent(
        cardInfos: (json['cards'] as List<dynamic>)
            .map((e) => CardInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        pitcherUserId: (json['pitcherUserId'] as num).toInt(),
        targetUserId: (json['targetUserId'] as num).toInt(),
        allMulliganReady: json['allMulliganReady'] as bool,
        fromMulligan: json['fromMulligan'] as bool,
      );
}
