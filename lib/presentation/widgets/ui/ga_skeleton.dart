import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

enum _SkeletonKind { block, circle, lines }

/// Loading placeholder: rounded blocks with a soft, repeating shimmer
/// (static under reduced motion). Hidden from screen readers — wrap the
/// loading area in `Semantics(label: 'Loading')`.
///
/// ```dart
/// GaTile(
///   child: Row(children: [
///     GaSkeleton.circle(size: 48),
///     SizedBox(width: 12),
///     Expanded(child: GaSkeleton.lines(lines: 2)),
///   ]),
/// )
/// ```
class GaSkeleton extends StatelessWidget {
  /// A rounded block; full available width when [width] is null.
  const GaSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppTokens.radiusSm,
  })  : lineCount = 1,
        spacing = 0,
        _kind = _SkeletonKind.block;

  /// A circle (avatars).
  const GaSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = size / 2,
        lineCount = 1,
        spacing = 0,
        _kind = _SkeletonKind.circle;

  /// A paragraph: [lines] bars, the last one shorter.
  const GaSkeleton.lines({
    super.key,
    int lines = 3,
    this.height = 14,
    this.spacing = 8,
  })  : width = null,
        radius = AppTokens.radiusPill,
        lineCount = lines,
        _kind = _SkeletonKind.lines;

  final double? width;
  final double height;
  final double radius;
  final int lineCount;
  final double spacing;
  final _SkeletonKind _kind;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = p.skeleton;

    Widget bar(double? barWidth) => Container(
          width: barWidth ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    final count = lineCount < 1 ? 1 : lineCount;
    Widget shape = switch (_kind) {
      _SkeletonKind.block => bar(width),
      _SkeletonKind.circle => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      _SkeletonKind.lines => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              FractionallySizedBox(
                widthFactor: count > 1 && i == count - 1 ? 0.6 : 1,
                child: bar(null),
              ),
            ],
          ],
        ),
    };

    if (!AppTokens.reduceMotion(context)) {
      shape = shape
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: const Duration(milliseconds: 1300),
            color: p.skeletonHighlight,
          );
    }

    return ExcludeSemantics(child: shape);
  }
}
