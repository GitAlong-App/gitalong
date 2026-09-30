import 'package:flutter/material.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import 'animated_count.dart';
import 'illustration.dart';
import 'src/stat_chip.dart';

/// ⚡ + "120 XP" in `gold-edge` (a lighter gold in dark mode for contrast).
/// The number ticks up when XP grows.
///
/// ```dart
/// XpChip(xp: p.xp)
/// ```
class XpChip extends StatelessWidget {
  const XpChip({super.key, required this.xp, this.onTap});

  final int xp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return StatChip(
      semanticLabel: '$xp XP',
      onTap: onTap,
      pressedTint: p.tint(AppTone.gold),
      leading: const Illustration(Illustrations.highVoltage, size: 20),
      value: AnimatedCount(
        value: xp,
        suffix: ' XP',
        style: AppTextStyles.h3(p.toneText(AppTone.gold)),
      ),
    );
  }
}
