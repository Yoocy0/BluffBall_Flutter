import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../tutorial/tutorial_flow_screen.dart';
import 'tutorial_service.dart';

/// 앱 재실행·세션 복원 후 → 항상 홈.
/// 튜토리얼은 로그인 시에만 검사한다.
Future<void> navigateAfterSessionRestore(BuildContext context) async {
  if (!context.mounted) return;
  _replaceWith(context, const HomeScreen());
}

/// 소셜 로그인 성공 직후:
/// GET /tutorial/status → completed == false 인 계정만 튜토리얼, 아니면 홈.
/// 상태 조회 실패 시에는 강제 튜토리얼 없이 홈으로 보낸다.
Future<void> navigateAfterLogin(BuildContext context) async {
  bool showTutorial = false;
  try {
    final status = await TutorialService().fetchStatus();
    showTutorial = !status.completed;
  } catch (_) {
    showTutorial = false;
  }

  if (!context.mounted) return;

  _replaceWith(
    context,
    showTutorial
        ? const TutorialFlowScreen(isReplay: false)
        : const HomeScreen(),
  );
}

void _replaceWith(BuildContext context, Widget next) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (_, animation, secondaryAnimation) => next,
      transitionsBuilder: (_, anim, secondaryAnimation, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 450),
    ),
  );
}
