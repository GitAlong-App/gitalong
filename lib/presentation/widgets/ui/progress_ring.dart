import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

/// Circular progress (e.g. profile strength around the avatar): stroke 6,
/// rounded caps, starts at 12 o'clock. Animates like [value] changes (500 ms,
/// instant under reduced motion). [child] sits in the middle, inset from the
/// ring.
///
/// ```dart
/// final s = profileStrength(user);
/// ProgressRing(value: s.done / s.total, size: 112, child: avatar)
/// ```
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 6,
    this.tone = AppTone.green,
    this.trackColor,
    this.child,
    this.animateOnMount = false,
    this.semanticLabel,
    this.semanticValue,
  });

  /// Progress, 0..1 (clamped).
  final double value;

  /// Outer diameter.
  final double size;
  final double strokeWidth;
  final AppTone tone;

  /// Defaults to the palette's `border` colour.
  final Color? trackColor;

  /// Content in the middle (e.g. an avatar).
  final Widget? child;

  final bool animateOnMount;
  final String? semanticLabel;

  /// Defaults to a percentage.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final content = child;

    return Semantics(
      label: semanticLabel,
      value: semanticValue ?? '${(target * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: animateOnMount ? 0 : target, end: target),
          duration: AppTokens.motion(context, AppTokens.progressDuration),
          curve: Curves.easeOut,
          builder: (context, progress, inner) => CustomPaint(
            painter: _RingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              color: tone.progress,
              track: trackColor ?? p.border,
            ),
            child: inner,
          ),
          child: content == null
              ? null
              : Padding(
                  padding: EdgeInsets.all(strokeWidth + 4),
                  child: Center(child: content),
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.track,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
