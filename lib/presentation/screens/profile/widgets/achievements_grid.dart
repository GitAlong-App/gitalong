import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/constants/achievements.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';
import 'equal_height_row.dart';

/// All achievements in spec order, three per row, locked or unlocked.
/// Tapping one explains how it's earned.
class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({
    super.key,
    required this.isUnlocked,
    this.isNew,
  });

  /// Whether the signed-in user has earned the achievement with this key.
  final bool Function(String key) isUnlocked;

  /// Whether the achievement was unlocked since it was last seen (gets the
  /// kit's one-off highlight). Optional.
  final bool Function(String key)? isNew;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    const all = Achievements.all;
    final rows = <Widget>[];
    for (var start = 0; start < all.length; start += _columns) {
      final slice = all.sublist(start, math.min(start + _columns, all.length));
      rows.add(
        EqualHeightRow(
          spacing: AppTokens.space12,
          children: [
            for (final achievement in slice)
              AchievementTile(
                achievement: achievement,
                unlocked: isUnlocked(achievement.key),
                isNew: isNew?.call(achievement.key) ?? false,
                showDescription: false,
                onTap: () => showAchievementSheet(
                  context,
                  achievement: achievement,
                  unlocked: isUnlocked(achievement.key),
                ),
              ),
            for (var i = slice.length; i < _columns; i++) const SizedBox(),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTokens.space12),
          rows[i],
        ],
      ],
    );
  }
}

/// Bottom sheet with an achievement's art, title, status and how to earn it.
Future<void> showAchievementSheet(
  BuildContext context, {
  required AchievementDefinition achievement,
  required bool unlocked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _AchievementSheet(achievement: achievement, unlocked: unlocked),
  );
}

class _AchievementSheet extends StatelessWidget {
  const _AchievementSheet({required this.achievement, required this.unlocked});

  final AchievementDefinition achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final statusColor =
        unlocked ? palette.toneText(AppTone.green) : palette.inkMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space24,
        0,
        AppTokens.space24,
        AppTokens.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Illustration(
            achievement.illustration,
            size: 96,
            grayscale: !unlocked,
            opacity: unlocked ? 1.0 : 0.6,
          ),
          const SizedBox(height: AppTokens.space16),
          Semantics(
            header: true,
            child: Text(
              achievement.title,
              style: AppTextStyles.h2(palette.ink),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: unlocked ? palette.greenTint : palette.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                color: unlocked ? AppColors.green : palette.border,
                width: AppTokens.borderWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unlocked
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsFill.lockSimple,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Text(
                  unlocked ? 'UNLOCKED' : 'LOCKED',
                  style: AppTextStyles.caption(statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          Text(
            unlocked
                ? 'You earned this: ${achievement.description}'
                : 'How to earn it: ${achievement.description}',
            style: AppTextStyles.body(palette.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.space24),
          PressableButton(
            label: unlocked ? 'Nice!' : 'Got it',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
