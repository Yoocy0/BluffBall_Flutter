import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/match_service.dart';
import '../services/match_session_storage.dart';
import '../services/game_session_restore_service.dart';
import '../services/team_service.dart';
import '../services/league_service.dart';
import '../services/league_match_service.dart';
import '../services/token_storage.dart';
import '../models/game_session_state_exception.dart';
import '../models/league_enums.dart';
import '../widgets/board_game_box.dart';
import '../widgets/exit_confirm_dialogs.dart';
import '../widgets/league_home_panel.dart';
import '../widgets/no_team_panel.dart';
import '../widgets/pitch_loadout_panel.dart';
import '../widgets/team_home_panel.dart';
import '../models/team.dart';
import '../models/team_pitch_cards.dart';
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

enum _GameStartMode { showdown, leagueCompact, leagueFull }

class _LeagueGate {
  final bool allowed;
  final String? hint;
  const _LeagueGate({required this.allowed, this.hint});
}

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
  int _navIndex = 2;     // 기본: 경기
  int _prevNavIndex = 2;
  bool _singleModeLoading = false;
  bool _restoreInProgress = false;
  bool _reconnectDialogVisible = false;
  bool _hasTeam = false;
  bool _teamStatusLoaded = false;
  Team? _myTeam;
  int? _myUserId;
  NoTeamPanelMode _noTeamMode = NoTeamPanelMode.idle;
  SavedMatchSession? _pendingMatchSession;

  final _matchService = MatchService();
  final _restoreService = GameSessionRestoreService();
  final _teamService = TeamService();
  final _leagueService = LeagueService();
  final _leagueMatchService = LeagueMatchService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingMatch();
      _refreshTeamStatus();
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
      final reconnect = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2A3518),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _kGold.withValues(alpha: 0.45)),
          ),
          icon: Icon(
            Icons.sports_baseball_rounded,
            color: _kGold.withValues(alpha: 0.9),
            size: 32,
          ),
          title: const Text(
            '진행 중인 매치가 있습니다',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            '중단된 경기를 이어서 진행할 수 있습니다.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                '나중에',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _kGold,
                foregroundColor: const Color(0xFF2A1F05),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '재접속',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF3A1A05),
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF3A1A05),
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Restore] 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('게임 복원에 실패했습니다. ($e)'),
            backgroundColor: const Color(0xFF3A1A05),
          ),
        );
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
      if (index != 3) _noTeamMode = NoTeamPanelMode.idle;
    });
    if (index == 3) _refreshTeamStatus();
  }

  Future<void> _refreshTeamStatus() async {
    try {
      final token = await TokenStorage().getAccessToken();
      final userIdStr =
          token != null ? MatchService.extractUserIdFromJwt(token) : null;
      final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      final team = await _teamService.getMyTeam();
      if (!mounted) return;
      setState(() {
        _myUserId = userId;
        _myTeam = team;
        _hasTeam = team != null;
        _teamStatusLoaded = true;
        if (team != null) _noTeamMode = NoTeamPanelMode.idle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myTeam = null;
        _hasTeam = false;
        _teamStatusLoaded = true;
      });
    }
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
                    if (_navIndex == 2 || _navIndex == 3 || _navIndex == 4)
                      const SizedBox(height: 8),
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
      case 0: return const _ShopScreen();
      case 1:
        return PitchLoadoutPanel(
          key: ValueKey('pitch-${_myTeam?.teamId ?? 0}'),
          team: _hasTeam ? _myTeam : null,
          isLeader: _myUserId != null &&
              _myTeam != null &&
              _myUserId == _myTeam!.leaderUserId,
        );
      case 3: return _hasTeam && _myTeam != null
          ? TeamHomePanel(
              key: ValueKey(_myTeam!.teamId),
              team: _myTeam!,
              onLeftTeam: _refreshTeamStatus,
              onTeamUpdated: (team) {
                setState(() => _myTeam = team);
              },
            )
          : NoTeamPanel(
              mode: _noTeamMode,
              onTeamReady: _refreshTeamStatus,
            );
      case 4:
        return LeagueHomePanel(
          key: ValueKey('league-${_myTeam?.teamId ?? 0}'),
          hasTeam: _hasTeam,
          teamName: _myTeam?.name,
          teamId: _myTeam?.teamId,
          isLeader: _myUserId != null &&
              _myTeam != null &&
              _myUserId == _myTeam!.leaderUserId,
        );
      default: return const BoardGameBox(heroTagOverride: BoardGameBox.heroTag);
    }
  }

  // ── 하단 버튼 (탭별) ─────────────────────────────────────────────────────
  Widget _buildBottomButtons() {
    switch (_navIndex) {
      case 2: return _buildMatchButtons();
      case 3: return _buildTeamButtons();
      default: return const SizedBox.shrink();
    }
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
              label: _singleModeLoading ? '연결 중...' : '게임 시작',
              icon: _singleModeLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.sports_esports_rounded,
              onTap: _singleModeLoading ? () {} : _showGameStartModes,
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

  Widget _buildTeamButtons() {
    if (!_teamStatusLoaded) return const SizedBox(height: 58);

    if (!_hasTeam) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          Expanded(child: _BattleButton(
            label: '검색',
            icon: Icons.search_rounded,
            onTap: () => setState(() => _noTeamMode = NoTeamPanelMode.search),
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF6BB8E8), Color(0xFF2F6FA8)],
            ),
            shadowColor: const Color(0xFF1A3A60),
          )),
          const SizedBox(width: 12),
          Expanded(child: _BattleButton(
            label: '창단',
            icon: Icons.add_home_rounded,
            onTap: () => setState(() => _noTeamMode = NoTeamPanelMode.create),
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
            ),
            shadowColor: const Color(0xFF8B5010),
          )),
        ]),
      );
    }

    // 소속 팀: 하단 정규/미니/유니폼 제거 (패널 안에서 전적·금고·로스터)
    return const SizedBox.shrink();
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

  // ── 하단 네비게이션 (4개) ────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      _NavItem(icon: Icons.storefront_rounded, label: '상점'),
      _NavItem(icon: Icons.style_rounded, label: '구종'),
      _NavItem(icon: Icons.sports_soccer_rounded, label: '경기'),
      _NavItem(icon: Icons.groups_rounded, label: '팀'),
      _NavItem(icon: Icons.emoji_events_rounded, label: '리그'),
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

  Future<void> _showGameStartModes() async {
    final canStartLeague = await _canStartLeagueMatch();
    if (!mounted) return;

    final selected = await showDialog<_GameStartMode>(
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
                    'MODE SELECT',
                    style: TextStyle(
                      color: _kGold.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '게임 모드 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BattleButton(
                    label: '쇼다운',
                    icon: Icons.bolt_rounded,
                    onTap: () => Navigator.of(ctx).pop(_GameStartMode.showdown),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
                    ),
                    shadowColor: const Color(0xFF8B5010),
                  ),
                  const SizedBox(height: 14),
                  _BattleButton(
                    label: '리그전(컴팩트)',
                    icon: Icons.sports_baseball_rounded,
                    enabled: canStartLeague.allowed,
                    onTap: () => Navigator.of(ctx).pop(_GameStartMode.leagueCompact),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF6BB8E8), Color(0xFF2F6FA8)],
                    ),
                    shadowColor: const Color(0xFF1A3A60),
                  ),
                  const SizedBox(height: 14),
                  _BattleButton(
                    label: '리그전(풀)',
                    icon: Icons.emoji_events_rounded,
                    enabled: canStartLeague.allowed,
                    onTap: () => Navigator.of(ctx).pop(_GameStartMode.leagueFull),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE07A4A), Color(0xFFA04020)],
                    ),
                    shadowColor: const Color(0xFF5A2010),
                  ),
                  if (canStartLeague.hint != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      canStartLeague.hint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
      case _GameStartMode.showdown:
        await _joinSingleMode();
      case _GameStartMode.leagueCompact:
        await _joinLeagueMode(LeagueFormat.compact, GameMode.teamMini);
      case _GameStartMode.leagueFull:
        await _joinLeagueMode(LeagueFormat.full, GameMode.teamRegular);
    }
  }

  Future<_LeagueGate> _canStartLeagueMatch() async {
    try {
      final team = await _teamService.getMyTeam();
      if (team == null) {
        return const _LeagueGate(
          allowed: false,
          hint: '리그전은 팀 소속 시에만 이용할 수 있습니다',
        );
      }

      final token = await TokenStorage().getAccessToken();
      final userIdStr =
          token != null ? MatchService.extractUserIdFromJwt(token) : null;
      final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      final isLeader = userId != null && userId == team.leaderUserId;
      if (!isLeader) {
        return const _LeagueGate(
          allowed: false,
          hint: '리그전 매칭은 팀 리더만 시작할 수 있습니다',
        );
      }
      return const _LeagueGate(allowed: true);
    } catch (_) {
      return const _LeagueGate(
        allowed: false,
        hint: '팀 정보를 확인할 수 없습니다',
      );
    }
  }

  /// 로스터·구종 미완 메시지. 준비됐으면 null.
  Future<String?> _leagueMatchReadyIssue(LeagueFormat format) async {
    final team = _myTeam ?? await _teamService.getMyTeam();
    if (team == null) return '소속 팀이 없습니다.';

    final batterCount = format == LeagueFormat.compact ? 3 : 9;
    final slotCount = format == LeagueFormat.compact ? 4 : 5;

    TeamLineup? lineup;
    TeamPitchCards? pitchCards;
    try {
      lineup = await _teamService.getLineup(team.teamId, format.apiValue);
      pitchCards =
          await _teamService.getPitchCards(team.teamId, format.apiValue);
    } catch (_) {
      return '출전 로스터 또는 구종 선택 정보를 확인할 수 없습니다.';
    }

    if (lineup == null ||
        lineup.userIds.length < batterCount ||
        lineup.startingPitcherUserId == null) {
      return '출전 로스터가 아직 등록되지 않았습니다.\n팀 탭에서 로스터를 완성해주세요.';
    }

    final rosterIds = <int>{...lineup.userIds, lineup.startingPitcherUserId!};
    final byUser = {
      for (final s in pitchCards?.selections ?? const <MemberPitchSelection>[])
        s.userId: s,
    };

    final pitcherId = lineup.startingPitcherUserId!;
    final pitcherSel = byUser[pitcherId];
    if (pitcherSel == null ||
        pitcherSel.cardIds.length < slotCount ||
        pitcherSel.dropCardId <= 0) {
      return '투수 구종 선택이 완료되지 않았습니다.\n구종 탭에서 투수 구종을 배치해주세요.';
    }

    for (final uid in rosterIds) {
      final sel = byUser[uid];
      if (sel == null ||
          sel.cardIds.length < slotCount ||
          sel.dropCardId <= 0) {
        return '출전 멤버의 구종 선택이 완료되지 않았습니다.\n구종 탭에서 전원 배치를 완료해주세요.';
      }
    }
    return null;
  }

  Future<void> _showLeagueMatchNotReadyDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A3518),
        title: const Text(
          '매칭 준비 미완료',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: _kGold),
            child: const Text(
              '확인',
              style: TextStyle(color: Color(0xFF2A1F05)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinLeagueMode(LeagueFormat format, GameMode gameMode) async {
    if (_singleModeLoading) return;
    setState(() => _singleModeLoading = true);
    try {
      final tier = await _leagueService.getCurrentTier(format);
      if (!mounted) return;
      if (tier == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${format == LeagueFormat.compact ? '컴팩트' : '풀'} 리그에 먼저 참가해야 합니다.',
            ),
            backgroundColor: const Color(0xFF3A1A05),
          ),
        );
        return;
      }

      final readyIssue = await _leagueMatchReadyIssue(format);
      if (!mounted) return;
      if (readyIssue != null) {
        await _showLeagueMatchNotReadyDialog(readyIssue);
        return;
      }

      await MatchSessionCoordinator.onQueueJoin();
      if (!mounted) return;

      // 대기 화면으로 먼저 이동해 WS 구독 후 join (push는 await하지 않음)
      if (mounted) setState(() => _singleModeLoading = false);
      final joinError = await Navigator.of(context).push<Object?>(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MatchmakingScreen(
            gameMode: gameMode,
            onCancelQueue: _leagueMatchService.cancelQueue,
            pendingJoin: () => _leagueMatchService.joinQueue(
              format: format,
              tier: tier,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      );

      if (!mounted) return;
      if (joinError is MatchException) {
        if (joinError.code == 'LEAGUE_MATCH_NOT_READY' ||
            joinError.message.contains('로스터') ||
            joinError.message.contains('구종')) {
          await _showLeagueMatchNotReadyDialog(joinError.message);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(joinError.message),
              backgroundColor: const Color(0xFF3A1A05),
            ),
          );
        }
      }
    } on MatchException catch (e) {
      if (!mounted) return;
      if (e.code == 'LEAGUE_MATCH_NOT_READY' ||
          e.message.contains('로스터') ||
          e.message.contains('구종')) {
        await _showLeagueMatchNotReadyDialog(e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF3A1A05),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네트워크 오류가 발생했습니다.'),
            backgroundColor: Color(0xFF3A1A05),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _singleModeLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF3A1A05),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네트워크 오류가 발생했습니다.'),
            backgroundColor: Color(0xFF3A1A05),
          ),
        );
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
  final bool enabled;
  const _BattleButton({
    required this.label, required this.icon, required this.onTap,
    required this.gradient, required this.shadowColor,
    this.enabled = true,
  });

  @override
  State<_BattleButton> createState() => _BattleButtonState();
}

class _BattleButtonState extends State<_BattleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 58,
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(
            gradient: enabled
                ? widget.gradient
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF5A5A5A), Color(0xFF3A3A3A)],
                  ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: (!enabled || _pressed)
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
              color: Colors.white.withValues(alpha: enabled ? 0.15 : 0.08),
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
