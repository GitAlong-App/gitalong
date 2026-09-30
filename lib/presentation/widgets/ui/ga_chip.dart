import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'illustration.dart';
import 'src/fill_width.dart';
import 'src/pressable.dart';

/// A pill chip: 2 px border, Caption type (UPPERCASE by default).
///
/// Selected = the [tone]'s tint fill and border (green by default). With
/// [onRemove] it shows an × (tapping the chip removes it when there is no
/// [onTap]; with both, the × removes and screen readers get a "Remove"
/// action). Visual height 36; tappable chips reserve a 48 px touch target.
///
/// ```dart
/// GaChip(label: 'Rust', selected: picked, onTap: () => toggle('Rust'))
/// GaChip(label: 'TypeScript', onRemove: () => remove('TypeScript'))
/// ```
class GaChip extends StatelessWidget {
  const GaChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.icon,
    this.illustration,
    this.tone = AppTone.green,
    this.uppercase = true,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Shows an × that calls this.
  final VoidCallback? onRemove;

  /// Leading icon (16 px).
  final IconData? icon;

  /// Leading illustration name (18 px); takes precedence over [icon].
  final String? illustration;

  /// Colour when [selected].
  final AppTone tone;

  final bool uppercase;

  /// Overrides the screen-reader label (defaults to [label]).
  final String? semanticLabel;

  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fill = selected ? p.tint(tone) : p.card;
    final border = selected ? tone.fill : p.border;
    final textColor = selected ? p.toneText(tone) : p.ink;
    final remove = onRemove;
    final tap = onTap;
    final removeOnly = remove != null && tap == null;
    final interactive = tap != null || remove != null;

    Widget? leading;
    final art = illustration;
    final leadingIcon = icon;
    if (art != null) {
      leading = Illustration(art, size: 18);
    } else if (leadingIcon != null) {
      leading = Icon(leadingIcon, size: 16, color: textColor);
    }

    Widget removeGlyph = Icon(
      Icons.close_rounded,
      size: 16,
      color: selected ? textColor : p.inkMuted,
    );
    if (remove != null && tap != null) {
      // Its own hit area; screen readers use the custom action instead.
      removeGlyph = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: remove,
        child: SizedBox(
          width: 32,
          height: _height,
          child: Center(child: removeGlyph),
        ),
      );
    }

    Widget pill(double pressed, bool focused) {
      return Transform.scale(
        scale: 1 - 0.04 * pressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: _height),
          padding: EdgeInsets.only(
            left: 14,
            right: remove != null ? (tap != null ? 2 : 10) : 14,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
              color: focused ? AppColors.greenBright : border,
              width: focused ? AppTokens.focusRingWidth : AppTokens.borderWidth,
            ),
          ),
          // Natural width in unbounded parents (horizontal lists), so the
          // flexible label never sees an infinite width.
          child: FillWidthIfBounded(
            fill: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    uppercase ? label.toUpperCase() : label,
                    style: AppTextStyles.caption(textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (remove != null) ...[
                  const SizedBox(width: 4),
                  removeGlyph,
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!interactive) {
      return Semantics(
        label: semanticLabel ?? label,
        selected: selected ? true : null,
        excludeSemantics: true,
        child: pill(0, false),
      );
    }

    return Pressable(
      onTap: removeOnly ? remove : tap,
      haptic: PressHaptic.selection,
      semanticLabel:
          semanticLabel ?? (removeOnly ? 'Remove $label' : label),
      selected: removeOnly ? null : selected,
      customSemanticsActions: remove != null && tap != null
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: 'Remove $label'): remove,
            }
          : null,
      builder: (context, pressed, focused) => Padding(
        padding: const EdgeInsets.symmetric(
          vertical: (AppTokens.minTouchTarget - _height) / 2,
        ),
        child: pill(pressed, focused),
      ),
    );
  }
}
