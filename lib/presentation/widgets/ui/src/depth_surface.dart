import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

/// A face with a solid bottom edge: the "3D" look of every button and tile.
///
/// The face sits [edge] px above a same-shaped block in [edgeColor].
/// [pressed] (0..1, may overshoot slightly) moves the face down over the
/// edge, so a fully pressed surface looks flat. The overall size never
/// changes, so pressing doesn't shift the layout.
class DepthSurface extends StatelessWidget {
  const DepthSurface({
    super.key,
    required this.child,
    required this.color,
    required this.edgeColor,
    this.borderColor,
    this.borderWidth = AppTokens.borderWidth,
    this.edge = AppTokens.tileEdge,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppTokens.radiusLg),
    ),
    this.circle = false,
    this.pressed = 0,
    this.padding = EdgeInsets.zero,
    this.focused = false,
  });

  final Widget child;
  final Color color;
  final Color edgeColor;

  /// 2 px outline of the face; none when null.
  final Color? borderColor;
  final double borderWidth;

  /// Height of the bottom edge (0 for a flat surface).
  final double edge;

  /// Corner radius (ignored when [circle]).
  final BorderRadius borderRadius;
  final bool circle;

  /// 0 = resting, 1 = pressed flat.
  final double pressed;

  /// Padding inside the face.
  final EdgeInsetsGeometry padding;

  /// Draws the keyboard focus ring.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;
    final radius = circle ? null : borderRadius;
    final outline = borderColor;

    Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: radius,
        border: outline == null
            ? null
            : Border.all(color: outline, width: borderWidth),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (focused) {
      face = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.greenBright,
            width: AppTokens.focusRingWidth,
          ),
        ),
        child: face,
      );
    }

    if (edge <= 0) return face;

    return Stack(
      // Passthrough: the face gets the incoming constraints, so a surface
      // stretched to full width really is full width.
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: edge,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: edgeColor,
              shape: shape,
              borderRadius: radius,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: edge),
          child: Transform.translate(
            offset: Offset(0, edge * pressed),
            child: face,
          ),
        ),
      ],
    );
  }
}
