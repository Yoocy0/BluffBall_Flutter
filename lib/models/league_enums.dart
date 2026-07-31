/// 리그 포맷 (백엔드 LeagueFormat)
enum LeagueFormat {
  full,
  compact;

  String get apiValue => switch (this) {
        LeagueFormat.full => 'FULL',
        LeagueFormat.compact => 'COMPACT',
      };

  static LeagueFormat? fromApi(String? value) => switch (value) {
        'FULL' => LeagueFormat.full,
        'COMPACT' => LeagueFormat.compact,
        _ => null,
      };
}

/// 리그 티어 (백엔드 LeagueTier)
enum LeagueTier {
  amateur1,
  amateur2,
  amateur3,
  amateur4,
  independent,
  pro1,
  pro2;

  String get apiValue => switch (this) {
        LeagueTier.amateur1 => 'AMATEUR_1',
        LeagueTier.amateur2 => 'AMATEUR_2',
        LeagueTier.amateur3 => 'AMATEUR_3',
        LeagueTier.amateur4 => 'AMATEUR_4',
        LeagueTier.independent => 'INDEPENDENT',
        LeagueTier.pro1 => 'PRO_1',
        LeagueTier.pro2 => 'PRO_2',
      };

  String get displayName => switch (this) {
        LeagueTier.amateur1 => '아마 1부',
        LeagueTier.amateur2 => '아마 2부',
        LeagueTier.amateur3 => '아마 3부',
        LeagueTier.amateur4 => '아마 4부',
        LeagueTier.independent => '독립',
        LeagueTier.pro1 => '프로 1부',
        LeagueTier.pro2 => '프로 2부',
      };

  static LeagueTier? fromApi(String? value) => switch (value) {
        'AMATEUR_1' => LeagueTier.amateur1,
        'AMATEUR_2' => LeagueTier.amateur2,
        'AMATEUR_3' => LeagueTier.amateur3,
        'AMATEUR_4' => LeagueTier.amateur4,
        'INDEPENDENT' => LeagueTier.independent,
        'PRO_1' => LeagueTier.pro1,
        'PRO_2' => LeagueTier.pro2,
        _ => null,
      };
}
