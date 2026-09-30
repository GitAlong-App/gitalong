import 'package:flutter/material.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import 'animated_count.dart';
import 'illustration.dart';
import 'src/stat_chip.dart';

/// 🔥 + the streak length in `flame`. The flame is grey (desaturated) when
/// the user hasn't been active today — the streak is "at risk". The number
/// ticks up when it grows. Tap to open the streak sheet.
///
/// ```dart
/// StreakChip(days: p.streakDays, activeToday: p.activeToday, onTap: _openStreakSheet)
/// ```
class StreakChip extends StatelessWidget {
  const StreakChip({
    super.key,
    required this.days,
    required this.activeToday,
    this.onTap,
  });

  final int days;

  /// Swiped or messaged today (their local day).
  final bool activeToday;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = activeToday ? p.toneText(AppTone.flame) : p.inkMuted;
    final dayWord = days == 1 ? 'day' : 'days';
    final label = activeToday
        ? '$days $dayWord streak'
        : '$days $dayWord streak, not active yet today';

    return StatChip(
      semanticLabel: label,
      onTap: onTap,
      pressedTint: p.tint(AppTone.flame),
      leading: Illustration(
        Illustrations.fire,
        size: 20,
        grayscale: !activeToday,
        opacity: activeToday ? 1 : 0.6,
      ),
      value: AnimatedCount(value: days, style: AppTextStyles.h3(color)),
    );
  }
}
