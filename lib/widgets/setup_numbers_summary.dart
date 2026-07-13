import 'package:flutter/material.dart';

import '../models/double_judgment_config.dart';

const kSetupCategoryColors = {
  '아웃': Color(0xFF9E9E9E),
  '병살': Color(0xFFBB66FF),
  '3루타': Color(0xFF448AFF),
  '홈런': Color(0xFFFF5252),
};

const _kDoubleColor = Color(0xFFFFC107);

/// 본인 셋업 숫자 + 공통 2루타 조건 요약 바.
class SetupNumbersSummaryBar extends StatelessWidget {
  final Map<String, List<int>> setupNumbers;
  final DoubleJudgmentConfig? doubleJudgment;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final bool showLockIcon;

  const SetupNumbersSummaryBar({
    super.key,
    required this.setupNumbers,
    this.doubleJudgment,
    this.margin = const EdgeInsets.fromLTRB(16, 4, 16, 2),
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.fontSize = 9,
    this.showLockIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    if (setupNumbers.isEmpty && doubleJudgment == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: margin,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLockIcon) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: fontSize + 3,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...setupNumbers.entries.map(_buildSetupChip),
                  if (doubleJudgment != null) ...[
                    _buildDivider(),
                    _buildDoubleChip(doubleJudgment!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupChip(MapEntry<String, List<int>> e) {
    final color = kSetupCategoryColors[e.key] ?? Colors.white;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${e.key} ',
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: e.value.join('·'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Text(
      '|',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.28),
        fontSize: fontSize + 1,
        fontWeight: FontWeight.w300,
        height: 1.2,
      ),
    );
  }

  Widget _buildDoubleChip(DoubleJudgmentConfig config) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '2루타 ',
            style: TextStyle(
              color: _kDoubleColor.withValues(alpha: 0.92),
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: '${config.diceSideLetter}${config.targetFace}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
