import 'package:flutter/material.dart';

const _kDialogBg = Color(0xFF2A3518);
const _kDialogGold = Color(0xFFFFD700);

Future<bool?> showAppExitConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _kDialogGold.withValues(alpha: 0.45)),
      ),
      title: const Text(
        '게임을 종료하시겠습니까?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: const Text(
        '확인 시 앱이 종료됩니다.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            '취소',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: _kDialogGold,
            foregroundColor: const Color(0xFF2A1F05),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            '종료',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Future<bool?> showInGameForfeitConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.55)),
      ),
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Colors.redAccent.withValues(alpha: 0.92),
        size: 34,
      ),
      title: const Text(
        '경기 나가기',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: const Text(
        '지금 나가면 몰수패(0:10)로 처리됩니다.\n'
        '고의로 경기를 포기하는 경우에만 나가 주세요.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            '계속하기',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            '나가기',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Future<bool?> showMatchmakingCancelConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _kDialogGold.withValues(alpha: 0.45)),
      ),
      title: const Text(
        '매칭을 취소하시겠습니까?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: const Text(
        '확인 시 매칭 대기가 취소됩니다.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            '계속 대기',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: _kDialogGold,
            foregroundColor: const Color(0xFF2A1F05),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            '취소',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
