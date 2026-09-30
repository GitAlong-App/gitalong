import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// Nope / Super like / Like: three big round 3D buttons under the card.
///
/// Each button swells a little as the card is dragged towards its action,
/// so the gesture and the buttons read as one control. A button is disabled
/// while its callback is null (e.g. during loading).
class SwipeActionBar extends StatelessWidget {
  const SwipeActionBar({
    super.key,
    required this.drag,
    required this.threshold,
    this.onNope,
    this.onSuperLike,
    this.onLike,
  });

  /// The top card's drag offset.
  final ValueNotifier<Offset> drag;

  /// Drag distance at which releasing commits the swipe.
  final double threshold;

  final VoidCallback? onNope;
  final VoidCallback? onSuperLike;
  final VoidCallback? onLike;

  static const double _sideSize = 64;
  static const double _centerSize = 56;
  static const double _grow = 0.15;

  static double _unit(double value) =>
      value <= 0 ? 0.0 : (value >= 1 ? 1.0 : value);

  @override
  Widget build(BuildContext context) {
    // Haptics come from the swipe itself (FeedbackService), not the press.
    final nope = CircleActionButton(
      icon: PhosphorIconsBold.x,
      tone: AppTone.danger,
      semanticLabel: 'Nope',
      size: _sideSize,
      haptics: false,
      onPressed: onNope,
    );
    final superLike = CircleActionButton(
      icon: PhosphorIconsFill.star,
      tone: AppTone.purple,
      semanticLabel: 'Super like',
      size: _centerSize,
      haptics: false,
      onPressed: onSuperLike,
    );
    final like = CircleActionButton(
      icon: PhosphorIconsFill.heart,
      tone: AppTone.green,
      semanticLabel: 'Like',
      size: _sideSize,
      haptics: false,
      onPressed: onLike,
    );

    Widget row(double nopeAmount, double superAmount, double likeAmount) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.scale(scale: 1 + _grow * nopeAmount, child: nope),
          const SizedBox(width: AppTokens.space24),
          Transform.scale(scale: 1 + _grow * superAmount, child: superLike),
          const SizedBox(width: AppTokens.space24),
          Transform.scale(scale: 1 + _grow * likeAmount, child: like),
        ],
      );
    }

    final Widget buttons = AppTokens.reduceMotion(context)
        ? row(0, 0, 0)
        : AnimatedBuilder(
            animation: drag,
            builder: (context, child) {
              final offset = drag.value;
              final horizontal = _unit(offset.dx.abs() / threshold);
              return row(
                offset.dx < 0 ? horizontal : 0.0,
                _unit(-offset.dy / threshold) * (1 - horizontal),
                offset.dx > 0 ? horizontal : 0.0,
              );
            },
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.gutter,
        AppTokens.space4,
        AppTokens.gutter,
        AppTokens.space16,
      ),
      child: buttons,
    );
  }
}
