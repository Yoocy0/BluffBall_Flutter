import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_mode.dart';
import '../services/game_websocket_service.dart';
import '../widgets/mode_background.dart';

class GameOverScreen extends StatefulWidget {
  final GameMode gameMode;
  final int myScore;
  final int opponentScore;
  final bool didWin;

  const GameOverScreen({
    super.key,
    required this.gameMode,
    required this.myScore,
    required this.opponentScore,
    required this.didWin,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.didWin;
    final resultColor = win ? const Color(0xFFFFD700) : const Color(0xFFFF1744);
    final resultText = win ? 'Win' : 'Lose';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(children: [
          ModeBackground(mode: widget.gameMode),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Column(children: [
              const Spacer(),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: _buildResultPanel(win, resultColor, resultText),
                ),
              ),
              const Spacer(),
              _buildHomeButton(context),
              const SizedBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildResultPanel(bool win, Color color, String resultText) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.50),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 플레이어 이름 (TODO: 실제 닉네임으로 교체)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _playerLabel('나', color),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.25),
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              _playerLabel('상대', Colors.black54),
            ],
          ),
          const SizedBox(height: 14),

          // 스코어
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.myScore}',
                style: TextStyle(
                  color: win ? color : Colors.black87,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.20),
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Text(
                '${widget.opponentScore}',
                style: TextStyle(
                  color: !win ? const Color(0xFFFF1744) : Colors.black87,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 구분선
          Divider(color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // Win / Lose
          Text(
            resultText,
            style: TextStyle(
              color: color,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerLabel(String name, Color color) {
    return Text(
      name,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: () {
                GameWebSocketService.instance.disconnect();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: const Center(
              child: Text(
                '홈으로',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
