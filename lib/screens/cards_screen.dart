import 'package:flutter/material.dart';

import '../models/enhancement_card.dart';
import '../models/user_pitch_card.dart';
import '../services/user_inventory_service.dart';
import '../utils/api_error_ui.dart';
import '../widgets/app_dialog.dart';

/// 실물 카드 비율 (가로 : 세로 = 5.6 : 8.7)
const double kPitchCardAspectRatio = 5.6 / 8.7;

const _kGold = Color(0xFFFFD700);
const _kGoldDark = Color(0xFFD4821A);
const _kPanelBg = Color(0xFF242F12);
const _kRevertBg = Color(0xFF4A4A4A);
const _kRevertDisabled = Color(0xFF2E2E2E);

/// 홈 하단 「카드」탭 — 보유 구종 조회.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final _service = UserInventoryService();

  List<UserPitchCard>? _cards;
  String? _error;
  bool _loading = true;
  bool _actionBusy = false;
  UserPitchCard? _selected;
  int _enhancementCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      final cards = await _service.fetchPitchCards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
      await _refreshEnhancementCount();
    } on InventoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '보유 구종을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _refreshEnhancementCount() async {
    try {
      final enhancements = await _service.fetchEnhancementCards();
      if (!mounted) return;
      setState(() {
        _enhancementCount =
            enhancements.fold<int>(0, (sum, e) => sum + e.quantity);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _enhancementCount = 0);
    }
  }

  void _selectCard(UserPitchCard card) {
    setState(() => _selected = card);
  }

  void _clearSelection() {
    if (_actionBusy) return;
    setState(() => _selected = null);
  }

  void _applyUpdatedCard(UserPitchCard updated) {
    final list = _cards;
    if (list == null) return;
    final idx =
        list.indexWhere((c) => c.userPitchCardId == updated.userPitchCardId);
    setState(() {
      if (idx >= 0) {
        list[idx] = updated;
      }
      _selected = updated;
      _actionBusy = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      showErrorDialog(context, message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A3518),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onEnhanceTap(UserPitchCard card) async {
    if (_actionBusy) return;

    List<EnhancementCard> owned;
    try {
      owned = await _service.fetchEnhancementCards();
    } on InventoryException catch (e) {
      _showMessage(e.message, isError: true);
      return;
    } catch (_) {
      _showMessage('강화 카드를 불러오지 못했습니다.', isError: true);
      return;
    }
    if (!mounted) return;

    final usable = owned.where((e) {
      if (e.quantity <= 0) return false;
      if (e.effect.isChangeAmount && card.changeAmountEnhanced) return false;
      if (e.effect.isTiming && card.timingEnhanced) return false;
      return e.effect != EnhancementEffect.unknown;
    }).toList();

    if (usable.isEmpty) {
      final bothDone = card.changeAmountEnhanced && card.timingEnhanced;
      _showMessage(
        bothDone
            ? '이미 변화량·타이밍 강화가 모두 적용되어 있습니다.'
            : '사용 가능한 강화 카드가 없습니다.',
        isError: true,
      );
      return;
    }

    final picked = await showModalBottomSheet<EnhancementCard>(
      context: context,
      backgroundColor: const Color(0xFF1A220E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _EnhancePickerSheet(items: usable),
    );
    if (picked == null || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      final updated = await _service.enhancePitchCard(
        userPitchCardId: card.userPitchCardId,
        enhancementCardId: picked.cardId,
      );
      if (!mounted) return;
      _applyUpdatedCard(updated);
      await _refreshEnhancementCount();
      _showMessage('${picked.name} 강화가 적용되었습니다.');
    } on InventoryException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      _showMessage('강화에 실패했습니다.', isError: true);
    }
  }

  Future<void> _onRevertTap(UserPitchCard card) async {
    if (_actionBusy || !card.isEnhanced) return;

    final kinds = <EnhanceRevertKind>[
      if (card.changeAmountEnhanced) EnhanceRevertKind.changeAmount,
      if (card.timingEnhanced) EnhanceRevertKind.timing,
    ];
    if (kinds.isEmpty) return;

    EnhanceRevertKind? kind = kinds.length == 1
        ? kinds.first
        : await showModalBottomSheet<EnhanceRevertKind>(
            context: context,
            backgroundColor: const Color(0xFF1A220E),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (ctx) => _RevertPickerSheet(kinds: kinds),
          );
    if (kind == null || !mounted) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: '강화 되돌리기',
      message: '${kind.label}을(를) 진행할까요?\n재화 50이 소모됩니다.',
      cancelLabel: '취소',
      confirmLabel: '되돌리기',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      final updated = await _service.revertEnhancement(
        userPitchCardId: card.userPitchCardId,
        kind: kind,
      );
      if (!mounted) return;
      _applyUpdatedCard(updated);
      _showMessage('강화를 되돌렸습니다.');
    } on InventoryException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      _showMessage('강화 되돌리기에 실패했습니다.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Text(
                '보유 구종',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (_cards != null)
                Text(
                  '${_cards!.length}장',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              _body(),
              if (_selected != null) _detailOverlay(_selected!),
              if (_actionBusy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(color: _kGold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading && _cards == null) {
      return const Center(
        child: CircularProgressIndicator(color: _kGold),
      );
    }

    if (_error != null && _cards == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFF8A65),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(foregroundColor: _kGold),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final cards = _cards ?? const <UserPitchCard>[];
    if (cards.isEmpty) {
      return RefreshIndicator(
        color: _kGold,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(
                child: Text(
                  '보유한 구종이 없습니다',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kGold,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: kPitchCardAspectRatio,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return GestureDetector(
            onTap: () => _selectCard(card),
            child: _InventoryPitchCard(card: card),
          );
        },
      ),
    );
  }

  Widget _detailOverlay(UserPitchCard card) {
    final canRevert = card.isEnhanced;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = screenW * 0.52;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clearSelection,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GestureDetector(
                    onTap: () {},
                    child: SizedBox(
                      width: cardW,
                      child: _InventoryPitchCard(
                        card: card,
                        enlarged: true,
                        selected: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: _EnhanceButton(
                        count: _enhancementCount,
                        onTap: () => _onEnhanceTap(card),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RevertButton(
                      enabled: canRevert,
                      onTap: canRevert ? () => _onRevertTap(card) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnhancePickerSheet extends StatelessWidget {
  final List<EnhancementCard> items;

  const _EnhancePickerSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '강화 카드 선택',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '적용할 강화 카드를 고르세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, item),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.effect.label,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'x${item.quantity}',
                            style: const TextStyle(
                              color: _kGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RevertPickerSheet extends StatelessWidget {
  final List<EnhanceRevertKind> kinds;

  const _RevertPickerSheet({required this.kinds});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '되돌릴 강화 선택',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '재화 50이 소모됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            ...kinds.map((kind) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, kind),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        kind.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EnhanceButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _EnhanceButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [_kGold, _kGoldDark],
          ),
          boxShadow: [
            BoxShadow(
              color: _kGold.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '강화',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevertButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _RevertButton({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? _kRevertBg : _kRevertDisabled,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.08),
            ),
          ),
          child: Icon(
            Icons.undo_rounded,
            color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.4),
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _InventoryPitchCard extends StatelessWidget {
  final UserPitchCard card;
  final bool enlarged;
  final bool selected;

  const _InventoryPitchCard({
    required this.card,
    this.enlarged = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameSize = enlarged ? 24.0 : 17.6;
    final infoSize = enlarged ? 15.0 : 11.0;
    final radius = enlarged ? 14.0 : 10.0;

    return AspectRatio(
      aspectRatio: kPitchCardAspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12122A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected
                ? _kGold
                : Colors.white.withValues(alpha: 0.16),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? _kGold.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: selected ? 18 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: enlarged ? 4 : 3,
                decoration: BoxDecoration(
                  color: card.timingColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius - 1),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                enlarged ? 12 : 7,
                enlarged ? 14 : 10,
                enlarged ? 12 : 7,
                enlarged ? 12 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: enlarged ? 10 : 6,
                    ),
                    child: Text(
                      card.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: nameSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _infoRow(
                    label: '변화방향',
                    value: card.directionArrow,
                    valueColor: card.timingColor,
                    fontSize: infoSize,
                  ),
                  SizedBox(height: enlarged ? 6 : 4),
                  _infoRow(
                    label: '변화량',
                    value: '${card.effectiveChangeAmount}',
                    highlight: card.changeAmountEnhanced,
                    fontSize: infoSize,
                  ),
                  SizedBox(height: enlarged ? 6 : 4),
                  _infoRow(
                    label: '타이밍',
                    value: card.timingLabel,
                    valueColor: card.timingColor,
                    highlight: card.timingEnhanced,
                    fontSize: infoSize,
                  ),
                ],
              ),
            ),
            if (card.isEnhanced)
              Positioned(
                top: enlarged ? 10 : 6,
                right: enlarged ? 8 : 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kPanelBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _kGold.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    '강화',
                    style: TextStyle(
                      color: _kGold,
                      fontSize: enlarged ? 10 : 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    required double fontSize,
    Color? valueColor,
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: highlight ? _kGold : (valueColor ?? Colors.white),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
