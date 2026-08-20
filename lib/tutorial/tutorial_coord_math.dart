/// 좌표 1~25 격자에서 방향·변화량만큼 이동한 최종 좌표.
int tutorialApplyMove({
  required int start,
  required String direction,
  required int changeAmount,
}) {
  var current = start.clamp(1, 25);
  for (var i = 0; i < changeAmount; i++) {
    final next = _step(current, direction);
    if (next == null) break;
    current = next;
  }
  return current;
}

int? _step(int n, String direction) {
  final row = (n - 1) ~/ 5;
  final col = (n - 1) % 5;
  final d = direction.toUpperCase();

  var r = row;
  var c = col;
  if (d == 'UP') {
    r -= 1;
  } else if (d == 'DOWN') {
    r += 1;
  } else if (d == 'LEFT' || d == 'REVERSE') {
    c -= 1;
  } else if (d == 'RIGHT' || d == 'SIDE') {
    c += 1;
  } else if (d == 'UP_LEFT') {
    r -= 1;
    c -= 1;
  } else if (d == 'UP_RIGHT') {
    r -= 1;
    c += 1;
  } else if (d == 'DOWN_LEFT') {
    r += 1;
    c -= 1;
  } else if (d == 'DOWN_RIGHT') {
    r += 1;
    c += 1;
  } else if (d == 'STRAIGHT' || d == 'CENTER' || d == 'NONE') {
    return n;
  } else {
    return n;
  }

  if (r < 0 || r > 4 || c < 0 || c > 4) return null;
  return r * 5 + c + 1;
}
