import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// ─── 색상 팔레트 ────────────────────────────────────────────────────────────
const _kDarkBase = Color(0xFF161D0B);
const _kOliveMid = Color(0xFF3D5020);
const _kOliveLight = Color(0xFF556B2F);
const _kBrownBase = Color(0xFF5C3010);
const _kGold = Color(0xFFFFD700);
const _kGoldDark = Color(0xFFB8860B);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 1; // 기본: 경기(가운데)

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            const _HomeBackground(),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildCharacterPanel()),
                  _buildArenaLabel(),
                  _buildBattleButtons(),
                  const SizedBox(height: 8),
                  _buildBottomNav(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 (닉네임 + 재화 + 설정) ────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // 아바타 + 닉네임
          _PlayerBadge(),
          const Spacer(),
          // 골드
          const _CurrencyBadge(
            icon: Icons.monetization_on_rounded,
            iconColor: _kGold,
            value: '8,350',
          ),
          const SizedBox(width: 6),
          // 젬
          const _CurrencyBadge(
            icon: Icons.diamond_rounded,
            iconColor: Color(0xFF72C6EF),
            value: '372',
          ),
          const SizedBox(width: 8),
          // 설정 (임시 로그아웃)
          _TopIconButton(
            icon: Icons.settings_rounded,
            onTap: () => _showSettingsMenu(context),
          ),
        ],
      ),
    );
  }

  // ── 캐릭터 영역 (패널 없이 캐릭터만) ────────────────────────────────────
  Widget _buildCharacterPanel() {
    return const _AnimatedCharacter();
  }

  // ── 아레나 라벨 ──────────────────────────────────────────────────────────
  Widget _buildArenaLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 1,
            color: _kGoldDark.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Text(
            'BLUFFBALL ARENA',
            style: TextStyle(
              color: _kGold.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 1,
            color: _kGoldDark.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  // ── 전투 버튼 2개 ─────────────────────────────────────────────────────────
  Widget _buildBattleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _BattleButton(
              label: '싱글 모드',
              icon: Icons.person_rounded,
              onTap: () {},
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
              ),
              shadowColor: const Color(0xFF8B5010),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BattleButton(
              label: '커스텀 모드',
              icon: Icons.people_rounded,
              onTap: () {},
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7EC850), Color(0xFF4A8A20)],
              ),
              shadowColor: const Color(0xFF2A5010),
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 네비게이션 ───────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      _NavItem(icon: Icons.checkroom_rounded, label: '옷장'),
      _NavItem(icon: Icons.sports_soccer_rounded, label: '경기'),
      _NavItem(icon: Icons.groups_rounded, label: '클랜'),
    ];

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _kDarkBase.withValues(alpha: 0.97),
        border: const Border(
          top: BorderSide(color: Color(0xFF4A5A25), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _navIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _navIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: selected
                      ? _kOliveMid.withValues(alpha: 0.45)
                      : Colors.transparent,
                  border: selected
                      ? const Border(
                          top: BorderSide(color: _kGold, width: 2.5),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        items[i].icon,
                        size: 26,
                        color: selected ? _kGold : Colors.white30,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? _kGold : Colors.white30,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 설정 메뉴 ─────────────────────────────────────────────────────────────
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
              title: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _signOut(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}

// ─── 데이터 클래스 ────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── 위젯 컴포넌트 ────────────────────────────────────────────────────────

class _PlayerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _kPanelBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kPanelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kOliveMid, _kBrownBase],
              ),
              border: Border.all(color: _kGold, width: 1.5),
            ),
            child: const Icon(Icons.person_rounded, size: 20, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          const Text(
            '플레이어',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;

  const _CurrencyBadge({
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _kPanelBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPanelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _kPanelBg.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kPanelBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white60),
      ),
    );
  }
}

class _BattleButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Color shadowColor;

  const _BattleButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradient,
    required this.shadowColor,
  });

  @override
  State<_BattleButton> createState() => _BattleButtonState();
}

class _BattleButtonState extends State<_BattleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 58,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.shadowColor.withValues(alpha: 0.9),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 6),
                    blurRadius: 10,
                  ),
                ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 배경 ─────────────────────────────────────────────────────────────────

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _BackgroundPainter()),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 기본 그라디언트: 올리브 그린 → 안장 갈색
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E2810),
          Color(0xFF2D3A15),
          Color(0xFF3A2208),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 다이아몬드 타일 패턴
    final tilePaint = Paint()
      ..color = const Color(0xFF3D5020).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const tileW = 30.0;
    const tileH = 30.0;
    for (double row = -1; row * tileH < size.height + tileH; row++) {
      for (double col = -1; col * tileW < size.width + tileW; col++) {
        final cx = col * tileW;
        final cy = row * tileH;
        final hw = tileW / 2;
        final hh = tileH / 2;
        final path = Path()
          ..moveTo(cx + hw, cy)
          ..lineTo(cx + tileW, cy + hh)
          ..lineTo(cx + hw, cy + tileH)
          ..lineTo(cx, cy + hh)
          ..close();
        canvas.drawPath(path, tilePaint);
      }
    }

    // 하단 갈색 그라디언트 오버레이
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF3A1A05).withValues(alpha: 0.55),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      bottomPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 캐릭터 플로팅 애니메이션 ────────────────────────────────────────────────

class _AnimatedCharacter extends StatefulWidget {
  const _AnimatedCharacter();

  @override
  State<_AnimatedCharacter> createState() => _AnimatedCharacterState();
}

class _AnimatedCharacterState extends State<_AnimatedCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatY;
  late final Animation<double> _shadowScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatY = Tween<double>(begin: -7, end: 7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 캐릭터 — 세로 꽉 채움
                Positioned(
                  top: 0,
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(0, _floatY.value),
                    child: child,
                  ),
                ),
                // 발밑 그림자
                Positioned(
                  bottom: 4,
                  child: Transform.scale(
                    scaleX: _shadowScale.value,
                    child: Container(
                      width: constraints.maxWidth * 0.3,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: Colors.black.withValues(alpha: 0.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Image.asset(
            'assets/images/character.png',
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
          ),
        );
      },
    );
  }
}

