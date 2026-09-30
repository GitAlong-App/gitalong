import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import 'pressable.dart';

/// Icon + number layout shared by the streak and XP chips. Tappable chips
/// get a 48 px touch target and a tinted pressed state.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.leading,
    required this.value,
    required this.semanticLabel,
    this.onTap,
    this.pressedTint,
  });

  final Widget leading;
  final Widget value;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Color? pressedTint;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final tint = pressedTint ?? AppColors.greenTint;

    Widget body(double pressed, bool focused) {
      final t = pressed.clamp(0.0, 1.0).toDouble();
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: tappable ? AppTokens.minTouchTarget : 0,
          minWidth: tappable ? AppTokens.minTouchTarget : 0,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(tint.withValues(alpha: 0), tint, t),
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: focused
                  ? Border.all(
                      color: AppColors.greenBright,
                      width: AppTokens.focusRingWidth,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [leading, const SizedBox(width: 6), value],
              ),
            ),
          ),
        ),
      );
    }

    if (!tappable) {
      return Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: body(0, false),
      );
    }

    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, pressed, focused) => body(pressed, focused),
    );
  }
}
