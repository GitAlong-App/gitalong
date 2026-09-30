import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/achievements.dart';
import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'ga_tile.dart';
import 'illustration.dart';

/// An achievement in a grid: 56 px illustration, title and description.
///
/// Locked: grayscale at 40 % with a lock. [isNew] (just unlocked): gold ring
/// and a one-time shimmer.
///
/// ```dart
/// for (final a in Achievements.all)
///   AchievementTile(achievement: a, unlocked: p.hasAchievement(a.key))
/// ```
class AchievementTile extends StatelessWidget {
  const AchievementTile({
    super.key,
    required this.achievement,
    required this.unlocked,
    this.isNew = false,
    this.showDescription = true,
    this.onTap,
  });

  final AchievementDefinition achievement;
  final bool unlocked;

  /// Highlight a fresh unlock.
  final bool isNew;

  final bool showDescription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final highlight = isNew && unlocked;
    final reduced = AppTokens.reduceMotion(context);

    Widget art = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? p.goldTint : p.surface,
            border: Border.all(
              color: highlight ? AppColors.gold : p.border,
              width: highlight ? 3 : AppTokens.borderWidth,
            ),
            // A crisp halo (no blur) for fresh unlocks.
            boxShadow: highlight
                ? [BoxShadow(color: p.goldTint, spreadRadius: 4)]
                : null,
          ),
        ),
        Illustration(
          achievement.illustration,
          size: 56,
          grayscale: !unlocked,
          opacity: unlocked ? 1 : 0.4,
        ),
        if (!unlocked)
          const Positioned(
            right: -2,
            bottom: -2,
            child: Illustration(Illustrations.locked, size: 24),
          ),
      ],
    );

    if (highlight && !reduced) {
      art = art.animate().shimmer(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 1200),
            color: Colors.white.withValues(alpha: 0.7),
          );
    }

    final status = unlocked ? (isNew ? 'Unlocked, new' : 'Unlocked') : 'Locked';

    return GaTile(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      semanticLabel:
          'Achievement: ${achievement.title}. ${achievement.description}. $status',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          art,
          const SizedBox(height: 10),
          Text(
            achievement.title,
            style: AppTextStyles.titleSmall(unlocked ? p.ink : p.inkMuted),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (showDescription) ...[
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: AppTextStyles.bodySmall(p.inkMuted),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
