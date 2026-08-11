enum GameMode {
  single,
  teamRegular,
  teamMini,
  custom;

  String get displayName => switch (this) {
    GameMode.single => '쇼다운',
    GameMode.teamRegular => '리그전(풀)',
    GameMode.teamMini => '리그전(컴팩트)',
    GameMode.custom => '커스텀',
  };
}
