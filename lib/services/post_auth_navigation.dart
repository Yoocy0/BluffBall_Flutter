import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../tutorial/tutorial_flow_screen.dart';
import 'tutorial_service.dart';

/// 로그인·세션 복원 후 튜토리얼 강제 진입 여부를 결정한다.
///
/// 이후 백엔드 `tutorialCompleted` boolean을 [TutorialService.syncFromServer]로
/// 맞춘 뒤 이 함수를 그대로 쓰면 된다.
Future<void> navigateAfterAuth(BuildContext context) async {
  final completed = await TutorialService().isCompleted();
  if (!context.mounted) return;

  final Widget next = completed
      ? const HomeScreen()
      : const TutorialFlowScreen(isReplay: false);

  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => next,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 450),
    ),
  );
}
