import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'matchmaking_screen.dart';

// ─── 색상 팔레트 ────────────────────────────────────────────────────────────
const _kDarkBase = Color(0xFF161D0B);
const _kOliveMid = Color(0xFF3D5020);
const _kBrownBase = Color(0xFF5C3010);
const _kGold = Color(0xFFFFD700);
const _kGoldDark = Color(0xFFB8860B);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);

// ─── 데이터 모델 ─────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _PlayerInfo {
  final String name;
  final bool isOnline;
  final String position;
  const _PlayerInfo(this.name, {required this.isOnline, required this.position});
}

class _WardrobeCategory {
  final String label;
  final IconData icon;
  const _WardrobeCategory(this.label, this.icon);
}

class _WardrobeItem {
  final String name;
  final Color color;
  final bool isEquipped;
  const _WardrobeItem(this.name, this.color, {this.isEquipped = false});
}

// ─── 샘플 데이터 ─────────────────────────────────────────────────────────────

const _samplePlayers = [
  _PlayerInfo('플레이어1', isOnline: true, position: '투수'),
  _PlayerInfo('플레이어2', isOnline: true, position: '포수'),
  _PlayerInfo('플레이어3', isOnline: false, position: '1루수'),
  _PlayerInfo('플레이어4', isOnline: true, position: '2루수'),
  _PlayerInfo('플레이어5', isOnline: false, position: '3루수'),
  _PlayerInfo('플레이어6', isOnline: false, position: '유격수'),
  _PlayerInfo('플레이어7', isOnline: true, position: '좌익수'),
  _PlayerInfo('플레이어8', isOnline: false, position: '중견수'),
  _PlayerInfo('플레이어9', isOnline: true, position: '우익수'),
];

const _wardrobeCategories = [
  _WardrobeCategory('상의', Icons.dry_cleaning_rounded),
  _WardrobeCategory('하의', Icons.airline_seat_legroom_normal_rounded),
  _WardrobeCategory('신발', Icons.hiking_rounded),
  _WardrobeCategory('카드', Icons.style_rounded),
  _WardrobeCategory('주사위', Icons.casino_rounded),
];

final _wardrobeItems = <int, List<_WardrobeItem>>{
  0: [
    const _WardrobeItem('기본 티셔츠', Color(0xFF1A3A7A), isEquipped: true),
    const _WardrobeItem('빨간 저지', Color(0xFF8A1A1A)),
    const _WardrobeItem('그린 유니폼', Color(0xFF1A6A2A)),
    const _WardrobeItem('레트로 셔츠', Color(0xFF7A5A1A)),
    const _WardrobeItem('퍼플 상의', Color(0xFF5A1A7A)),
    const _WardrobeItem('한정판', Color(0xFF1A6A6A)),
  ],
  1: [
    const _WardrobeItem('기본 바지', Color(0xFF2A2A7A), isEquipped: true),
    const _WardrobeItem('스포츠 숏츠', Color(0xFF7A2A4A)),
    const _WardrobeItem('트레이닝 팬츠', Color(0xFF2A5A2A)),
    const _WardrobeItem('슬림 핏', Color(0xFF5A3A1A)),
  ],
  2: [
    const _WardrobeItem('클래식 스파이크', Color(0xFF3A2A1A), isEquipped: true),
    const _WardrobeItem('레드 클리츠', Color(0xFF7A1A1A)),
    const _WardrobeItem('화이트 슈즈', Color(0xFF5A5A5A)),
    const _WardrobeItem('골드 스파이크', Color(0xFF7A6A1A)),
  ],
  3: [
    const _WardrobeItem('스트라이크 카드', Color(0xFF1A4A7A), isEquipped: true),
    const _WardrobeItem('홈런 카드', Color(0xFF8A3A1A)),
    const _WardrobeItem('번트 카드', Color(0xFF3A7A1A)),
    const _WardrobeItem('도루 카드', Color(0xFF6A1A6A)),
    const _WardrobeItem('희생번트', Color(0xFF1A6A5A)),
    const _WardrobeItem('전력질주', Color(0xFF7A4A1A)),
  ],
  4: [
    const _WardrobeItem('기본 주사위', Color(0xFF4A4A4A), isEquipped: true),
    const _WardrobeItem('화염 주사위', Color(0xFF8A2A1A)),
    const _WardrobeItem('얼음 주사위', Color(0xFF1A5A8A)),
    const _WardrobeItem('황금 주사위', Color(0xFF7A6A1A)),
  ],
};

// ─── 홈 화면 ─────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 2;     // 기본: 경기
  int _prevNavIndex = 2;

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() {
      _prevNavIndex = _navIndex;
      _navIndex = index;
    });
  }

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
                  Expanded(child: _buildMainContent()),
                  _buildBottomButtons(),
                  if (_navIndex == 2 || _navIndex == 3) const SizedBox(height: 8),
                  _buildBottomNav(),
                ],
              ),
            ),
          ],
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
      case 1: return const _WardrobeScreen();
      case 3: return const _TeamPanel();
      default: return const _AnimatedCharacter();
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
              label: '싱글 모드', icon: Icons.person_rounded,
              onTap: () => Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const MatchmakingScreen(),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(
                  opacity: anim, child: child,
                ),
                transitionDuration: const Duration(milliseconds: 350),
              )),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        Expanded(child: _BattleButton(
          label: '정규 모드', icon: Icons.emoji_events_rounded, onTap: () {},
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
          ),
          shadowColor: const Color(0xFF8B5010),
        )),
        const SizedBox(width: 10),
        Expanded(child: _BattleButton(
          label: '미니 모드', icon: Icons.sports_baseball_rounded, onTap: () {},
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC850), Color(0xFF4A8A20)],
          ),
          shadowColor: const Color(0xFF2A5010),
        )),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showUniformSettings(context),
          child: Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF6B8EE0), Color(0xFF3A5AB0)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: const Color(0xFF1A3070).withValues(alpha: 0.9),
                offset: const Offset(0, 4), blurRadius: 0,
              )],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), width: 1,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.checkroom_rounded, color: Colors.white, size: 20),
                SizedBox(height: 2),
                Text('유니폼', style: TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                )),
              ],
            ),
          ),
        ),
      ]),
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

  // ── 하단 네비게이션 (4개) ────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      _NavItem(icon: Icons.storefront_rounded, label: '상점'),
      _NavItem(icon: Icons.checkroom_rounded, label: '옷장'),
      _NavItem(icon: Icons.sports_soccer_rounded, label: '경기'),
      _NavItem(icon: Icons.groups_rounded, label: '팀'),
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

  void _showUniformSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const _UniformSettingsSheet(),
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

// ─── 옷장 화면 ────────────────────────────────────────────────────────────────

class _WardrobeScreen extends StatefulWidget {
  const _WardrobeScreen();

  @override
  State<_WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<_WardrobeScreen> {
  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 작아진 캐릭터
      const SizedBox(
        height: 175,
        child: _AnimatedCharacter(),
      ),
      // 카테고리 + 아이템 그리드
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌측 카테고리 목록
            _buildCategoryList(),
            // 우측 아이템 그리드
            Expanded(child: _buildItemGrid()),
          ],
        ),
      ),
    ]);
  }

  Widget _buildCategoryList() {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: _kDarkBase.withValues(alpha: 0.6),
        border: Border(
          right: BorderSide(color: _kPanelBorder.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _wardrobeCategories.length,
        itemBuilder: (_, i) {
          final selected = _selectedCategory == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? _kOliveMid.withValues(alpha: 0.6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? _kGold.withValues(alpha: 0.6) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(_wardrobeCategories[i].icon, size: 22,
                      color: selected ? _kGold : Colors.white38),
                  const SizedBox(height: 4),
                  Text(_wardrobeCategories[i].label, style: TextStyle(
                    fontSize: 10,
                    color: selected ? _kGold : Colors.white38,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemGrid() {
    final items = _wardrobeItems[_selectedCategory] ?? [];
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ItemCard(item: items[i]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final _WardrobeItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _kPanelBg.withValues(alpha: 0.8),
          border: Border.all(
            color: item.isEquipped
                ? _kGold.withValues(alpha: 0.7)
                : _kPanelBorder.withValues(alpha: 0.4),
            width: item.isEquipped ? 2 : 1,
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      item.color.withValues(alpha: 0.9),
                      item.color.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _wardrobeCategories[_getIconIndexForItem(item)].icon,
                        size: 40, color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    if (item.isEquipped)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('착용 중', style: TextStyle(
                            color: Colors.black, fontSize: 8,
                            fontWeight: FontWeight.w900,
                          )),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text(item.name,
                style: const TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getIconIndexForItem(_WardrobeItem item) {
    for (final entry in _wardrobeItems.entries) {
      if (entry.value.contains(item)) return entry.key;
    }
    return 0;
  }
}

// ─── 팀 패널 ─────────────────────────────────────────────────────────────────

class _TeamPanel extends StatelessWidget {
  const _TeamPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kPanelBorder, width: 2),
          color: _kPanelBg.withValues(alpha: 0.92),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14, offset: const Offset(0, 4),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            Container(height: 3, decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBrownBase, _kGold, _kBrownBase],
              ),
            )),
            _buildTeamHeader(context),
            Divider(color: _kPanelBorder.withValues(alpha: 0.5), height: 1),
            const Expanded(child: _PlayerList()),
            Container(height: 3, decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBrownBase, _kGold, _kBrownBase],
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildTeamHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF4A6A28), _kBrownBase],
            ),
            border: Border.all(color: _kGold, width: 2),
            boxShadow: [BoxShadow(
              color: _kGold.withValues(alpha: 0.2),
              blurRadius: 8, spreadRadius: 1,
            )],
          ),
          child: const Icon(Icons.shield_rounded, color: _kGold, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('팀 이름', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
            )),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 7, height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF5EE85E),
                  )),
              const SizedBox(width: 5),
              Text(
                '접속 중 ${_samplePlayers.where((p) => p.isOnline).length}명',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 12,
                )),
            ]),
          ],
        )),
        GestureDetector(
          onTap: () => _showRecords(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kOliveMid.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kPanelBorder, width: 1.5),
            ),
            child: Row(children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: _kGold),
              const SizedBox(width: 4),
              Text('기록', style: TextStyle(
                color: _kGold.withValues(alpha: 0.9),
                fontSize: 12, fontWeight: FontWeight.w700,
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showRecords(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2),
              ))),
          const SizedBox(height: 20),
          const Text('팀 기록', style: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 16),
          _RecordRow(label: '정규 모드', win: 12, lose: 5),
          const SizedBox(height: 8),
          _RecordRow(label: '미니 모드', win: 20, lose: 8),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final String label;
  final int win;
  final int lose;
  const _RecordRow({required this.label, required this.win, required this.lose});

  @override
  Widget build(BuildContext context) {
    final total = win + lose;
    final winRate = total > 0 ? win / total : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kOliveMid.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPanelBorder.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text('$win승 $lose패', style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
        )),
        const SizedBox(width: 12),
        Text('${(winRate * 100).toStringAsFixed(0)}%', style: TextStyle(
          color: winRate >= 0.5 ? const Color(0xFF7EC850) : const Color(0xFFFF6B6B),
          fontSize: 14, fontWeight: FontWeight.w700,
        )),
      ]),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text('소속 플레이어', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
        )),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          itemCount: _samplePlayers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) => _PlayerRow(player: _samplePlayers[i]),
        ),
      ),
    ]);
  }
}

class _PlayerRow extends StatelessWidget {
  final _PlayerInfo player;
  const _PlayerRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: player.isOnline
            ? _kOliveMid.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: player.isOnline
              ? _kPanelBorder.withValues(alpha: 0.6)
              : _kPanelBorder.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: player.isOnline ? const Color(0xFF5EE85E) : Colors.white24,
          boxShadow: player.isOnline ? [BoxShadow(
            color: const Color(0xFF5EE85E).withValues(alpha: 0.6),
            blurRadius: 6, spreadRadius: 1,
          )] : null,
        )),
        const SizedBox(width: 10),
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kOliveMid.withValues(alpha: 0.4),
            border: Border.all(color: _kPanelBorder, width: 1),
          ),
          child: const Icon(Icons.person_rounded, size: 18, color: Colors.white54),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(player.name, style: TextStyle(
              color: player.isOnline ? Colors.white : Colors.white54,
              fontSize: 13, fontWeight: FontWeight.w600,
            )),
            Text(player.position, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), fontSize: 10,
            )),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: player.isOnline
                ? const Color(0xFF2A5A20).withValues(alpha: 0.6)
                : Colors.black26,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            player.isOnline ? '접속 중' : '오프라인',
            style: TextStyle(
              color: player.isOnline ? const Color(0xFF8AE870) : Colors.white30,
              fontSize: 10, fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── 유니폼 설정 ──────────────────────────────────────────────────────────────

class _UniformSettingsSheet extends StatefulWidget {
  const _UniformSettingsSheet();

  @override
  State<_UniformSettingsSheet> createState() => _UniformSettingsSheetState();
}

class _UniformSettingsSheetState extends State<_UniformSettingsSheet> {
  int _selectedColor = 0;
  int _selectedNumber = 0;

  static const _teamColors = [
    Color(0xFF1A3A8A), Color(0xFF8A1A1A), Color(0xFF1A6A2A),
    Color(0xFF6A1A6A), Color(0xFF8A6A1A), Color(0xFF1A6A6A),
  ];
  static const _numbers = ['01','02','05','07','10','11','13','22','99'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(2),
        ))),
        const SizedBox(height: 20),
        const Text('유니폼 설정', style: TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
        )),
        const SizedBox(height: 20),
        Text('팀 컬러', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2,
        )),
        const SizedBox(height: 12),
        Row(children: List.generate(_teamColors.length, (i) {
          final sel = _selectedColor == i;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedColor = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: sel ? 38 : 32, height: sel ? 38 : 32,
                decoration: BoxDecoration(
                  color: _teamColors[i], shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? _kGold : Colors.white24,
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel ? [BoxShadow(
                    color: _kGold.withValues(alpha: 0.4), blurRadius: 8,
                  )] : null,
                ),
              ),
            ),
          );
        })),
        const SizedBox(height: 20),
        Text('등번호', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2,
        )),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8,
          children: List.generate(_numbers.length, (i) {
            final sel = _selectedNumber == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedNumber = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 50, height: 42,
                decoration: BoxDecoration(
                  color: sel
                      ? _kOliveMid.withValues(alpha: 0.8)
                      : _kPanelBg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? _kGold : _kPanelBorder.withValues(alpha: 0.5),
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Center(child: Text(_numbers[i], style: TextStyle(
                  color: sel ? _kGold : Colors.white54,
                  fontSize: 16, fontWeight: FontWeight.w800,
                ))),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF8B5010).withValues(alpha: 0.9),
                  offset: const Offset(0, 4), blurRadius: 0,
                )],
              ),
              child: const Center(child: Text('저장', style: TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w900, letterSpacing: 1,
              ))),
            ),
          ),
        ),
      ]),
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
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 58,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _pressed ? [] : [
            BoxShadow(color: widget.shadowColor.withValues(alpha: 0.9),
                offset: const Offset(0, 4), blurRadius: 0),
            BoxShadow(color: Colors.black.withValues(alpha: 0.35),
                offset: const Offset(0, 6), blurRadius: 10),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15), width: 1,
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

// ─── 캐릭터 플로팅 애니메이션 ────────────────────────────────────────────────

class _AnimatedCharacter extends StatefulWidget {
  const _AnimatedCharacter({super.key});

  @override
  State<_AnimatedCharacter> createState() => _AnimatedCharacterState();
}

class _AnimatedCharacterState extends State<_AnimatedCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _floatY;
  late final Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: -7, end: 7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _shadow = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(top: 0, bottom: 16, left: 0, right: 0,
              child: Transform.translate(
                offset: Offset(0, _floatY.value), child: child,
              )),
            Positioned(bottom: 4,
              child: Transform.scale(scaleX: _shadow.value,
                child: Container(
                  width: constraints.maxWidth * 0.3, height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.black.withValues(alpha: 0.4),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12, spreadRadius: 3,
                    )],
                  ),
                ),
              )),
          ],
        ),
        child: Image.asset('assets/images/character.png',
          fit: BoxFit.contain, alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high),
      );
    });
  }
}
