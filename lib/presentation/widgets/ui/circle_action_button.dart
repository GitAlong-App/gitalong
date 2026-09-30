import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import 'src/depth_surface.dart';
import 'src/pressable.dart';

/// A big round 3D button, e.g. the Nope (danger), Super (purple) and Like
/// (green) actions under the Discover card. Filled with the [tone] and a
/// white icon by default; [filled] false gives a white face with a
/// tone-coloured icon. [size] is the face diameter; the edge adds 4–5 px.
///
/// ```dart
/// CircleActionButton(
///   icon: PhosphorIconsBold.x,
///   tone: AppTone.danger,
///   semanticLabel: 'Nope',
///   onPressed: _nope,
/// )
/// ```
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tone = AppTone.green,
    this.size = 64,
    this.filled = true,
    this.haptics = true,
  });

  final IconData icon;

  /// Required: the button has no visible text.
  final String semanticLabel;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final AppTone tone;

  /// Face diameter.
  final double size;

  final bool filled;
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null;
    final edge = size >= 56 ? 5.0 : AppTokens.buttonEdge;

    final Color face;
    final Color edgeColor;
    final Color iconColor;
    Color? border;
    if (!enabled) {
      face = p.disabledFill;
      edgeColor = p.disabledEdge;
      iconColor = p.disabledText;
    } else if (filled) {
      face = tone.fill;
      edgeColor = tone.edge;
      iconColor = tone.onFill;
    } else {
      face = p.card;
      edgeColor = p.borderStrong;
      border = p.border;
      iconColor = p.toneText(tone);
    }

    return Pressable(
      onTap: onPressed,
      haptic: haptics ? PressHaptic.light : PressHaptic.none,
      semanticLabel: semanticLabel,
      builder: (context, pressed, focused) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppTokens.minTouchTarget,
          minHeight: AppTokens.minTouchTarget,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DepthSurface(
            circle: true,
            color: face,
            edgeColor: edgeColor,
            borderColor: border,
            edge: edge,
            pressed: pressed,
            focused: focused,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.42, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
