import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'illustration.dart';
import 'src/depth_surface.dart';
import 'src/fill_width.dart';
import 'src/pressable.dart';

/// Colour variants of [PressableButton].
enum PressableVariant {
  /// Green fill, white label: the main action on a screen.
  primary,

  /// White (card) fill, 2 px border, neutral edge, ink label.
  secondary,

  /// Super-like, levels, "pro".
  purple,

  /// Streak actions.
  flame,

  /// XP / reward actions (ink label).
  gold,

  /// Informational actions (ink label).
  sky,

  /// Destructive actions.
  danger,

  /// Dark ink fill (light fill in dark mode), e.g. "Continue with GitHub".
  ink,

  /// No fill or edge; green label. Low-emphasis actions ("Keep swiping").
  ghost,
}

/// Height presets of [PressableButton] (total height including the 4 px
/// edge).
enum PressableSize {
  /// 40 px. Keeps a 48 px touch target with transparent padding.
  small,

  /// 52 px (spec default).
  medium,

  /// 60 px, for hero actions.
  large,
}

/// The chunky 3D button of the design system.
///
/// Radius 16, a solid 4 px bottom edge in a darker shade. On press the face
/// moves down 4 px as the edge collapses (90 ms), with a light haptic tick,
/// then springs back on release. The label is shown in UPPERCASE.
///
/// Disabled when [onPressed] is null; [loading] swaps the label for a
/// spinner and ignores taps. Full width by default when the parent's width
/// is bounded (falls back to its natural width inside an unbounded `Row`).
///
/// ```dart
/// PressableButton(label: 'Get started', onPressed: _start)
/// PressableButton(
///   label: 'Continue with GitHub',
///   variant: PressableVariant.ink,
///   icon: PhosphorIconsFill.githubLogo,
///   onPressed: _signIn,
/// )
/// ```
class PressableButton extends StatelessWidget {
  const PressableButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PressableVariant.primary,
    this.size = PressableSize.medium,
    this.icon,
    this.illustration,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = true,
    this.haptics = true,
    this.semanticLabel,
    this.autofocus = false,
  });

  /// Button text (shown uppercase; read as written by screen readers).
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  final PressableVariant variant;
  final PressableSize size;

  /// Leading icon.
  final IconData? icon;

  /// Leading illustration name (24 px); takes precedence over [icon].
  final String? illustration;

  final IconData? trailingIcon;

  /// Shows a spinner instead of the label and ignores taps.
  final bool loading;

  /// Stretch to the available width (when bounded).
  final bool fullWidth;

  /// Light haptic on press.
  final bool haptics;

  /// Overrides the screen-reader label (defaults to [label]).
  final String? semanticLabel;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final metrics = _ButtonMetrics.of(size);
    final colors = _ButtonColors.resolve(
      variant,
      p,
      disabled: onPressed == null,
    );
    final isGhost = variant == PressableVariant.ghost;
    final edge = isGhost ? 0.0 : AppTokens.buttonEdge;
    final faceHeight = metrics.height - edge;
    final radius = BorderRadius.circular(AppTokens.radiusMd);

    final baseText = AppTextStyles.button(colors.label);
    final textStyle = baseText.copyWith(
      fontSize: (baseText.fontSize ?? 17) * metrics.fontScale,
    );

    Widget? leading;
    final art = illustration;
    final leadingIcon = icon;
    if (art != null) {
      leading = Illustration(art, size: metrics.illustrationSize);
    } else if (leadingIcon != null) {
      leading = Icon(leadingIcon, size: metrics.iconSize, color: colors.label);
    }
    final trailing = trailingIcon;

    final Widget content = loading
        ? SizedBox.square(
            dimension: metrics.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.label,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: textStyle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                Icon(trailing, size: metrics.iconSize, color: colors.label),
              ],
            ],
          );

    Widget button = Pressable(
      onTap: loading ? null : onPressed,
      haptic: haptics ? PressHaptic.light : PressHaptic.none,
      semanticLabel: semanticLabel ?? label,
      semanticValue: loading ? 'Loading' : null,
      autofocus: autofocus,
      builder: (context, pressed, focused) {
        final fill = isGhost
            ? Color.lerp(
                  colors.fill,
                  p.tint(AppTone.green),
                  pressed.clamp(0.0, 1.0).toDouble(),
                ) ??
                colors.fill
            : colors.fill;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: metrics.touchPadding),
          child: DepthSurface(
            color: fill,
            edgeColor: colors.edge,
            borderColor: colors.border,
            edge: edge,
            borderRadius: radius,
            pressed: pressed,
            focused: focused,
            padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: faceHeight),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        );
      },
    );

    button = FillWidthIfBounded(fill: fullWidth, child: button);
    return button;
  }
}

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.height,
    required this.fontScale,
    required this.iconSize,
    required this.illustrationSize,
    required this.horizontalPadding,
    required this.touchPadding,
  });

  /// Total visual height including the edge.
  final double height;
  final double fontScale;
  final double iconSize;
  final double illustrationSize;
  final double horizontalPadding;

  /// Transparent vertical padding that keeps the touch target ≥ 48 px.
  final double touchPadding;

  static _ButtonMetrics of(PressableSize size) => switch (size) {
        PressableSize.small => const _ButtonMetrics(
            height: 40,
            fontScale: 15 / 17,
            iconSize: 18,
            illustrationSize: 20,
            horizontalPadding: 16,
            touchPadding: 4,
          ),
        PressableSize.medium => const _ButtonMetrics(
            height: AppTokens.buttonHeight,
            fontScale: 1,
            iconSize: 22,
            illustrationSize: 24,
            horizontalPadding: 20,
            touchPadding: 0,
          ),
        PressableSize.large => const _ButtonMetrics(
            height: 60,
            fontScale: 18 / 17,
            iconSize: 24,
            illustrationSize: 28,
            horizontalPadding: 24,
            touchPadding: 0,
          ),
      };
}

class _ButtonColors {
  const _ButtonColors({
    required this.fill,
    required this.edge,
    required this.label,
    this.border,
  });

  final Color fill;
  final Color edge;
  final Color label;
  final Color? border;

  static _ButtonColors resolve(
    PressableVariant variant,
    AppPalette p, {
    required bool disabled,
  }) {
    final clear = p.bg.withValues(alpha: 0);
    if (variant == PressableVariant.ghost) {
      return _ButtonColors(
        fill: clear,
        edge: clear,
        label: disabled ? p.disabledText : p.toneText(AppTone.green),
      );
    }
    if (disabled) {
      return _ButtonColors(
        fill: p.disabledFill,
        edge: p.disabledEdge,
        label: p.disabledText,
      );
    }
    return switch (variant) {
      PressableVariant.primary => _tone(AppTone.green),
      PressableVariant.purple => _tone(AppTone.purple),
      PressableVariant.flame => _tone(AppTone.flame),
      PressableVariant.gold => _tone(AppTone.gold),
      PressableVariant.sky => _tone(AppTone.sky),
      PressableVariant.danger => _tone(AppTone.danger),
      PressableVariant.secondary => _ButtonColors(
          fill: p.card,
          edge: p.borderStrong,
          border: p.border,
          label: p.ink,
        ),
      PressableVariant.ink => p.isDark
          ? const _ButtonColors(
              fill: AppColors.darkInk,
              edge: AppColors.borderStrong,
              label: AppColors.ink,
            )
          : const _ButtonColors(
              fill: AppColors.ink,
              edge: AppColors.inkEdge,
              label: Colors.white,
            ),
      // Handled above; listed for exhaustiveness.
      PressableVariant.ghost => _ButtonColors(
          fill: clear,
          edge: clear,
          label: p.toneText(AppTone.green),
        ),
    };
  }

  static _ButtonColors _tone(AppTone tone) =>
      _ButtonColors(fill: tone.fill, edge: tone.edge, label: tone.onFill);
}
