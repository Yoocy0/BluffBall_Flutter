import 'dart:convert';

/// 백엔드 MulliganRequest record 대응 모델.
///
/// [cardIdsToSwap] 가 빈 리스트이면 현재 패를 그대로 확정.
class MulliganRequest {
  final List<int> cardIdsToSwap;

  const MulliganRequest({required this.cardIdsToSwap});

  const MulliganRequest.confirm() : cardIdsToSwap = const [];

  Map<String, dynamic> toJson() => {'cardIdsToSwap': cardIdsToSwap};

  String toJsonString() => jsonEncode(toJson());
}
