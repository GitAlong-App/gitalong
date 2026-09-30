import 'package:flutter/material.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/progress_entity.dart';
import '../../../bloc/progress/progress_state.dart';
import '../../../widgets/ui/ui.dart';

/// Discover's top bar: the title with the streak and XP chips, and the
/// daily-goal bar ("6 / 10 builders today") under it.
///
/// Skeletons while progress loads; the progress parts collapse away when
/// progress is unavailable (or not wired), leaving just the title.
class DiscoverHeader extends StatelessWidget {
  const DiscoverHeader({
    super.key,
    required this.progress,
    this.onStreakTap,
    this.onXpTap,
  });

  /// The progress state, or null when there is no progress source.
  final ProgressState? progress;

  final ValueChanged<ProgressEntity>? onStreakTap;
  final ValueChanged<ProgressEntity>? onXpTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = progress;
    final duration = AppTokens.motion(context, AppTokens.medium);

    final String kind;
    Widget stats = const SizedBox.shrink();
    Widget goal = const SizedBox.shrink();
    if (state is ProgressLoaded) {
      kind = 'loaded';
      final data = state.progress;
      final streakTap = onStreakTap;
      final xpTap = onXpTap;
      stats = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreakChip(
            days: data.streakDays,
            activeToday: data.activeToday,
            onTap: streakTap == null ? null : () => streakTap(data),
          ),
          XpChip(
            xp: data.xp,
            onTap: xpTap == null ? null : () => xpTap(data),
          ),
        ],
      );
      goal = DailyGoalBar(progress: data);
    } else if (state is ProgressInitial) {
      kind = 'loading';
      stats = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GaSkeleton(width: 48, height: 26, radius: AppTokens.radiusPill),
          SizedBox(width: AppTokens.space8),
          GaSkeleton(width: 84, height: 26, radius: AppTokens.radiusPill),
          SizedBox(width: AppTokens.space8),
        ],
      );
      goal = const _DailyGoalSkeleton();
    } else {
      kind = 'none';
    }

    return Padding(
      // Tappable chips carry their own 8 px inset on the right.
      padding: const EdgeInsets.fromLTRB(
        AppTokens.gutter,
        AppTokens.space4,
        AppTokens.space12,
        0,
      ),
      child: AnimatedSize(
        duration: duration,
        curve: AppTokens.curve,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTokens.minTouchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Discover',
                        style: AppTextStyles.h1(p.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: duration,
                    child: KeyedSubtree(
                      key: ValueKey<String>('stats-$kind'),
                      child: stats,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: duration,
              child: KeyedSubtree(
                key: ValueKey<String>('goal-$kind'),
                child: goal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The trophy (grey until earned), "6 / 10 builders today" ticking up, and
/// the goal bar, which turns gold once the goal is reached.
class DailyGoalBar extends StatelessWidget {
  const DailyGoalBar({super.key, required this.progress});

  final ProgressEntity progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reached = progress.goalReached;
    final today = progress.todaySwipes;
    final goal = progress.dailyGoal;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppTokens.space4,
        bottom: AppTokens.space4,
        right: AppTokens.space8,
      ),
      child: Row(
        children: [
          Illustration(
            Illustrations.trophy,
            size: 30,
            grayscale: !reached,
            opacity: reached ? 1.0 : 0.55,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The bar below announces the value to screen readers.
                ExcludeSemantics(
                  child: AnimatedCount(
                    value: today,
                    prefix: reached ? 'Daily goal reached · ' : '',
                    suffix: reached ? ' today' : ' / $goal builders today',
                    style: AppTextStyles.titleSmall(
                      reached ? p.toneText(AppTone.gold) : p.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GaProgressBar(
                  value: progress.goalProgress,
                  tone: reached ? AppTone.gold : AppTone.green,
                  semanticLabel: 'Daily goal',
                  semanticValue: reached
                      ? 'Reached, $today builders reviewed today'
                      : '$today of $goal builders reviewed today',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyGoalSkeleton extends StatelessWidget {
  const _DailyGoalSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        top: AppTokens.space4,
        bottom: AppTokens.space4,
        right: AppTokens.space8,
      ),
      child: Row(
        children: [
          GaSkeleton.circle(size: 30),
          SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GaSkeleton(width: 150, height: 14),
                SizedBox(height: 6),
                GaSkeleton(height: 16, radius: AppTokens.radiusPill),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
