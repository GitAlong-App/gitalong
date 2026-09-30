import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// A number that ticks up (or down) to [value] whenever it changes, with
/// tabular figures so it doesn't jitter. On first build it counts from
/// [from] when given, otherwise it simply shows [value]. Instant under
/// reduced motion. Screen readers get the final value only.
///
/// ```dart
/// AnimatedCount(value: p.xp, suffix: ' XP', style: AppTextStyles.h3(color))
/// AnimatedCount(from: 0, value: 50, prefix: '+', suffix: ' XP')
/// ```
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.from,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppTokens.countDuration,
    this.semanticsLabel,
  });

  final int value;
  final TextStyle? style;

  /// Starting number for the first animation.
  final int? from;

  final String prefix;
  final String suffix;
  final Duration duration;

  /// Defaults to "$prefix$value$suffix".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final textStyle = base.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      label: semanticsLabel ?? '$prefix$value$suffix',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: (from ?? value).toDouble(),
          end: value.toDouble(),
        ),
        duration: AppTokens.motion(context, duration),
        curve: AppTokens.curve,
        builder: (context, current, _) => Text(
          '$prefix${current.round()}$suffix',
          style: textStyle,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}
