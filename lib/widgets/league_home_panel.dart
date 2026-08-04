import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/league_enums.dart';
import '../models/team_league_progress.dart';
import '../services/league_service.dart';

const _kPanelCream = Color(0xFFFFFFCC);
const _kInk = Color(0xFF2A1F05);
const _kInkMuted = Color(0xFF5C4A28);
const _kGold = Color(0xFFB8860B);
const _kBorder = Color(0xFFD4C48A);
const _kOlive = Color(0xFF3D5020);

/// 리그 탭 — 카탈로그·참가·진행 상태 연동
class LeagueHomePanel extends StatefulWidget {
  final bool hasTeam;
  final String? teamName;
  final int? teamId;
  final bool isLeader;

  const LeagueHomePanel({
    super.key,
    required this.hasTeam,
    this.teamName,
    this.teamId,
    this.isLeader = false,
  });

  @override
  State<LeagueHomePanel> createState() => _LeagueHomePanelState();
}

class _LeagueHomePanelState extends State<LeagueHomePanel> {
  final _leagueService = LeagueService();

  LeagueFormat _selected = LeagueFormat.compact;
  final Map<LeagueFormat, TeamLeagueProgress?> _progress = {
    LeagueFormat.compact: null,
    LeagueFormat.full: null,
  };
  final Map<LeagueFormat, int> _entryFees = {
    LeagueFormat.compact: 1000,
    LeagueFormat.full: 1000,
  };

  bool _loading = false;
  bool _joining = false;

  TeamLeagueProgress? get _current => _progress[_selected];
  bool get _isJoined => _current != null;

  @override
  void initState() {
    super.initState();
    if (widget.hasTeam) _reload();
  }

  @override
  void didUpdateWidget(covariant LeagueHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasTeam != oldWidget.hasTeam ||
        widget.teamId != oldWidget.teamId) {
      if (widget.hasTeam) {
        _reload();
      } else {
        setState(() {
          _progress[LeagueFormat.compact] = null;
          _progress[LeagueFormat.full] = null;
        });
      }
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

  Future<void> _reload() async {
    if (!widget.hasTeam) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _leagueService.getMyProgress(),
        _leagueService.getLeagues(tier: LeagueTier.amateur4),
      ]);
      final progressList = results[0] as List<TeamLeagueProgress>;
      final catalog = results[1] as List<League>;

      final next = <LeagueFormat, TeamLeagueProgress?>{
        LeagueFormat.compact: null,
        LeagueFormat.full: null,
      };
      for (final p in progressList) {
        next[p.format] = p;
      }

      final fees = Map<LeagueFormat, int>.from(_entryFees);
      for (final league in catalog) {
        fees[league.format] = league.entryFee;
      }

      if (!mounted) return;
      setState(() {
        _progress
          ..[LeagueFormat.compact] = next[LeagueFormat.compact]
          ..[LeagueFormat.full] = next[LeagueFormat.full];
        _entryFees
          ..[LeagueFormat.compact] = fees[LeagueFormat.compact]!
          ..[LeagueFormat.full] = fees[LeagueFormat.full]!;
        _loading = false;
      });
    } on LeagueException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('리그 정보를 불러오지 못했습니다.');
    }
  }

  Future<void> _onFormatTap(LeagueFormat format) async {
    if (!widget.hasTeam) {
      _toast('팀에 소속된 뒤 리그에 참가할 수 있습니다.');
      return;
    }

    if (_progress[format] != null) {
      setState(() => _selected = format);
      return;
    }

    final joined = await _showJoinDialog(format);
    if (!mounted || joined != true) return;
    await _enter(format);
  }

  Future<bool?> _showJoinDialog(LeagueFormat format) {
    final label = format == LeagueFormat.compact ? '컴팩트' : '풀';
    final fee = _entryFees[format] ?? 1000;
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: _kPanelCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder, width: 1.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$label 리그에 참가하시겠습니까?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아마 4부부터 시작합니다.',
                    style: TextStyle(
                      color: _kInkMuted.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!widget.isLeader) ...[
                    const SizedBox(height: 8),
                    Text(
                      '리그 참가는 팀 리더만 할 수 있습니다.',
                      style: TextStyle(
                        color: Colors.red.shade700.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: widget.isLeader
                          ? () => Navigator.pop(ctx, true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kOlive,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _kOlive.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '참가($fee)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx, false),
                tooltip: '닫기',
                icon: Icon(
                  Icons.close_rounded,
                  color: _kInk.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enter(LeagueFormat format) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final progress = await _leagueService.enter(format);
      if (!mounted) return;
      setState(() {
        _progress[format] = progress;
        _selected = format;
        _joining = false;
      });
      _toast(
        '${format == LeagueFormat.compact ? '컴팩트' : '풀'} 리그에 참가했습니다.',
      );
    } on LeagueException catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _joining = false);
      _toast('리그 참가에 실패했습니다.');
    }
  }

  Future<void> _promote() async {
    final current = _current;
    final next = current?.nextTier;
    if (current == null || next == null || !current.promoteReady) return;
    if (!widget.isLeader) {
      _toast('승급은 팀 리더만 할 수 있습니다.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kPanelCream,
        title: const Text('리그 승급', style: TextStyle(color: _kInk)),
        content: Text(
          '${next.displayName}(으)로 승급할까요?',
          style: const TextStyle(color: _kInkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kOlive),
            child: const Text('승급'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final progress = await _leagueService.promote(
        format: _selected,
        targetTier: next,
      );
      if (!mounted) return;
      setState(() => _progress[_selected] = progress);
      _toast('${next.displayName}(으)로 승급했습니다.');
    } on LeagueException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('승급에 실패했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: _kPanelCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: _loading || _joining
                  ? const Center(
                      child: CircularProgressIndicator(color: _kOlive),
                    )
                  : _buildBody(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _FormatButton(
                      label: 'Compact',
                      selected: _selected == LeagueFormat.compact,
                      onTap: () => _onFormatTap(LeagueFormat.compact),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FormatButton(
                      label: 'Full',
                      selected: _selected == LeagueFormat.full,
                      onTap: () => _onFormatTap(LeagueFormat.full),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!widget.hasTeam) {
      return const _EmptyMessage(
        title: '팀 소속이 필요합니다',
        subtitle: '리그는 팀 단위로 참가할 수 있습니다.',
      );
    }

    if (!_isJoined) {
      return const _EmptyMessage(
        title: '리그에 참가해야 볼 수 있습니다',
        subtitle: '하단에서 Compact / Full을 눌러 참가하세요.',
      );
    }

    final progress = _current!;
    final myName =
        widget.teamName?.isNotEmpty == true ? widget.teamName! : '우리 팀';

    // 순위 API 없음 — 현재는 내 팀 진행 상태만 표시
    final rankings = [
      _RankRow(
        name: myName,
        rating: progress.rating,
        isMine: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  progress.currentTier.displayName,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kOlive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kOlive.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _selected == LeagueFormat.compact ? 'Compact' : 'Full',
                  style: const TextStyle(
                    color: _kOlive,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${progress.wins}승 ${progress.losses}패 · 득실 ${progress.runDiff}'
            ' · ${progress.ratingFloor}–${progress.ratingCeil}',
            style: TextStyle(
              color: _kInkMuted.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (progress.promoteReady && progress.nextTier != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: _promote,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: _kInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  '${progress.nextTier!.displayName} 승급 가능',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            '순위',
            style: TextStyle(
              color: _kInkMuted.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            itemCount: rankings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final row = rankings[i];
              return _RankTile(rank: i + 1, row: row);
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyMessage({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: _kInk.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kInkMuted.withValues(alpha: 0.85),
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

class _RankRow {
  final String name;
  final int rating;
  final bool isMine;

  const _RankRow({
    required this.name,
    required this.rating,
    this.isMine = false,
  });
}

class _RankTile extends StatelessWidget {
  final int rank;
  final _RankRow row;

  const _RankTile({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: row.isMine
            ? _kOlive.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: row.isMine
              ? _kOlive.withValues(alpha: 0.45)
              : _kBorder.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? _kGold : _kInkMuted,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.name,
              style: TextStyle(
                color: _kInk,
                fontSize: 14,
                fontWeight: row.isMine ? FontWeight.w900 : FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${row.rating}',
            style: const TextStyle(
              color: _kInk,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormatButton({
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kOlive : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kOlive : _kBorder,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _kInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
