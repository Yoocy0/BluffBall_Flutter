import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../services/game_forfeit_service.dart';
import '../services/game_presence_controller.dart';
import 'exit_confirm_dialogs.dart';

/// OpponentDisconnectedEvent 수신 시 120초 카운트다운 배너.
class OpponentDisconnectedOverlay extends StatelessWidget {
  const OpponentDisconnectedOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GamePresenceController.instance,
      builder: (context, _) {
        final ctrl = GamePresenceController.instance;
        if (!ctrl.isOpponentDisconnectedVisible) return const SizedBox.shrink();

        final minutes = ctrl.remainingSeconds ~/ 60;
        final seconds = ctrl.remainingSeconds % 60;
        final timeLabel = minutes > 0
            ? '$minutes:${seconds.toString().padLeft(2, '0')}'
            : '${ctrl.remainingSeconds}초';

        return Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1A05).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF7043)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Color(0xFFFFAB91), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '상대방 연결이 끊어졌습니다',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '재접속 대기 $timeLabel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 인게임 화면 body 위에 presence 카운트다운 + 뒤로가기 몰수 확인을 적용합니다.
class InGamePresenceShell extends StatelessWidget {
  final String matchSessionId;
  final GameMode gameMode;
  final Widget child;

  const InGamePresenceShell({
    super.key,
    required this.matchSessionId,
    required this.gameMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || matchSessionId.isEmpty) return;
        final leave = await showInGameForfeitConfirmDialog(context);
        if (leave != true) return;
        await GameForfeitService.instance.leaveMatchWithForfeit(
          gameMode: gameMode,
          matchSessionId: matchSessionId,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          const OpponentDisconnectedOverlay(),
        ],
      ),
    );
  }
}
