import 'package:flutter/material.dart';

import '../models/card_info.dart';
import '../models/store_models.dart';
import '../screens/cards_screen.dart' show kPitchCardAspectRatio;
import '../services/store_service.dart';
import '../utils/api_error_ui.dart';
import '../widgets/app_dialog.dart';

const _kGold = Color(0xFFFFD700);
const _kGoldDark = Color(0xFFD4821A);
const _kPanel = Color(0xFF242F12);
const _kCardBg = Color(0xFF12122A);

/// 밸런스용 임시 골드 패키지 (서버 IAP 연동 전 UI).
/// 구 다이아 패키지 환산: 10골드 = $1 (구 1다이아 = $1).
class _GoldPack {
  final int gold;
  final String priceLabel;
  const _GoldPack(this.gold, this.priceLabel);
}

const _kGoldPacks = [
  // 구 다이아 10 / 50 / 100 → 골드 ×10, 달러 가격 유지
  _GoldPack(100, r'$1.00'),
  _GoldPack(500, r'$4.50'),
  _GoldPack(1000, r'$7.50'),
];

/// 홈 하단 「상점」탭.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  final _service = StoreService();
  late final TabController _tabs;

  StoreCatalog? _catalog;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  int get _gold => _catalog?.currency ?? 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _service.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } on StoreException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '상점 목록을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _purchasePitch(StorePitchOffer offer) async {
    if (_busy || !offer.purchasable) return;

    final ok = await showAppConfirmDialog(
      context,
      title: '구종 구매',
      message: '${offer.displayName}을(를) 골드 ${offer.price}에 구매할까요?',
      cancelLabel: '취소',
      confirmLabel: '구매',
    );
    if (ok != true || !mounted) return;

    if (_gold < offer.price) {
      await showAppAlertDialog(
        context,
        message: '골드가 부족합니다.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _service.purchasePitch(offer.cardId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showAppAlertDialog(
        context,
        message:
            '${CardInfo.shortPitchName(result.purchasedCard.name)}을(를) 구매했습니다.\n'
            '남은 골드: ${result.remainingCurrency}',
      );
    } on StoreException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.isInsufficientCurrency) {
        await showAppAlertDialog(
          context,
          message: '골드가 부족합니다.',
        );
        return;
      }
      await showErrorDialog(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showErrorDialog(context, '구종 구매에 실패했습니다.');
    }
  }

  Future<void> _purchaseEnhancement(StoreEnhancementOffer offer) async {
    if (_busy) return;

    final ok = await showAppConfirmDialog(
      context,
      title: '강화 카드 구매',
      message: '${offer.name} 1장을 골드 ${offer.price}에 구매할까요?',
      cancelLabel: '취소',
      confirmLabel: '구매',
    );
    if (ok != true || !mounted) return;

    if (_gold < offer.price) {
      await showAppAlertDialog(
        context,
        message: '골드가 부족합니다.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _service.purchaseEnhancement(offer.cardId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showAppAlertDialog(
        context,
        message:
            '${result.purchasedCard.name}을(를) 구매했습니다.\n'
            '보유: ${result.purchasedCard.quantity}장 · '
            '남은 골드: ${result.remainingCurrency}',
      );
    } on StoreException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.isInsufficientCurrency) {
        await showAppAlertDialog(
          context,
          message: '골드가 부족합니다.',
        );
        return;
      }
      await showErrorDialog(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showErrorDialog(context, '강화 카드 구매에 실패했습니다.');
    }
  }

  Future<void> _buyGold(_GoldPack pack) async {
    if (_busy) return;
    final ok = await showAppConfirmDialog(
      context,
      title: '골드 충전',
      message: '골드 ${pack.gold}개 (${pack.priceLabel})를 결제할까요?',
      cancelLabel: '취소',
      confirmLabel: '결제',
    );
    if (ok != true || !mounted) return;

    // TODO: Play Billing + POST /store/currency/google/confirm
    await showAppAlertDialog(
      context,
      title: '준비 중',
      message: '인앱 결제는 곧 지원될 예정입니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            _tabBar(),
            Expanded(child: _body()),
          ],
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: _kGold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Text(
            '상점',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _balanceChip(
            icon: Icons.monetization_on_rounded,
            color: _kGold,
            value: _catalog == null ? '—' : _format(_gold),
          ),
        ],
      ),
    );
  }

  Widget _balanceChip({
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kPanel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: TabBar(
          controller: _tabs,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFFF5C542), Color(0xFFD4821A)],
            ),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: '구종'),
            Tab(text: '강화'),
            Tab(text: '재화'),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _catalog == null) {
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }

    if (_error != null && _catalog == null) {
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

    final catalog = _catalog!;
    return TabBarView(
      controller: _tabs,
      children: [
        _offerGridTab(
          emptyText: '판매 중인 구종이 없습니다',
          itemCount: catalog.pitchOffers.length,
          itemBuilder: (i) {
            final offer = catalog.pitchOffers[i];
            return _ShopOfferCell(
              card: _StorePitchCard(offer: offer),
              priceLabel: '${offer.price}',
              priceIcon: Icons.monetization_on_rounded,
              priceColor: _kGold,
              canBuy: offer.purchasable,
              buyLabel: offer.purchasable
                  ? '구매'
                  : (offer.hasBaseCopy ? '보유 중' : '구매 불가'),
              onBuy: offer.purchasable ? () => _purchasePitch(offer) : null,
            );
          },
        ),
        _offerGridTab(
          emptyText: '판매 중인 강화 카드가 없습니다',
          itemCount: catalog.enhancementOffers.length,
          itemBuilder: (i) {
            final offer = catalog.enhancementOffers[i];
            return _ShopOfferCell(
              card: _StoreEnhancementCard(offer: offer),
              priceLabel: '${offer.price}',
              priceIcon: Icons.monetization_on_rounded,
              priceColor: _kGold,
              canBuy: true,
              buyLabel: '구매',
              ownedQty: offer.ownedQty,
              onBuy: () => _purchaseEnhancement(offer),
            );
          },
        ),
        _currencyTab(),
      ],
    );
  }

  Widget _offerGridTab({
    required String emptyText,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return RefreshIndicator(
      color: _kGold,
      onRefresh: _load,
      child: itemCount == 0
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.25,
                  child: Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final cellW =
                    (constraints.maxWidth - 24 - 20) / 3; // pad + gaps
                final cardH = cellW / kPitchCardAspectRatio;
                const below = 8.0 + 18.0 + 6.0 + 36.0; // gaps + price + button
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: itemCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                    mainAxisExtent: cardH + below,
                  ),
                  itemBuilder: (context, i) => itemBuilder(i),
                );
              },
            ),
    );
  }

  Widget _currencyTab() {
    return RefreshIndicator(
      color: _kGold,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          _currencySectionTitle(
            icon: Icons.monetization_on_rounded,
            color: _kGold,
            title: '골드',
            subtitle: '결제로 충전',
          ),
          const SizedBox(height: 10),
          _packRow(
            itemCount: _kGoldPacks.length,
            itemBuilder: (i) {
              final pack = _kGoldPacks[i];
              return _ShopOfferCell(
                card: _CurrencyFaceCard(
                  amount: pack.gold,
                  label: '골드',
                  accent: _kGold,
                  icon: Icons.monetization_on_rounded,
                ),
                priceLabel: pack.priceLabel,
                priceIcon: null,
                priceColor: Colors.white70,
                canBuy: true,
                buyLabel: '구매',
                onBuy: () => _buyGold(pack),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _currencySectionTitle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _packRow({
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - 20) / 3;
        final cardH = cellW / kPitchCardAspectRatio;
        const below = 8.0 + 18.0 + 6.0 + 36.0;
        return SizedBox(
          height: cardH + below,
          child: Row(
            children: [
              for (var i = 0; i < itemCount; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: itemBuilder(i)),
              ],
            ],
          ),
        );
      },
    );
  }

  String _format(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// 카드 + 하단 가격 + 구매 버튼.
class _ShopOfferCell extends StatelessWidget {
  final Widget card;
  final String priceLabel;
  final IconData? priceIcon;
  final Color priceColor;
  final bool canBuy;
  final String buyLabel;
  final int? ownedQty;
  final VoidCallback? onBuy;

  const _ShopOfferCell({
    required this.card,
    required this.priceLabel,
    required this.priceIcon,
    required this.priceColor,
    required this.canBuy,
    required this.buyLabel,
    this.ownedQty,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: kPitchCardAspectRatio,
          child: card,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (priceIcon != null) ...[
              Icon(priceIcon, size: 13, color: priceColor),
              const SizedBox(width: 3),
            ],
            Text(
              priceLabel,
              style: TextStyle(
                color: priceColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: canBuy ? onBuy : null,
                  child: Opacity(
                    opacity: canBuy ? 1 : 0.45,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: canBuy
                            ? const LinearGradient(
                                colors: [_kGold, _kGoldDark],
                              )
                            : null,
                        color:
                            canBuy ? null : Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        buyLabel,
                        style: TextStyle(
                          color: canBuy ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (ownedQty != null) ...[
                const SizedBox(width: 6),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _kPanel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGold.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    'x$ownedQty',
                    style: const TextStyle(
                      color: _kGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StorePitchCard extends StatelessWidget {
  final StorePitchOffer offer;

  const _StorePitchCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final canBuy = offer.purchasable;
    final accent = offer.hasStats ? offer.timingColor : _kGold;
    return Opacity(
      opacity: canBuy ? 1 : 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: canBuy
                ? accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.14),
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
                  color: accent,
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
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      offer.displayName,
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
                    value: offer.hasStats ? offer.directionArrow : '—',
                    valueColor: accent,
                  ),
                  const SizedBox(height: 4),
                  _infoRow(
                    label: '변화량',
                    value: offer.hasStats ? '${offer.changeAmount}' : '—',
                  ),
                  const SizedBox(height: 4),
                  _infoRow(
                    label: '타이밍',
                    value: offer.hasStats ? offer.timingLabel : '—',
                    valueColor: accent,
                  ),
                ],
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
    Color? valueColor,
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
              color: valueColor ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreEnhancementCard extends StatelessWidget {
  final StoreEnhancementOffer offer;

  const _StoreEnhancementCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withValues(alpha: 0.45)),
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
              decoration: const BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.vertical(
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    offer.name,
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
                Text(
                  offer.effect.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyFaceCard extends StatelessWidget {
  final int amount;
  final String label;
  final Color accent;
  final IconData icon;

  const _CurrencyFaceCard({
    required this.amount,
    required this.label,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
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
                color: accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
            child: Column(
              children: [
                Icon(icon, color: accent, size: 28),
                const Spacer(),
                Text(
                  '$amount',
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
