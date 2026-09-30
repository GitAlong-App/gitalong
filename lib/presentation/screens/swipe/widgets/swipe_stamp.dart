import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';

/// A chunky sticker stamp (LIKE, NOPE or SUPER): the tone's fill on a 4 px
/// darker bottom edge, with a white outline so it reads on any card.
class SwipeStamp extends StatelessWidget {
  const SwipeStamp({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final AppTone tone;

  static const double _outline = 3;
  static const BorderRadius _radius =
      BorderRadius.all(Radius.circular(AppTokens.radiusMd));

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(AppTokens.radiusMd + _outline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_outline),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tone.edge, borderRadius: _radius),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.buttonEdge),
            child: DecoratedBox(
              decoration: BoxDecoration(color: tone.fill, borderRadius: _radius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 26, color: tone.onFill),
                    const SizedBox(width: AppTokens.space8),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      style: AppTextStyles.h1(tone.onFill).copyWith(
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour wash and the LIKE / NOPE / SUPER stamps over the dragged card.
///
/// Each amount is 0..1: how far the drag has gone towards that action (1 =
/// releasing now commits it). Paints nothing at 0 and ignores touches.
class SwipeStampsOverlay extends StatelessWidget {
  const SwipeStampsOverlay({
    super.key,
    required this.like,
    required this.nope,
    required this.superLike,
  });

  final double like;
  final double nope;
  final double superLike;

  static const SwipeStamp _likeStamp = SwipeStamp(
    label: 'Like',
    icon: PhosphorIconsFill.heart,
    tone: AppTone.green,
  );
  static const SwipeStamp _nopeStamp = SwipeStamp(
    label: 'Nope',
    icon: PhosphorIconsBold.x,
    tone: AppTone.danger,
  );
  static const SwipeStamp _superStamp = SwipeStamp(
    label: 'Super',
    icon: PhosphorIconsFill.star,
    tone: AppTone.purple,
  );

  @override
  Widget build(BuildContext context) {
    final reduced = AppTokens.reduceMotion(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _wash(AppTone.green, like),
          _wash(AppTone.danger, nope),
          _wash(AppTone.purple, superLike),
          Positioned(
            top: 24,
            left: 18,
            child: _stamp(_likeStamp, like, -0.2, reduced),
          ),
          Positioned(
            top: 24,
            right: 18,
            child: _stamp(_nopeStamp, nope, 0.2, reduced),
          ),
          Align(
            alignment: const Alignment(0, 0.45),
            child: _stamp(_superStamp, superLike, -0.06, reduced),
          ),
        ],
      ),
    );
  }

  static Widget _wash(AppTone tone, double amount) {
    if (amount <= 0) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.fill.withValues(alpha: 0.16 * _unit(amount)),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      ),
    );
  }

  static Widget _stamp(
    SwipeStamp stamp,
    double amount,
    double angle,
    bool reduced,
  ) {
    if (amount <= 0) return const SizedBox.shrink();
    final t = _unit(amount);
    return Opacity(
      opacity: t,
      child: Transform.rotate(
        angle: angle,
        child: reduced
            ? stamp
            : Transform.scale(scale: 0.85 + 0.15 * t, child: stamp),
      ),
    );
  }

  static double _unit(double value) =>
      value <= 0 ? 0.0 : (value >= 1 ? 1.0 : value);
}
