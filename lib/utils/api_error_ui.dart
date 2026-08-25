import 'package:flutter/material.dart';

import '../models/api_error.dart';
import '../widgets/app_dialog.dart';

/// 앱 공통 에러 팝업.
Future<void> showErrorDialog(BuildContext context, String message) async {
  if (!context.mounted) return;
  await showAppAlertDialog(
    context,
    message: message,
    confirmLabel: '확인',
  );
}

Future<void> showApiErrorDialog(BuildContext context, ApiError error) =>
    showErrorDialog(context, error.message);

/// 하위 호환 — 스낵바 대신 팝업.
@Deprecated('Use showErrorDialog')
void showErrorSnackBar(BuildContext context, String message) {
  showErrorDialog(context, message);
}

@Deprecated('Use showApiErrorDialog')
void showApiErrorSnackBar(BuildContext context, ApiError error) {
  showApiErrorDialog(context, error);
}
