import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/match_service.dart';
import '../services/match_session_storage.dart';
import '../services/game_session_restore_service.dart';
import '../models/game_session_state_exception.dart';
import '../utils/api_error_ui.dart';
import '../widgets/app_dialog.dart';
import '../widgets/board_game_box.dart';
import '../widgets/exit_confirm_dialogs.dart';
import '../tutorial/tutorial_flow_screen.dart';
import 'cards_screen.dart';
import 'login_screen.dart';
import 'match_found_screen.dart';
import 'matchmaking_screen.dart';
import '../models/game_mode.dart';

// ─── 색상 팔레트 ────────────────────────────────────────────────────────────
const _kDarkBase = Color(0xFF161D0B);
const _kOliveMid = Color(0xFF3D5020);
const _kBrownBase = Color(0xFF5C3010);
const _kGold = Color(0xFFFFD700);
const _kGoldDark = Color(0xFFB8860B);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);

// ─── 데이터 모델 ─────────────────────────────────────────────────────────────

enum _ShowdownOpponent { vsUser, vsBot }

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── 홈 화면 ─────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _navIndex = 1;     // 기본: 경기 (가운데)
  int _prevNavIndex = 1;
  bool _singleModeLoading = false;
  bool _restoreInProgress = false;
  bool _reconnectDialogVisible = false;
  SavedMatchSession? _pendingMatchSession;

  final _matchService = MatchService();
  final _restoreService = GameSessionRestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingMatch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingMatch();
    }
  }

  Future<void> _checkPendingMatch() async {
    final saved = await MatchSessionCoordinator.tryRestore();
    if (!mounted || saved == null) return;
    _pendingMatchSession = saved;
    if (_reconnectDialogVisible || _restoreInProgress) return;
    await _showReconnectDialog(saved);
  }

  Future<void> _showReconnectDialog(SavedMatchSession saved) async {
    _reconnectDialogVisible = true;
    try {
      final reconnect = await showAppConfirmDialog(
        context,
        icon: Icon(
          Icons.sports_baseball_rounded,
          color: _kGold.withValues(alpha: 0.9),
          size: 32,
        ),
        title: '진행 중인 매치가 있습니다',
        message: '중단된 경기를 이어서 진행할 수 있습니다.',
        cancelLabel: '나중에',
        confirmLabel: '재접속',
      );

      if (!mounted || reconnect != true) return;
      await _reconnectToMatch(saved);
    } finally {
      _reconnectDialogVisible = false;
    }
  }

  Future<void> _reconnectToMatch([SavedMatchSession? session]) async {
    final saved = session ?? _pendingMatchSession;
    if (saved == null || _restoreInProgress) return;

    setState(() => _restoreInProgress = true);
    try {
      final page = await _restoreService.buildRestorePage(saved.matchSessionId);
      if (!mounted) return;
      if (page == null) {
        await MatchSessionCoordinator.onSessionEnd();
        setState(() => _pendingMatchSession = null);
        return;
      }

      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    } on GameSessionStateException catch (e) {
      if (e.shouldClearLocalSession) {
        await MatchSessionCoordinator.onSessionEnd();
        if (mounted) setState(() => _pendingMatchSession = null);
      }
      if (mounted) {
        showErrorDialog(context, e.message);
      }
    } on StateError catch (e) {
      if (mounted) {
        showErrorDialog(context, e.message);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Restore] 실패: $e');
      if (mounted) {
        showErrorDialog(context, '게임 복원에 실패했습니다. ($e)');
      }
    } finally {
      if (mounted) setState(() => _restoreInProgress = false);
    }
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() {
      _prevNavIndex = _navIndex;
      _navIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await showAppExitConfirmDialog(context);
        if (exit == true) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(
            children: [
              const _HomeBackground(),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildMainContent()),
                    _buildBottomButtons(),
                    if (_navIndex == 1) const SizedBox(height: 8),
                    _buildBottomNav(),
                  ],
                ),
              ),
              if (_restoreInProgress)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 슬라이드 전환 메인 콘텐츠 ────────────────────────────────────────────
  Widget _buildMainContent() {
    final slideDir = _navIndex >= _prevNavIndex ? 1.0 : -1.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        final key = child.key as ValueKey<int>;
        final isEntering = key.value == _navIndex;
        final beginOffset = isEntering
            ? Offset(slideDir, 0)
            : Offset(-slideDir, 0);
        return ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut))
                .animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_navIndex),
        child: _buildContentForIndex(),
      ),
    );
  }

  Widget _buildContentForIndex() {
    switch (_navIndex) {
      case 0:
        return const _ShopScreen();
      case 2:
        return const CardsScreen();
      default:
        return const BoardGameBox(heroTagOverride: BoardGameBox.heroTag);
    }
  }

  // ── 하단 버튼 (탭별) ─────────────────────────────────────────────────────
  Widget _buildBottomButtons() {
    if (_navIndex == 1) return _buildMatchButtons();
    return const SizedBox.shrink();
  }

  Widget _buildMatchButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 40, height: 1,
                    color: _kGoldDark.withValues(alpha: 0.4)),
                const SizedBox(width: 10),
                Text('BLUFFBALL ARENA', style: TextStyle(
                  color: _kGold.withValues(alpha: 0.7),
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3,
                )),
                const SizedBox(width: 10),
                Container(width: 40, height: 1,
                    color: _kGoldDark.withValues(alpha: 0.4)),
              ],
            ),
          ),
          Row(children: [
            Expanded(child: _BattleButton(
              label: _singleModeLoading ? '연결 중...' : '쇼다운',
              icon: _singleModeLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.bolt_rounded,
              onTap: _singleModeLoading ? () {} : _showShowdownModes,
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
              ),
              shadowColor: const Color(0xFF8B5010),
            )),
            const SizedBox(width: 12),
            Expanded(child: _BattleButton(
              label: '커스텀 모드', icon: Icons.people_rounded, onTap: () {},
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF7EC850), Color(0xFF4A8A20)],
              ),
              shadowColor: const Color(0xFF2A5010),
            )),
          ]),
        ],
      ),
    );
  }

  // ── 상단 바 ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
        ),
      ),
      child: Row(children: [
        _PlayerBadge(),
        const Spacer(),
        const _CurrencyBadge(
          icon: Icons.monetization_on_rounded, iconColor: _kGold, value: '8,350',
        ),
        const SizedBox(width: 6),
        const _CurrencyBadge(
          icon: Icons.diamond_rounded, iconColor: Color(0xFF72C6EF), value: '372',
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          icon: Icons.settings_rounded,
          onTap: () => _showSettingsMenu(context),
        ),
      ]),
    );
  }

  // ── 하단 네비게이션 (상점 · 경기 · 카드) ────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      _NavItem(icon: Icons.storefront_rounded, label: '상점'),
      _NavItem(icon: Icons.sports_soccer_rounded, label: '경기'),
      _NavItem(icon: Icons.style_rounded, label: '카드'),
    ];

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _kDarkBase.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: Color(0xFF4A5A25), width: 1.5)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 8, offset: const Offset(0, -2),
        )],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _navIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onNavTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: selected
                      ? _kOliveMid.withValues(alpha: 0.45)
                      : Colors.transparent,
                  border: selected
                      ? const Border(top: BorderSide(color: _kGold, width: 2.5))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(items[i].icon, size: 24,
                          color: selected ? _kGold : Colors.white30),
                    ),
                    const SizedBox(height: 4),
                    Text(items[i].label, style: TextStyle(
                      fontSize: 10,
                      color: selected ? _kGold : Colors.white30,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.school_rounded, color: _kGold),
            title: const Text('튜토리얼 다시하기',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: Text(
              '보상 없이 데모만 진행',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TutorialFlowScreen(isReplay: true),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
            title: const Text('로그아웃',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            onTap: () { Navigator.pop(context); _signOut(context); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _showShowdownModes() async {
    final selected = await showDialog<_ShowdownOpponent>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF243018), Color(0xFF1A220E), Color(0xFF2A1A0A)],
            ),
            border: Border.all(
              color: _kGold.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SHOWDOWN',
                    style: TextStyle(
                      color: _kGold.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '상대 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BattleButton(
                    label: 'vs User',
                    icon: Icons.person_rounded,
                    onTap: () =>
                        Navigator.of(ctx).pop(_ShowdownOpponent.vsUser),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
                    ),
                    shadowColor: const Color(0xFF8B5010),
                  ),
                  const SizedBox(height: 14),
                  _BattleButton(
                    label: 'vs Bot',
                    icon: Icons.smart_toy_rounded,
                    onTap: () =>
                        Navigator.of(ctx).pop(_ShowdownOpponent.vsBot),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF6BB8E8), Color(0xFF2F6FA8)],
                    ),
                    shadowColor: const Color(0xFF1A3A60),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: '닫기',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case _ShowdownOpponent.vsUser:
        await _joinSingleMode();
      case _ShowdownOpponent.vsBot:
        showErrorDialog(context, 'vs Bot은 곧 지원될 예정입니다.');
    }
  }

  Future<void> _joinSingleMode() async {
    if (_singleModeLoading) return;
    setState(() => _singleModeLoading = true);
    try {
      await MatchSessionCoordinator.onQueueJoin();
      final result = await _matchService.joinQueue();
      if (!mounted) return;

      if (result.isMatched) {
        await MatchSessionCoordinator.onMatchFound(
          matchSessionId: result.matchSessionId,
          gameMode: GameMode.single,
        );
        if (!mounted) return;
        // 즉시 매칭 → 매칭 완료 화면으로 바로 이동
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (_, __, ___) => MatchFoundScreen(
            matchSessionId: result.matchSessionId,
            gameMode: GameMode.single,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ));
      } else {
        // 대기 중 → 매칭 대기 화면으로 이동 (WebSocket에서 알림 수신)
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MatchmakingScreen(gameMode: GameMode.single),
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ));
      }
    } on MatchException catch (e) {
      if (mounted) {
        showErrorDialog(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        showErrorDialog(context, '네트워크 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) setState(() => _singleModeLoading = false);
    }
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

// ─── 상점 화면 (빈 화면) ─────────────────────────────────────────────────────

class _ShopScreen extends StatelessWidget {
  const _ShopScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_rounded, size: 64,
              color: _kGold.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text('상점', style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4,
          )),
        ],
      ),
    );
  }
}

// ─── 공용 위젯 ────────────────────────────────────────────────────────────────

class _PlayerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _kPanelBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kPanelBorder, width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_kOliveMid, _kBrownBase],
            ),
            border: Border.all(color: _kGold, width: 1.5),
          ),
          child: const Icon(Icons.person_rounded, size: 20, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        const Text('플레이어', style: TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
        )),
      ]),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  const _CurrencyBadge({required this.icon, required this.iconColor, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _kPanelBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPanelBorder, width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 4, offset: const Offset(0, 2),
        )],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
        )),
      ]),
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
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _kPanelBg.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kPanelBorder, width: 1.5),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4, offset: const Offset(0, 2),
          )],
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
    required this.label, required this.icon, required this.onTap,
    required this.gradient, required this.shadowColor,
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(widget.label, style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 3)],
          )),
        ]),
      ),
    );
  }
}

// ─── 배경 ─────────────────────────────────────────────────────────────────────

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(child: CustomPaint(painter: _BackgroundPainter()));
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E2810), Color(0xFF2D3A15), Color(0xFF3A2208)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final tilePaint = Paint()
      ..color = const Color(0xFF3D5020).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const tw = 30.0;
    const th = 30.0;
    for (double r = -1; r * th < size.height + th; r++) {
      for (double c = -1; c * tw < size.width + tw; c++) {
        final cx = c * tw;
        final cy = r * th;
        canvas.drawPath(Path()
          ..moveTo(cx + tw / 2, cy)
          ..lineTo(cx + tw, cy + th / 2)
          ..lineTo(cx + tw / 2, cy + th)
          ..lineTo(cx, cy + th / 2)
          ..close(), tilePaint);
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFF3A1A05).withValues(alpha: 0.55)],
        ).createShader(
          Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
