import 'package:flutter/material.dart';

import '../models/catalog_pitch_card.dart';
import '../models/league_enums.dart';
import '../models/team.dart';
import '../models/team_pitch_cards.dart';
import '../services/card_service.dart';
import '../services/team_service.dart';

const _kGold = Color(0xFFFFD700);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);
const _kOliveMid = Color(0xFF3D5020);
const _kBrownBase = Color(0xFF5C3010);
const _kDropSlot = Color(0xFF5A3420);

const _kPreviewUserId = -1;

/// API 실패 시에도 드래그 UI를 확인할 수 있는 샘플 구종
const _kFallbackCatalog = <CatalogPitchCard>[
  CatalogPitchCard(
      cardId: 101, name: '포심', changeAmount: 0, direction: 'NONE', timing: 'NORMAL'),
  CatalogPitchCard(
      cardId: 102, name: '슬라이더', changeAmount: 2, direction: 'LEFT', timing: 'EARLY'),
  CatalogPitchCard(
      cardId: 103, name: '커브', changeAmount: 3, direction: 'DOWN', timing: 'LATE'),
  CatalogPitchCard(
      cardId: 104, name: '체인지업', changeAmount: 1, direction: 'DOWN', timing: 'LATE'),
  CatalogPitchCard(
      cardId: 105, name: '컷터', changeAmount: 1, direction: 'RIGHT', timing: 'NORMAL'),
  CatalogPitchCard(
      cardId: 106, name: '싱커', changeAmount: 2, direction: 'DOWN_LEFT', timing: 'EARLY'),
];

/// 구종 탭 — 포맷별 멤버 구종 슬롯 드래그 배치
class PitchLoadoutPanel extends StatefulWidget {
  final Team? team;
  final bool isLeader;

  const PitchLoadoutPanel({
    super.key,
    required this.team,
    required this.isLeader,
  });

  @override
  State<PitchLoadoutPanel> createState() => _PitchLoadoutPanelState();
}

class _PitchLoadoutPanelState extends State<PitchLoadoutPanel> {
  final _teamService = TeamService();
  final _cardService = CardService();

  LeagueFormat _format = LeagueFormat.compact;
  List<CatalogPitchCard> _catalog = const [];
  List<TeamMember> _members = const [];
  List<int> _rosterUserIds = const [];
  int? _selectedUserId;

  /// 탭으로 고른 카드 (드래그 보조)
  int? _pickedCardId;

  /// userId → 슬롯(cardId?), 마지막 슬롯 = drop
  final Map<int, List<int?>> _slotsByUser = {};

  bool _loading = false;
  bool _saving = false;
  bool _usingPreviewRoster = false;

  int get _slotCount => _format == LeagueFormat.compact ? 4 : 5;

  bool get _canEdit => widget.team != null;

  List<int?> get _currentSlots {
    final id = _selectedUserId;
    if (id == null) return List<int?>.filled(_slotCount, null);
    return _slotsByUser.putIfAbsent(
      id,
      () => List<int?>.filled(_slotCount, null),
    );
  }

  CatalogPitchCard? _cardOf(int? id) {
    if (id == null) return null;
    for (final c in _catalog) {
      if (c.cardId == id) return c;
    }
    return null;
  }

  String _nicknameOf(int userId) {
    if (userId == _kPreviewUserId) return '미리보기';
    for (final m in _members) {
      if (m.userId == userId) return m.nickname;
    }
    return '유저 $userId';
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant PitchLoadoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team?.teamId != widget.team?.teamId) {
      _bootstrap();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3A1A05),
      ),
    );
  }

  Future<void> _bootstrap() async {
    if (widget.team == null) {
      setState(() {
        _catalog = const [];
        _members = const [];
        _rosterUserIds = const [];
        _selectedUserId = null;
        _slotsByUser.clear();
        _pickedCardId = null;
        _usingPreviewRoster = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      List<CatalogPitchCard> catalog = const [];
      try {
        catalog = await _cardService.getPitchCards();
      } catch (_) {
        catalog = const [];
      }
      if (catalog.isEmpty) catalog = _kFallbackCatalog;

      List<TeamMember> members = const [];
      try {
        members = await _teamService.getMembers(widget.team!.teamId);
      } catch (_) {
        members = const [];
      }

      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _members = members;
      });
      await _loadFormat(_format);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalog = _kFallbackCatalog;
        _loading = false;
      });
      await _loadFormat(_format);
    }
  }

  Future<void> _loadFormat(LeagueFormat format) async {
    final team = widget.team;
    if (team == null) return;
    setState(() => _loading = true);

    final slotCount = format == LeagueFormat.compact ? 4 : 5;
    List<int> roster = const [];
    TeamPitchCards? saved;

    try {
      final lineup = await _teamService.getLineup(team.teamId, format.apiValue);
      if (lineup != null) {
        final ids = <int>[...lineup.userIds];
        if (format == LeagueFormat.compact &&
            lineup.startingPitcherUserId != null &&
            !ids.contains(lineup.startingPitcherUserId)) {
          ids.add(lineup.startingPitcherUserId!);
        }
        roster = ids;
      }
      saved = await _teamService.getPitchCards(team.teamId, format.apiValue);
    } catch (_) {
      // 로스터/저장값이 없어도 UI는 동작
    }

    final preview = roster.isEmpty;
    if (preview) roster = const [_kPreviewUserId];

    final slots = <int, List<int?>>{};
    for (final uid in roster) {
      slots[uid] = List<int?>.filled(slotCount, null);
    }

    if (saved != null && !preview) {
      for (final sel in saved.selections) {
        if (!roster.contains(sel.userId)) continue;
        final list = List<int?>.filled(slotCount, null);
        final ordered = [...sel.cardIds];
        if (ordered.contains(sel.dropCardId)) {
          ordered
            ..remove(sel.dropCardId)
            ..add(sel.dropCardId);
        }
        for (var i = 0; i < ordered.length && i < list.length; i++) {
          list[i] = ordered[i];
        }
        slots[sel.userId] = list;
      }
    }

    if (!mounted) return;
    setState(() {
      _format = format;
      _rosterUserIds = roster;
      _usingPreviewRoster = preview;
      _slotsByUser
        ..clear()
        ..addAll(slots);
      _selectedUserId = roster.first;
      _pickedCardId = null;
      _loading = false;
    });
  }

  void _setSlot(int index, int? cardId) {
    final uid = _selectedUserId;
    if (uid == null || !_canEdit) return;
    final slots = List<int?>.from(_currentSlots);
    while (slots.length < _slotCount) {
      slots.add(null);
    }
    if (cardId != null) {
      for (var i = 0; i < slots.length; i++) {
        if (slots[i] == cardId) slots[i] = null;
      }
    }
    slots[index] = cardId;
    setState(() {
      _slotsByUser[uid] = slots;
      _pickedCardId = null;
    });
    // Compact 4 / Full 5칸이 다 채워지면 자동 저장 시도
    if (slots.every((id) => id != null)) {
      _maybeAutoSave();
    }
  }

  bool get _allMembersFilled {
    if (_rosterUserIds.isEmpty || _usingPreviewRoster) return false;
    for (final uid in _rosterUserIds) {
      final slots = _slotsByUser[uid] ?? const <int?>[];
      if (slots.length < _slotCount || slots.any((id) => id == null)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _maybeAutoSave() async {
    if (!widget.isLeader || _saving || _usingPreviewRoster) return;
    if (!_allMembersFilled) {
      _toast('이 멤버 배치 완료. 전원 배치가 끝나면 자동 저장됩니다.');
      return;
    }
    await _save();
  }

  void _onPoolCardTap(int cardId) {
    if (!_canEdit) return;
    final used = _currentSlots.contains(cardId);
    if (used) {
      // 이미 배치된 카드면 슬롯에서 제거
      final idx = _currentSlots.indexOf(cardId);
      if (idx >= 0) _setSlot(idx, null);
      return;
    }
    // 빈 슬롯에 바로 넣기
    final empty = _currentSlots.indexWhere((id) => id == null);
    if (empty >= 0) {
      _setSlot(empty, cardId);
      return;
    }
    setState(() => _pickedCardId = cardId);
  }

  void _onSlotTap(int index) {
    if (!_canEdit) return;
    final current = _currentSlots[index];
    if (_pickedCardId != null) {
      _setSlot(index, _pickedCardId);
      return;
    }
    if (current != null) {
      _setSlot(index, null);
    }
  }

  Future<void> _save() async {
    final team = widget.team;
    if (team == null || !widget.isLeader || _saving) return;
    if (_usingPreviewRoster) return;

    final selections = <MemberPitchSelection>[];
    for (final uid in _rosterUserIds) {
      final slots = _slotsByUser[uid] ?? List<int?>.filled(_slotCount, null);
      if (slots.any((id) => id == null)) return;
      final ids = slots.cast<int>();
      selections.add(
        MemberPitchSelection(
          userId: uid,
          cardIds: ids,
          dropCardId: ids.last,
        ),
      );
    }

    setState(() => _saving = true);
    try {
      await _teamService.upsertPitchCards(
        teamId: team.teamId,
        format: _format.apiValue,
        selections: selections,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('구종 카드를 저장했습니다.');
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('구종 카드 저장에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kPanelBorder, width: 2),
          color: _kPanelBg.withValues(alpha: 0.92),
        ),
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kBrownBase, _kGold, _kBrownBase],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kBrownBase, _kGold, _kBrownBase],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.team == null) {
      return const _CenterMsg(
        title: '팀 소속이 필요합니다',
        subtitle: '팀에 가입한 뒤 구종 카드를 설정할 수 있습니다.',
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _FormatChip(
                  label: 'Compact',
                  selected: _format == LeagueFormat.compact,
                  onTap: () => _loadFormat(LeagueFormat.compact),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormatChip(
                  label: 'Full',
                  selected: _format == LeagueFormat.full,
                  onTap: () => _loadFormat(LeagueFormat.full),
                ),
              ),
            ],
          ),
        ),
        if (_rosterUserIds.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _rosterUserIds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final uid = _rosterUserIds[i];
                final selected = uid == _selectedUserId;
                return ChoiceChip(
                  label: Text(
                    _nicknameOf(uid),
                    style: TextStyle(
                      color: selected ? const Color(0xFF2A1F05) : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: selected,
                  selectedColor: _kGold,
                  backgroundColor: Colors.black.withValues(alpha: 0.25),
                  side: BorderSide(
                    color: selected
                        ? _kGold
                        : _kPanelBorder.withValues(alpha: 0.6),
                  ),
                  onSelected: (_) => setState(() {
                    _selectedUserId = uid;
                    _pickedCardId = null;
                  }),
                );
              },
            ),
          ),
        if (_usingPreviewRoster)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              '로스터가 없어 미리보기 모드입니다. 드래그로 배치를 확인할 수 있어요.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '배치 슬롯',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '끌어서 놓기 · 탭으로도 배치',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 104,
            child: Row(
              children: List.generate(_slotCount, (i) {
                final isDrop = i == _slotCount - 1;
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: i == _slotCount - 1 ? 0 : 6),
                    child: _SlotTarget(
                      card: _cardOf(_currentSlots[i]),
                      isDropSlot: isDrop,
                      highlighted: _pickedCardId != null,
                      onAccept: (cardId) => _setSlot(i, cardId),
                      onTap: () => _onSlotTap(i),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '보유 구종',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: _catalog.length,
            itemBuilder: (_, i) {
              final card = _catalog[i];
              final used = _currentSlots.contains(card.cardId);
              final picked = _pickedCardId == card.cardId;
              return _PoolCard(
                card: card,
                used: used,
                picked: picked,
                onTap: () => _onPoolCardTap(card.cardId),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _toast('구종 강화는 곧 연동됩니다.'),
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: _kGold, size: 18),
              label: Text(
                _saving ? '구종 저장 중...' : '구종 카드 강화',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _kPanelBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterMsg extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CenterMsg({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_rounded,
                size: 48, color: _kGold.withValues(alpha: 0.45)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _kOliveMid.withValues(alpha: 0.75)
                : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _kGold.withValues(alpha: 0.75) : _kPanelBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _kGold : Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotTarget extends StatelessWidget {
  final CatalogPitchCard? card;
  final bool isDropSlot;
  final bool highlighted;
  final ValueChanged<int> onAccept;
  final VoidCallback onTap;

  const _SlotTarget({
    required this.card,
    required this.isDropSlot,
    required this.highlighted,
    required this.onAccept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isDropSlot
                  ? _kDropSlot.withValues(alpha: hovering ? 0.9 : 0.7)
                  : _kOliveMid.withValues(alpha: hovering ? 0.7 : 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hovering || highlighted
                    ? _kGold
                    : (isDropSlot
                        ? const Color(0xFFC4783A)
                        : _kPanelBorder.withValues(alpha: 0.7)),
                width: hovering || highlighted ? 2 : 1.2,
              ),
            ),
            child: card == null
                ? Center(
                    child: Text(
                      isDropSlot ? 'DROP' : '+',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: isDropSlot ? 11 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : _MiniCardFace(card: card!, compact: true),
          ),
        );
      },
    );
  }
}

class _PoolCard extends StatelessWidget {
  final CatalogPitchCard card;
  final bool used;
  final bool picked;
  final VoidCallback onTap;

  const _PoolCard({
    required this.card,
    required this.used,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: picked ? _kGold : Colors.transparent,
          width: 2,
        ),
      ),
      child: Opacity(
        opacity: used ? 0.4 : 1,
        child: _MiniCardFace(card: card, compact: false),
      ),
    );

    // 이미 쓴 카드는 탭으로만 해제
    if (used) {
      return GestureDetector(onTap: onTap, child: face);
    }

    return Draggable<int>(
      data: card.cardId,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        child: SizedBox(
          width: 78,
          height: 100,
          child: _MiniCardFace(card: card, compact: false),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.2, child: face),
      child: GestureDetector(
        onTap: onTap,
        child: face,
      ),
    );
  }
}

class _MiniCardFace extends StatelessWidget {
  final CatalogPitchCard card;
  final bool compact;

  const _MiniCardFace({required this.card, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A220E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const Spacer(),
          Text(
            card.changeLabel,
            style: TextStyle(
              color: _kGold.withValues(alpha: 0.9),
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 2),
            Text(
              card.timing,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
