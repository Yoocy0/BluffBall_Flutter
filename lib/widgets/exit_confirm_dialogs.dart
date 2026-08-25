import 'package:flutter/material.dart';

import 'app_dialog.dart';

Future<bool?> showAppExitConfirmDialog(BuildContext context) {
  return showAppConfirmDialog(
    context,
    title: '게임을 종료하시겠습니까?',
    message: '확인 시 앱이 종료됩니다.',
    cancelLabel: '취소',
    confirmLabel: '종료',
  );
}

Future<bool?> showInGameForfeitConfirmDialog(BuildContext context) {
  return showAppConfirmDialog(
    context,
    icon: Icon(
      Icons.warning_amber_rounded,
      color: Colors.redAccent.withValues(alpha: 0.92),
      size: 34,
    ),
    title: '경기 나가기',
    message: '지금 나가면 몰수패(0:10)로 처리됩니다.\n'
        '고의로 경기를 포기하는 경우에만 나가 주세요.',
    cancelLabel: '계속하기',
    confirmLabel: '나가기',
  );
}

Future<bool?> showMatchmakingCancelConfirmDialog(BuildContext context) {
  return showAppConfirmDialog(
    context,
    title: '매칭을 취소하시겠습니까?',
    message: '확인 시 매칭 대기가 취소됩니다.',
    cancelLabel: '계속 대기',
    confirmLabel: '취소',
  );
}
