import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/team.dart';
import '../services/team_service.dart';
import '../screens/team_detail_sheet.dart';

const _kGold = Color(0xFFFFD700);
const _kPanelBg = Color(0xFF242F12);
const _kPanelBorder = Color(0xFF5A6E30);
const _kOliveMid = Color(0xFF3D5020);
const _kBrownBase = Color(0xFF5C3010);

enum NoTeamPanelMode { idle, search, create }

/// 팀 미소속 시 상단 패널 — idle / 검색 / 창단을 같은 자리에서 전환
class NoTeamPanel extends StatefulWidget {
  final NoTeamPanelMode mode;
  final VoidCallback? onTeamReady;

  const NoTeamPanel({
    super.key,
    required this.mode,
    this.onTeamReady,
  });

  @override
  State<NoTeamPanel> createState() => _NoTeamPanelState();
}

class _NoTeamPanelState extends State<NoTeamPanel> {
  final _teamService = TeamService();
  final _searchCtrl = TextEditingController();
  final _teamNameCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  List<Team> _results = const [];
  bool _searched = false;
  bool _searching = false;
  bool _creating = false;
  /// true = 가입 신청제, false = 즉시 가입 (UI 껍데기)
  bool _joinByApplication = true;

  @override
  void didUpdateWidget(covariant NoTeamPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      setState(() {
        if (widget.mode != NoTeamPanelMode.search) {
          _searched = false;
          _searching = false;
          _results = const [];
          _searchCtrl.clear();
        }
        if (widget.mode != NoTeamPanelMode.create) {
          _creating = false;
          _joinByApplication = true;
          _teamNameCtrl.clear();
          _logoUrlCtrl.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _teamNameCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _searched = true;
    });
    try {
      final results = await _teamService.searchTeams(
        name: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _results = results);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _results = const []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFF3A1A05)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팀 검색에 실패했습니다.'),
          backgroundColor: Color(0xFF3A1A05),
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _onCreate() async {
    final name = _teamNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팀 이름을 입력해주세요.'),
          backgroundColor: Color(0xFF3A1A05),
        ),
      );
      return;
    }
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final logo = _logoUrlCtrl.text.trim();
      await _teamService.createTeam(
        name: name,
        logoUrl: logo.isEmpty ? null : logo,
      );
      if (!mounted) return;
      widget.onTeamReady?.call();
    } on TeamException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFF3A1A05)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팀 창단에 실패했습니다.'),
          backgroundColor: Color(0xFF3A1A05),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openDetail(Team team) async {
    final joined = await showTeamDetailSheet(context, team);
    if (joined == true) {
      widget.onTeamReady?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
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
      ),
    );
  }

  Widget _buildBody() {
    return switch (widget.mode) {
      NoTeamPanelMode.idle => _buildIdle(),
      NoTeamPanelMode.search => _buildSearch(),
      NoTeamPanelMode.create => _buildCreate(),
    };
  }

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_rounded,
              size: 56,
              color: _kGold.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 소속된 팀이 없습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '하단에서 팀을 검색하거나\n새로운 팀을 창단해보세요',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A220E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPanelBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: InputDecoration(
                      hintText: '팀 이름 검색',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _searching ? null : _runSearch,
                  tooltip: '검색',
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kGold,
                          ),
                        )
                      : Icon(
                          Icons.search_rounded,
                          color: _kGold.withValues(alpha: 0.9),
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: !_searched
              ? Center(
                  child: Text(
                    '팀 이름을 검색해보세요',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        '검색 결과가 없습니다',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final team = _results[i];
                        return _TeamResultTile(
                          team: team,
                          onTap: () => _openDetail(team),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCreate() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            children: [
              _fieldLabel('팀 이름'),
              const SizedBox(height: 6),
              _WhiteInput(
                controller: _teamNameCtrl,
                hint: '최대 16자 (한글 약 8자)',
                maxLength: 16,
              ),
              const SizedBox(height: 12),
              _fieldLabel('로고 URL (선택)'),
              const SizedBox(height: 6),
              _WhiteInput(
                controller: _logoUrlCtrl,
                hint: 'https://...',
              ),
              const SizedBox(height: 14),
              _fieldLabel('가입 방식'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _JoinModeChip(
                      label: '즉시 가입',
                      selected: !_joinByApplication,
                      onTap: () => setState(() => _joinByApplication = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _JoinModeChip(
                      label: '가입 신청',
                      selected: _joinByApplication,
                      onTap: () => setState(() => _joinByApplication = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _joinByApplication
                    ? '신청 후 리더 승인 시 입단합니다. (설정만 미리보기)'
                    : '누구나 바로 가입할 수 있습니다. (설정만 미리보기)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '팀 이름은 창단 후 변경할 수 없습니다.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _creating ? null : _onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: const Color(0xFF2A1F05),
                      disabledBackgroundColor: _kGold.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2A1F05),
                            ),
                          )
                        : const Text(
                            '창단',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A220E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kPanelBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: _kGold,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatCost(kTeamCreateCost),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _kGold.withValues(alpha: 0.85),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _formatCost(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _TeamResultTile extends StatelessWidget {
  final Team team;
  final VoidCallback onTap;

  const _TeamResultTile({required this.team, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A220E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPanelBorder.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              _TeamLogo(logoUrl: team.logoUrl, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  team.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _JoinModeChip({
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

class _TeamLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const _TeamLogo({this.logoUrl, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOliveMid, _kBrownBase],
        ),
        border: Border.all(color: _kGold, width: 1.5),
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(logoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasLogo
          ? null
          : Icon(Icons.shield_rounded, color: _kGold, size: size * 0.5),
    );
  }
}

class _WhiteInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  const _WhiteInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white70),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 14),
        cursorColor: const Color(0xFF3D5020),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.35),
            fontSize: 13,
          ),
          border: InputBorder.none,
          isDense: true,
          counterStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.35),
            fontSize: 11,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}
