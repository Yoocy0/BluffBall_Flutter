import 'package:flutter/material.dart';

import '../models/league_enums.dart';
import '../models/team.dart';
import '../services/team_service.dart';

const _kGold = Color(0xFFFFD700);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);
const _kOliveMid = Color(0xFF3D5020);

/// true = 가입 성공
Future<bool?> showTeamDetailSheet(BuildContext context, Team team) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'team-detail',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => TeamDetailSheet(team: team),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class TeamDetailSheet extends StatefulWidget {
  final Team team;

  const TeamDetailSheet({super.key, required this.team});

  @override
  State<TeamDetailSheet> createState() => _TeamDetailSheetState();
}

class _TeamDetailSheetState extends State<TeamDetailSheet> {
  final _teamService = TeamService();
  bool _loading = true;
  bool _joining = false;
  List<TeamMember> _members = const [];
  TeamRecordItem? _compact;
  TeamRecordItem? _full;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _teamService.getMembers(widget.team.teamId),
        _teamService.getRecords(widget.team.teamId),
      ]);
      final members = results[0] as List<TeamMember>;
      final records = results[1] as List<TeamRecordItem>;
      members.sort((a, b) {
        if (a.isLeader == b.isLeader) return 0;
        return a.isLeader ? -1 : 1;
      });
      if (!mounted) return;
      setState(() {
        _members = members;
        _compact = _pickRecord(records, 'COMPACT');
        _full = _pickRecord(records, 'FULL');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  TeamRecordItem? _pickRecord(List<TeamRecordItem> records, String format) {
    final list = records.where((r) => r.format.toUpperCase() == format).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.rating.compareTo(a.rating));
    return list.first;
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await _teamService.joinTeam(widget.team.teamId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TeamException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFF3A1A05)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팀 가입에 실패했습니다.'),
          backgroundColor: Color(0xFF3A1A05),
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  String _tierLabel(String? tier) {
    if (tier == null || tier.isEmpty) return '-';
    return LeagueTier.fromApi(tier)?.displayName ?? tier;
  }

  @override
  Widget build(BuildContext context) {
    final count = _members.length;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.72,
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF243018), Color(0xFF1A220E), Color(0xFF2A1A0A)],
                ),
                border: Border.all(color: _kGold.withValues(alpha: 0.45), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.team.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          tooltip: '닫기',
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        _logo(widget.team.logoUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '금고 ${widget.team.treasury}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          _loading
                              ? '-/$kTeamMaxMembers'
                              : '$count/$kTeamMaxMembers',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: _kGold),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _LeagueRecordBlock(
                            title: 'Compact League',
                            tierLabel: _tierLabel(_compact?.tier),
                            wins: _compact?.wins ?? 0,
                            losses: _compact?.losses ?? 0,
                          ),
                          const SizedBox(height: 8),
                          _LeagueRecordBlock(
                            title: 'Full League',
                            tierLabel: _tierLabel(_full?.tier),
                            wins: _full?.wins ?? 0,
                            losses: _full?.losses ?? 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '팀원',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final m = _members[i];
                          return Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _kPanelBg.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _kPanelBorder.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (m.isLeader) ...[
                                  Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: _kGold.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    m.nickname,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (m.isLeader)
                                  Text(
                                    '리더',
                                    style: TextStyle(
                                      color: _kGold.withValues(alpha: 0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: (_loading || _joining) ? null : _join,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7EC850),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF7EC850).withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _joining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '가입 신청',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(String? logoUrl) {
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOliveMid, Color(0xFF5C3010)],
        ),
        border: Border.all(color: _kGold, width: 1.5),
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(logoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasLogo
          ? null
          : const Icon(Icons.shield_rounded, color: _kGold, size: 26),
    );
  }
}

class _LeagueRecordBlock extends StatelessWidget {
  final String title;
  final String tierLabel;
  final int wins;
  final int losses;

  const _LeagueRecordBlock({
    required this.title,
    required this.tierLabel,
    required this.wins,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kOliveMid.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPanelBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title : $tierLabel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$wins W  $losses L',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
