import 'package:flutter/material.dart';

/// 앱 공통 팝업 스타일.
const kAppDialogBg = Color(0xFF2A3518);
const kAppDialogGold = Color(0xFFFFD700);
const kAppDialogGoldDark = Color(0xFFD4821A);
const kAppDialogInk = Color(0xFF2A1F05);

/// 노란 직사각형 확인/주요 액션 버튼.
class AppDialogPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AppDialogPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [kAppDialogGold, kAppDialogGoldDark],
          ),
          boxShadow: [
            BoxShadow(
              color: kAppDialogGold.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// 보조(취소) 직사각형 버튼.
class AppDialogSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AppDialogSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// 공통 팝업 셸 (제목·본문·버튼 영역).
class AppDialogShell extends StatelessWidget {
  final Widget? icon;
  final String? title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;
  final EdgeInsetsGeometry? actionsPadding;

  const AppDialogShell({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.body,
    required this.actions,
    this.actionsPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: kAppDialogBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: kAppDialogGold.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(height: 12),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            if (body != null) body!,
            SizedBox(height: actions.isEmpty ? 0 : 20),
            Padding(
              padding: actionsPadding ?? EdgeInsets.zero,
              child: actions.length == 1
                  ? actions.first
                  : Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: actions[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 팝업 (확인 1개).
Future<void> showAppAlertDialog(
  BuildContext context, {
  String? title,
  required String message,
  String confirmLabel = '확인',
  Widget? icon,
  bool barrierDismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppDialogShell(
      icon: icon,
      title: title,
      message: message,
      actions: [
        AppDialogPrimaryButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// 확인/취소 팝업. true = 확인, false/null = 취소.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  Widget? icon,
  bool barrierDismissible = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppDialogShell(
      icon: icon,
      title: title,
      message: message,
      actions: [
        AppDialogSecondaryButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        AppDialogPrimaryButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
}
