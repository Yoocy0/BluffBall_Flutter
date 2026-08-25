import 'package:flutter/material.dart';

import '../models/user_pitch_card.dart';
import '../services/user_inventory_service.dart';

/// 실물 카드 비율 (가로 : 세로 = 5.6 : 8.7)
const double kPitchCardAspectRatio = 5.6 / 8.7;

const _kGold = Color(0xFFFFD700);
const _kPanelBg = Color(0xFF242F12);

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _service.fetchPitchCards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
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
        Expanded(child: _body()),
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
        itemBuilder: (context, index) => _InventoryPitchCard(card: cards[index]),
      ),
    );
  }
}

class _InventoryPitchCard extends StatelessWidget {
  final UserPitchCard card;

  const _InventoryPitchCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kPitchCardAspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12122A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
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
                height: 3,
                decoration: BoxDecoration(
                  color: card.timingColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 10, 7, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      card.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17.6,
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
                  ),
                  const SizedBox(height: 4),
                  _infoRow(
                    label: '변화량',
                    value: '${card.effectiveChangeAmount}',
                    highlight: card.changeAmountEnhanced,
                  ),
                  const SizedBox(height: 4),
                  _infoRow(
                    label: '타이밍',
                    value: card.timingLabel,
                    valueColor: card.timingColor,
                    highlight: card.timingEnhanced,
                  ),
                ],
              ),
            ),
            if (card.changeAmountEnhanced || card.timingEnhanced)
              Positioned(
                top: 6,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kPanelBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _kGold.withValues(alpha: 0.7)),
                  ),
                  child: const Text(
                    '강화',
                    style: TextStyle(
                      color: _kGold,
                      fontSize: 8,
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

  /// 하단 정보 — 이전 구종 이름 크기(11)로 표시.
  Widget _infoRow({
    required String label,
    required String value,
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
            fontSize: 11,
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
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
