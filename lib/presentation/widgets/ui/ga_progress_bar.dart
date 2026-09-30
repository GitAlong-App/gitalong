import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

/// A chunky pill progress bar with a glossy highlight band.
///
/// Height 16 by default. The fill is `green-bright` (or the [tone]'s colour)
/// with a 30 % white band 4 px high, inset 4 px from the top. Value changes
/// animate over 500 ms (ease-out); instant under reduced motion. Needs a
/// bounded width.
///
/// ```dart
/// GaProgressBar(
///   value: p.goalProgress,
///   semanticLabel: 'Daily goal',
///   semanticValue: '${p.todaySwipes} of ${p.dailyGoal}',
/// )
/// ```
class GaProgressBar extends StatelessWidget {
  const GaProgressBar({
    super.key,
    required this.value,
    this.tone = AppTone.green,
    this.height = 16,
    this.trackColor,
    this.animateOnMount = false,
    this.semanticLabel,
    this.semanticValue,
  });

  /// Progress, 0..1 (clamped).
  final double value;
  final AppTone tone;
  final double height;

  /// Defaults to the palette's `border` colour, visible on white.
  final Color? trackColor;

  /// Fill from 0 when first shown.
  final bool animateOnMount;

  final String? semanticLabel;

  /// Defaults to a percentage.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final track = trackColor ?? p.border;

    return Semantics(
      label: semanticLabel,
      value: semanticValue ?? '${(target * 100).round()}%',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: animateOnMount ? 0 : target, end: target),
          duration: AppTokens.motion(context, AppTokens.progressDuration),
          curve: Curves.easeOut,
          builder: (context, progress, _) => CustomPaint(
            painter: _ProgressBarPainter(
              progress: progress,
              fill: tone.progress,
              track: track,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({
    required this.progress,
    required this.fill,
    required this.track,
  });

  final double progress;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final radius = Radius.circular(h / 2);
    final paint = Paint()..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      paint..color = track,
    );

    if (progress <= 0) return;
    final width = math.max(h, size.width * progress.clamp(0.0, 1.0));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, h), radius),
      paint..color = fill,
    );

    // Glossy band: 30 % white, 4 px high, 4 px from the top.
    const bandHeight = 4.0;
    const bandTop = 4.0;
    final inset = h / 2;
    final bandWidth = width - inset * 2;
    if (h >= bandTop + bandHeight + 2 && bandWidth > 4) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, bandTop, bandWidth, bandHeight),
          const Radius.circular(bandHeight / 2),
        ),
        paint..color = Colors.white.withValues(alpha: 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fill != fill ||
      oldDelegate.track != track;
}
