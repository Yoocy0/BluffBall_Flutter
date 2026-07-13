import 'dart:convert';

/// 백엔드 SetupNumberRequest DTO에 대응하는 Dart 모델.
///
/// 경로: /app/game/{matchSessionId}/setup-numbers (STOMP)
class SetupNumberRequest {
  /// 투수의 아웃 유발 번호 목록 (1~12)
  final List<int> outNumList;

  /// 투수의 병살 유발 번호 목록 (1~12)
  final List<int> dpNumList;

  /// 타자의 3루타 유발 번호 목록 (1~12)
  final List<int> tripleNumList;

  /// 타자의 홈런 유발 번호 목록 (1~12)
  final List<int> hrNumList;

  const SetupNumberRequest({
    required this.outNumList,
    required this.dpNumList,
    required this.tripleNumList,
    required this.hrNumList,
  });

  Map<String, dynamic> toJson() => {
        'outNumList': outNumList,
        'dpNumList': dpNumList,
        'tripleNumList': tripleNumList,
        'hrNumList': hrNumList,
      };

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => 'SetupNumberRequest('
      'out=$outNumList, dp=$dpNumList, triple=$tripleNumList, hr=$hrNumList)';
}
