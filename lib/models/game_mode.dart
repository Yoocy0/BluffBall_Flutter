enum GameMode {
  single,
  teamRegular,
  teamMini,
  custom;

  String get displayName => switch (this) {
    GameMode.single => '싱글',
    GameMode.teamRegular => '팀 정규',
    GameMode.teamMini => '팀 미니매치',
    GameMode.custom => '커스텀',
  };
}
