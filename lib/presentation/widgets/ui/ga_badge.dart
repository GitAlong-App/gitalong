import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';

/// A count pill (unread messages, new matches) in `danger` by default, with
/// a ring in the page colour so it reads on top of icons and avatars. With a
/// [child], the pill sits on the child's top-right corner. Hidden when
/// [count] is 0 unless [showZero]. Pops in when the count changes.
///
/// ```dart
/// GaBadge(count: unread, child: const Icon(Icons.chat_bubble_rounded))
/// ```
class GaBadge extends StatelessWidget {
  const GaBadge({
    super.key,
    required this.count,
    this.child,
    this.tone = AppTone.danger,
    this.showZero = false,
    this.max = 99,
    this.semanticLabel,
  });

  final int count;
  final Widget? child;
  final AppTone tone;
  final bool showZero;

  /// Larger counts show as "99+".
  final int max;

  /// Screen-reader text; defaults to "N new".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = count > 0 || showZero;
    final text = count > max ? '$max+' : '$count';
    final anchor = child;

    Widget pill = Semantics(
      label: semanticLabel ?? '$text new',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.fill,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: p.bg, width: AppTokens.borderWidth),
        ),
        child: Text(
          text,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTextStyles.labelSmall(tone.onFill).copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ),
    );

    if (!AppTokens.reduceMotion(context)) {
      pill = pill.animate(key: ValueKey<int>(count)).scaleXY(
            begin: 0.5,
            end: 1,
            duration: AppTokens.slow,
            curve: AppTokens.bounceCurve,
          );
    }

    if (anchor == null) return visible ? pill : const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        anchor,
        if (visible) Positioned(top: -8, right: -10, child: pill),
      ],
    );
  }
}
