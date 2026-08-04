import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/league_enums.dart';
import '../models/team.dart';
import '../services/match_service.dart';
import '../services/team_service.dart';
import '../services/token_storage.dart';

const _kGold = Color(0xFFFFD700);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);
const _kOliveMid = Color(0xFF3D5020);
const _kBrownBase = Color(0xFF5C3010);

enum _TeamView { home, records, roster, applications }

/// 가입 방식 (UI 껍데기 — API 연동 전 로컬 상태)
enum _JoinPolicy { open, apply }

class _JoinApplication {
  final int userId;
  final String nickname;
  final bool online;
  final DateTime appliedAt;

  const _JoinApplication({
    required this.userId,
    required this.nickname,
    required this.online,
    required this.appliedAt,
  });
}

/// 소속 팀 홈 — 로고/이름 + 전적/금고/로스터 + 멤버 리스트
class TeamHomePanel extends StatefulWidget {
  final Team team;
  final VoidCallback? onLeftTeam;
  final ValueChanged<Team>? onTeamUpdated;

  const TeamHomePanel({
    super.key,
    required this.team,
    this.onLeftTeam,
    this.onTeamUpdated,
  });

  @override
  State<TeamHomePanel> createState() => _TeamHomePanelState();
}

class _TeamHomePanelState extends State<TeamHomePanel> {
  final _teamService = TeamService();
  List<TeamMember> _members = const [];
  bool _loading = true;
  _TeamView _view = _TeamView.home;
  int? _myUserId;
  Timer? _heartbeatTimer;
  Timer? _membersPollTimer;

  // records
  String? _recordTier; // null = 전체
  List<TeamRecordItem> _records = const [];
  bool _recordsLoading = false;

  // roster
  LeagueFormat _rosterFormat = LeagueFormat.compact;
  int? _pitcherUserId;
  List<int?> _batterSlots = List<int?>.filled(3, null);
  bool _rosterLoading = false;
  bool _rosterSaving = false;

  // applications (shell)
  _JoinPolicy _joinPolicy = _JoinPolicy.apply;
  final List<_JoinApplication> _applications = [
    _JoinApplication(
      userId: 9001,
      nickname: '신청자A',
      online: true,
      appliedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    _JoinApplication(
      userId: 9002,
      nickname: '신청자B',
      online: false,
      appliedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  Team get _team => widget.team;
  bool get _isLeader =>
      _myUserId != null && _myUserId == _team.leaderUserId;

  int get _batterCount =>
      _rosterFormat == LeagueFormat.compact ? 3 : 9;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant TeamHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team.teamId != widget.team.teamId) {
      _view = _TeamView.home;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _membersPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await TokenStorage().getAccessToken();
    if (token != null) {
      _myUserId = int.tryParse(MatchService.extractUserIdFromJwt(token) ?? '');
    }
    await _loadMembers();
    _startPresenceTimers();
  }

  void _startPresenceTimers() {
    _heartbeatTimer?.cancel();
    _membersPollTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _teamService.heartbeat(_team.teamId);
    });
    _membersPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_view == _TeamView.home) _loadMembers(silent: true);
    });
    _teamService.heartbeat(_team.teamId);
  }

  Future<void> _loadMembers({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final members = await _teamService.getMembers(_team.teamId);
      members.sort((a, b) {
        if (a.isLeader == b.isLeader) return 0;
        return a.isLeader ? -1 : 1;
      });
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _members = const [];
          _loading = false;
        }
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF3A1A05)),
    );
  }

  Future<void> _leave() async {
    final ok = await _confirm(
      title: '팀 탈퇴',
      message: '정말 이 팀에서 탈퇴할까요?',
      confirmLabel: '탈퇴',
    );
    if (ok != true) return;

    try {
      await _teamService.leaveTeam(_team.teamId);
      widget.onLeftTeam?.call();
    } on TeamException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('팀 탈퇴에 실패했습니다.');
    }
  }

  Future<void> _deleteTeam() async {
    final ok = await _confirm(
      title: '팀 삭제',
      message: '팀을 삭제하면 복구할 수 없습니다.\n정말 삭제할까요?',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (ok != true) return;

    try {
      await _teamService.deleteTeam(_team.teamId);
      widget.onLeftTeam?.call();
    } on TeamException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('팀 삭제에 실패했습니다.');
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A3518),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? const Color(0xFFE85A5A) : _kGold,
            ),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? Colors.white : const Color(0xFF2A1F05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemberDetail(TeamMember member) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MemberDetailDialog(
        member: member,
        canManage: _isLeader && member.userId != _myUserId,
        onKick: () async {
          Navigator.pop(ctx);
          await _kickMember(member);
        },
        onChangeRole: () async {
          Navigator.pop(ctx);
          await _changeMemberRole(member);
        },
      ),
    );
  }

  Future<void> _kickMember(TeamMember member) async {
    final ok = await _confirm(
      title: '강제 탈퇴',
      message: '${member.nickname} 님을 팀에서 내보낼까요?',
      confirmLabel: '강제 탈퇴',
      destructive: true,
    );
    if (ok != true) return;

    try {
      await _teamService.kickMember(_team.teamId, member.userId);
      if (!mounted) return;
      _toast('${member.nickname} 님을 내보냈습니다.');
      await _loadMembers();
    } on TeamException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('강제 탈퇴에 실패했습니다.');
    }
  }

  Future<void> _changeMemberRole(TeamMember member) async {
    if (member.isLeader) {
      _toast('리더 강등은 다른 멤버에게 리더를 위임하세요.');
      return;
    }

    final ok = await _confirm(
      title: '리더 위임',
      message: '${member.nickname} 님에게 리더 권한을 위임할까요?\n위임 후 본인은 멤버가 됩니다.',
      confirmLabel: '위임',
    );
    if (ok != true) return;

    try {
      await _teamService.updateMemberRole(
        teamId: _team.teamId,
        userId: member.userId,
        role: 'LEADER',
      );
      if (!mounted) return;
      _toast('${member.nickname} 님에게 리더를 위임했습니다.');
      widget.onTeamUpdated?.call(
        Team(
          teamId: _team.teamId,
          name: _team.name,
          logoUrl: _team.logoUrl,
          leaderUserId: member.userId,
          treasury: _team.treasury,
          currentLeagueId: _team.currentLeagueId,
        ),
      );
      await _loadMembers();
    } on TeamException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('계급 변경에 실패했습니다.');
    }
  }

  Future<void> _openRecords() async {
    setState(() {
      _view = _TeamView.records;
      _recordTier = null;
    });
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _recordsLoading = true);
    try {
      final records = await _teamService.getRecords(
        _team.teamId,
        tier: _recordTier,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _recordsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = const [];
        _recordsLoading = false;
      });
      _toast('전적 조회에 실패했습니다.');
    }
  }

  TeamRecordItem? _recordForFormat(String format) {
    final list = _records
        .where((r) => r.format.toUpperCase() == format)
        .toList();
    if (list.isEmpty) return null;
    if (_recordTier != null) {
      final matched = list.where((r) => r.tier == _recordTier).toList();
      if (matched.isEmpty) return null;
      matched.sort((a, b) => b.rating.compareTo(a.rating));
      return matched.first;
    }
    // 전체: 포맷별 합산
    return TeamRecordItem(
      leagueId: 0,
      format: format,
      tier: '',
      wins: list.fold(0, (s, r) => s + r.wins),
      losses: list.fold(0, (s, r) => s + r.losses),
      runDiff: list.fold(0, (s, r) => s + r.runDiff),
      rating: list.isEmpty
          ? 0
          : (list.fold(0, (s, r) => s + r.rating) / list.length).round(),
    );
  }

  Future<void> _openRoster() async {
    setState(() => _view = _TeamView.roster);
    await _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _rosterLoading = true;
      _batterSlots = List<int?>.filled(_batterCount, null);
      _pitcherUserId = null;
    });
    try {
      final lineup = await _teamService.getLineup(
        _team.teamId,
        _rosterFormat.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _pitcherUserId = lineup?.startingPitcherUserId;
        final ids = lineup?.userIds ?? const <int>[];
        _batterSlots = List<int?>.generate(
          _batterCount,
          (i) => i < ids.length ? ids[i] : null,
        );
        _rosterLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rosterLoading = false);
    }
  }

  Future<void> _saveRoster() async {
    if (!_isLeader) {
      _toast('로스터 저장은 리더만 가능합니다.');
      return;
    }
    if (_pitcherUserId == null || _batterSlots.any((e) => e == null)) {
      _toast('투수와 타순을 모두 지정해주세요.');
      return;
    }
    setState(() => _rosterSaving = true);
    try {
      await _teamService.upsertLineup(
        teamId: _team.teamId,
        format: _rosterFormat.apiValue,
        userIds: _batterSlots.cast<int>(),
        startingPitcherUserId: _pitcherUserId!,
      );
      if (!mounted) return;
      _toast('로스터를 저장했습니다.');
    } on TeamException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('로스터 저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _rosterSaving = false);
    }
  }

  Future<void> _showTreasuryDialog() async {
    var treasury = _team.treasury;
    try {
      final t = await _teamService.getTreasury(_team.teamId);
      treasury = t.treasury;
    } catch (_) {}

    if (!mounted) return;
    final amountCtrl = TextEditingController();
    var donating = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A3518),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _kGold.withValues(alpha: 0.4)),
              ),
              title: const Text(
                '팀 금고',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: _kGold),
                      const SizedBox(width: 8),
                      Text(
                        _formatNumber(treasury),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '현재 팀 잔고',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '기부 금액',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A220E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kPanelBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kPanelBorder),
                      ),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    '닫기',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                  ),
                ),
                FilledButton(
                  onPressed: donating
                      ? null
                      : () async {
                          final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amount <= 0) {
                            _toast('기부 금액을 입력해주세요.');
                            return;
                          }
                          setLocal(() => donating = true);
                          try {
                            final result =
                                await _teamService.donate(_team.teamId, amount);
                            treasury = result.treasury;
                            widget.onTeamUpdated?.call(
                              Team(
                                teamId: _team.teamId,
                                name: _team.name,
                                logoUrl: _team.logoUrl,
                                leaderUserId: _team.leaderUserId,
                                treasury: result.treasury,
                                currentLeagueId: _team.currentLeagueId,
                              ),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _toast('기부가 완료되었습니다.');
                          } on TeamException catch (e) {
                            setLocal(() => donating = false);
                            _toast(e.message);
                          } catch (_) {
                            setLocal(() => donating = false);
                            _toast('기부에 실패했습니다.');
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: const Color(0xFF2A1F05),
                  ),
                  child: donating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '기부하기',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
    amountCtrl.dispose();
  }

  Future<void> _pickMember({
    required String title,
    required ValueChanged<int> onPicked,
    Set<int> exclude = const {},
  }) async {
    final candidates = _members
        .where((m) => !exclude.contains(m.userId))
        .toList();
    if (candidates.isEmpty) {
      _toast('선택할 수 있는 팀원이 없습니다.');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1E2810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final m = candidates[i];
                  return ListTile(
                    leading: Icon(
                      m.online ? Icons.circle : Icons.circle_outlined,
                      size: 12,
                      color: m.online
                          ? const Color(0xFF5EE85E)
                          : Colors.white38,
                    ),
                    title: Text(m.nickname,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(m.isLeader ? '리더' : '멤버',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45))),
                    onTap: () => Navigator.pop(ctx, m.userId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  String _nicknameOf(int? userId) {
    if (userId == null) return '미지정';
    for (final m in _members) {
      if (m.userId == userId) return m.nickname;
    }
    return '유저 $userId';
  }

  String _formatNumber(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  String _tierLabel(String tier) =>
      LeagueTier.fromApi(tier)?.displayName ?? tier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kPanelBorder, width: 2),
          color: _kPanelBg.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
              Expanded(
                child: switch (_view) {
                  _TeamView.home => _buildHome(),
                  _TeamView.records => _buildRecords(),
                  _TeamView.roster => _buildRoster(),
                  _TeamView.applications => _buildApplications(),
                },
              ),
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
      ),
    );
  }

  Widget _buildHome() {
    final onlineCount = _members.where((m) => m.online).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              _logo(_team.logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _team.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isLeader)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: _deleteTeam,
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _loading
                          ? '멤버 불러오는 중...'
                          : '접속 중 $onlineCount명 · ${_members.length}/$kTeamMaxMembers',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: _ActionChip(
                  icon: Icons.bar_chart_rounded,
                  label: '전적',
                  onTap: _openRecords,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: '금고',
                  onTap: _showTreasuryDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionChip(
                  icon: Icons.groups_rounded,
                  label: '로스터',
                  onTap: _openRoster,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionChip(
                  icon: Icons.mark_email_unread_rounded,
                  label: '신청함',
                  onTap: () => setState(() => _view = _TeamView.applications),
                ),
              ),
            ],
          ),
        ),
        Divider(color: _kPanelBorder.withValues(alpha: 0.5), height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '소속 플레이어',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kGold))
              : _members.isEmpty
                  ? Center(
                      child: Text(
                        '멤버가 없습니다',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) => _memberRow(_members[i]),
                    ),
        ),
      ],
    );
  }

  Widget _memberRow(TeamMember m) {
    final isMe = _myUserId != null && m.userId == _myUserId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMemberDetail(m),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: m.online
                ? _kOliveMid.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: m.online
                  ? _kPanelBorder.withValues(alpha: 0.55)
                  : _kPanelBorder.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: m.online ? const Color(0xFF5EE85E) : Colors.white24,
                  boxShadow: m.online
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF5EE85E).withValues(alpha: 0.55),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              if (m.isLeader) ...[
                Icon(Icons.star_rounded,
                    size: 16, color: _kGold.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.nickname,
                        style: TextStyle(
                          color: m.online ? Colors.white : Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onTap: _leave,
                          child: Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                m.isLeader ? '리더' : '멤버',
                style: TextStyle(
                  color: m.isLeader
                      ? _kGold.withValues(alpha: 0.85)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecords() {
    final full = _recordForFormat('FULL');
    final compact = _recordForFormat('COMPACT');
    final tierLabel =
        _recordTier == null ? '전체' : _tierLabel(_recordTier!);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '팀 전적',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _view = _TeamView.home),
                tooltip: '뒤로',
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: _DropdownBox<String?>(
            value: _recordTier,
            items: [
              (null, '전체'),
              ...LeagueTier.highToLow.map((t) => (t.apiValue, t.displayName)),
            ],
            onChanged: (v) {
              setState(() => _recordTier = v);
              _loadRecords();
            },
          ),
        ),
        Expanded(
          child: _recordsLoading
              ? const Center(child: CircularProgressIndicator(color: _kGold))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    _LeagueStatCard(
                      title: '풀 리그',
                      tierLabel: tierLabel,
                      record: full,
                    ),
                    const SizedBox(height: 12),
                    _LeagueStatCard(
                      title: '컴팩트 리그',
                      tierLabel: tierLabel,
                      record: compact,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRoster() {
    final used = <int>{
      if (_pitcherUserId != null) _pitcherUserId!,
      ..._batterSlots.whereType<int>(),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '출전 로스터',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _view = _TeamView.home),
                tooltip: '뒤로',
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _DropdownBox<LeagueFormat>(
            value: _rosterFormat,
            items: const [
              (LeagueFormat.compact, '컴팩트'),
              (LeagueFormat.full, '풀'),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _rosterFormat = v);
              _loadRoster();
            },
          ),
        ),
        Expanded(
          child: _rosterLoading
              ? const Center(child: CircularProgressIndicator(color: _kGold))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    _RosterSlot(
                      label: 'P',
                      subtitle: '투수',
                      nickname: _nicknameOf(_pitcherUserId),
                      onTap: !_isLeader
                          ? null
                          : () => _pickMember(
                                title: '선발 투수 선택',
                                exclude: _rosterFormat == LeagueFormat.compact
                                    ? {..._batterSlots.whereType<int>()}
                                    : const {},
                                onPicked: (id) =>
                                    setState(() => _pitcherUserId = id),
                              ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(_batterCount, (i) {
                      final exclude = {
                        ...used.where((id) => id != _batterSlots[i]),
                        if (_rosterFormat == LeagueFormat.compact &&
                            _pitcherUserId != null)
                          _pitcherUserId!,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _RosterSlot(
                          label: '${i + 1}',
                          subtitle: '타자',
                          nickname: _nicknameOf(_batterSlots[i]),
                          onTap: !_isLeader
                              ? null
                              : () => _pickMember(
                                    title: '${i + 1}번 타자 선택',
                                    exclude: exclude,
                                    onPicked: (id) => setState(
                                      () => _batterSlots[i] = id,
                                    ),
                                  ),
                        ),
                      );
                    }),
                    if (_isLeader) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: _rosterSaving ? null : _saveRoster,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kGold,
                            foregroundColor: const Color(0xFF2A1F05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _rosterSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2A1F05),
                                  ),
                                )
                              : const Text(
                                  '로스터 저장',
                                  style: TextStyle(fontWeight: FontWeight.w900),
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

  Widget _buildApplications() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '가입 신청함',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _view = _TeamView.home),
                tooltip: '뒤로',
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        if (_isLeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '가입 방식',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _JoinPolicyChip(
                        label: '즉시 가입',
                        selected: _joinPolicy == _JoinPolicy.open,
                        onTap: () =>
                            setState(() => _joinPolicy = _JoinPolicy.open),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _JoinPolicyChip(
                        label: '가입 신청',
                        selected: _joinPolicy == _JoinPolicy.apply,
                        onTap: () =>
                            setState(() => _joinPolicy = _JoinPolicy.apply),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _joinPolicy == _JoinPolicy.open
                      ? '누구나 바로 팀에 가입할 수 있습니다. (UI 미리보기)'
                      : '가입 신청 후 리더 승인 시 입단합니다. (UI 미리보기)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Text(
              '가입 신청 처리는 리더만 할 수 있습니다.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: !_isLeader
              ? Center(
                  child: Text(
                    '확인할 권한이 없습니다',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                )
              : _applications.isEmpty
                  ? Center(
                      child: Text(
                        '대기 중인 가입 신청이 없습니다',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _applications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final app = _applications[i];
                        return _ApplicationRow(
                          application: app,
                          onTap: () => _showApplicationDetail(app),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _showApplicationDetail(_JoinApplication app) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _ApplicationDetailDialog(application: app),
    );
    if (result == null || !mounted) return;

    setState(() {
      _applications.removeWhere((a) => a.userId == app.userId);
    });
    _toast(
      result == 'approve'
          ? '${app.nickname} 님의 승인했습니다. (미리보기)'
          : '${app.nickname} 님 신청을 거절했습니다. (미리보기)',
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
          colors: [Color(0xFF4A6A28), _kBrownBase],
        ),
        border: Border.all(color: _kGold, width: 2),
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(logoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasLogo
          ? null
          : const Icon(Icons.shield_rounded, color: _kGold, size: 28),
    );
  }
}

class _JoinPolicyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _JoinPolicyChip({
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
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _kOliveMid.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _kGold.withValues(alpha: 0.7) : _kPanelBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _kGold : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  final _JoinApplication application;
  final VoidCallback onTap;

  const _ApplicationRow({
    required this.application,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _kOliveMid.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kPanelBorder.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: application.online
                      ? const Color(0xFF5EE85E)
                      : Colors.white24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.nickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '가입 신청 · ${_relativeTime(application.appliedAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class _ApplicationDetailDialog extends StatelessWidget {
  final _JoinApplication application;

  const _ApplicationDetailDialog({required this.application});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A3518),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _kPanelBorder.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    application.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  application.online ? '온라인' : '오프라인',
                  style: TextStyle(
                    color: application.online
                        ? const Color(0xFF5EE85E)
                        : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '가입 신청',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const _LeagueStatCard(title: '쇼다운', record: null),
            const SizedBox(height: 10),
            const _LeagueStatCard(title: '컴팩트 리그', record: null),
            const SizedBox(height: 10),
            const _LeagueStatCard(title: '풀 리그', record: null),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85A5A),
                      side: const BorderSide(color: Color(0xFFE85A5A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '거절',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, 'approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7EC850),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '승인',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberDetailDialog extends StatefulWidget {
  final TeamMember member;
  final bool canManage;
  final VoidCallback onKick;
  final VoidCallback onChangeRole;

  const _MemberDetailDialog({
    required this.member,
    required this.canManage,
    required this.onKick,
    required this.onChangeRole,
  });

  @override
  State<_MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends State<_MemberDetailDialog> {
  String? _compactTier; // null = 전체
  String? _fullTier;

  static final _tierItems = <(String?, String)>[
    (null, '전체'),
    ...LeagueTier.highToLow.map((t) => (t.apiValue, t.displayName)),
  ];

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    return Dialog(
      backgroundColor: const Color(0xFF2A3518),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _kPanelBorder.withValues(alpha: 0.7)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      member.nickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: member.online
                          ? const Color(0xFF5EE85E).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      member.online ? '온라인' : '오프라인',
                      style: TextStyle(
                        color: member.online
                            ? const Color(0xFF5EE85E)
                            : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                member.isLeader ? '리더' : '멤버',
                style: TextStyle(
                  color: member.isLeader
                      ? _kGold.withValues(alpha: 0.85)
                      : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const _LeagueStatCard(
                        title: '쇼다운',
                        record: null,
                      ),
                      const SizedBox(height: 10),
                      _LeagueStatCard(
                        title: '컴팩트 리그',
                        record: null,
                        headerTrailing: _TierDropdown(
                          value: _compactTier,
                          items: _tierItems,
                          onChanged: (v) => setState(() => _compactTier = v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _LeagueStatCard(
                        title: '풀 리그',
                        record: null,
                        headerTrailing: _TierDropdown(
                          value: _fullTier,
                          items: _tierItems,
                          onChanged: (v) => setState(() => _fullTier = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.canManage) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onKick,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE85A5A),
                          side: const BorderSide(color: Color(0xFFE85A5A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '강제 탈퇴',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onChangeRole,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: const Color(0xFF2A1F05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '계급 변경',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueStatCard extends StatelessWidget {
  final String title;
  final String tierLabel;
  final TeamRecordItem? record;
  final Widget? headerTrailing;

  const _LeagueStatCard({
    required this.title,
    this.tierLabel = '',
    required this.record,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final wins = record?.wins ?? 0;
    final losses = record?.losses ?? 0;
    final runDiff = record?.runDiff ?? 0;
    final rating = record?.rating ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPanelBorder.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              14,
              headerTrailing != null ? 6 : 10,
              headerTrailing != null ? 8 : 14,
              headerTrailing != null ? 6 : 10,
            ),
            color: _kOliveMid.withValues(alpha: 0.55),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (headerTrailing != null)
                  headerTrailing!
                else if (tierLabel.isNotEmpty)
                  Text(
                    tierLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            color: Colors.black.withValues(alpha: 0.22),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(child: _StatHeader('승')),
                    Expanded(child: _StatHeader('패')),
                    Expanded(child: _StatHeader('득실')),
                    Expanded(child: _StatHeader('레이팅')),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _StatValue('$wins')),
                    Expanded(child: _StatValue('$losses')),
                    Expanded(child: _StatValue('$runDiff')),
                    Expanded(child: _StatValue('$rating')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatHeader extends StatelessWidget {
  final String text;
  const _StatHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  final String text;
  const _StatValue(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _kOliveMid.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kPanelBorder.withValues(alpha: 0.7)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: _kGold),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownBox<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  const _DropdownBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A220E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPanelBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E2810),
          iconEnabledColor: _kGold,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item.$1,
                child: Text(item.$2),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 전적 카드 헤더용 작은 티어 드롭다운
class _TierDropdown extends StatelessWidget {
  final String? value;
  final List<(String?, String)> items;
  final ValueChanged<String?> onChanged;

  const _TierDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 120),
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A220E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPanelBorder.withValues(alpha: 0.7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF1E2810),
          iconEnabledColor: _kGold,
          iconSize: 16,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<String?>(
                value: item.$1,
                child: Text(item.$2),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RosterSlot extends StatelessWidget {
  final String label;
  final String subtitle;
  final String nickname;
  final VoidCallback? onTap;

  const _RosterSlot({
    required this.label,
    required this.subtitle,
    required this.nickname,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1A220E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kPanelBorder.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kOliveMid.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _kGold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '$subtitle ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        nickname,
                        style: TextStyle(
                          color: nickname == '미지정'
                              ? Colors.white38
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.edit_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
