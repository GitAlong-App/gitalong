import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import 'src/depth_surface.dart';
import 'src/pressable.dart';

/// The design system's card: white (`card` in dark mode), 2 px border,
/// radius 20 and a 3 px `border-strong` bottom edge.
///
/// With [onTap] it becomes pressable (the face presses down onto the edge).
/// [onLongPress] only works together with [onTap]. A [tone] makes a tinted
/// tile: tone tint fill, tone border and tone edge — e.g. the gold "likes"
/// banner. [color], [borderColor] and [edgeColor] override individual
/// colours.
///
/// ```dart
/// GaTile(child: Text('Pitch'))
/// GaTile(tone: AppTone.gold, onTap: openLikes, child: Text('3 builders liked you'))
/// ```
class GaTile extends StatelessWidget {
  const GaTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.tone,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTokens.radiusLg,
    this.color,
    this.borderColor,
    this.edgeColor,
    this.showEdge = true,
    this.haptics = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final AppTone? tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Color? edgeColor;

  /// Draw the 3 px bottom edge.
  final bool showEdge;

  /// Light haptic when pressed.
  final bool haptics;

  /// Replaces the content's semantics with one label (for tiles that should
  /// read as a single item).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = tone;
    final fill = color ?? (t == null ? p.card : p.tint(t));
    final border = borderColor ?? (t == null ? p.border : t.fill);
    final edge = edgeColor ?? (t == null ? p.borderStrong : t.edge);
    final edgeHeight = showEdge ? AppTokens.tileEdge : 0.0;
    final borderRadius = BorderRadius.circular(radius);

    Widget surface(double pressed, bool focused) => DepthSurface(
          color: fill,
          edgeColor: edge,
          borderColor: border,
          edge: edgeHeight,
          borderRadius: borderRadius,
          pressed: pressed,
          focused: focused,
          padding: padding,
          child: child,
        );

    if (onTap == null) {
      final label = semanticLabel;
      final tile = surface(0, false);
      if (label == null) return tile;
      return Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: tile,
      );
    }

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      haptic: haptics ? PressHaptic.light : PressHaptic.none,
      semanticLabel: semanticLabel,
      builder: (context, pressed, focused) => surface(pressed, focused),
    );
  }
}
