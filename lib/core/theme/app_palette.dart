import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brightness-aware semantic colours, installed on both themes as a
/// [ThemeExtension].
///
/// ```dart
/// final p = context.palette; // or AppPalette.of(context)
/// Container(color: p.card, child: Text('Hi', style: TextStyle(color: p.ink)));
/// ```
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.greenTint,
    required this.purpleTint,
    required this.flameTint,
    required this.goldTint,
    required this.skyTint,
    required this.dangerTint,
    required this.disabledFill,
    required this.disabledEdge,
    required this.disabledText,
    required this.skeleton,
    required this.skeletonHighlight,
    required this.scrim,
  });

  /// Light palette.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    bg: AppColors.bg,
    surface: AppColors.surface,
    card: AppColors.card,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    ink: AppColors.ink,
    inkMuted: AppColors.inkMuted,
    inkSubtle: AppColors.inkSubtle,
    greenTint: AppColors.greenTint,
    purpleTint: AppColors.purpleTint,
    flameTint: AppColors.flameTint,
    goldTint: AppColors.goldTint,
    skyTint: AppColors.skyTint,
    dangerTint: AppColors.dangerTint,
    disabledFill: AppColors.disabledFill,
    disabledEdge: AppColors.disabledEdge,
    disabledText: AppColors.inkSubtle,
    skeleton: AppColors.border,
    skeletonHighlight: Color(0x99FFFFFF),
    scrim: Color(0x990F172A),
  );

  /// Dark palette: brand hues stay the same, tints are the hue at 15% over
  /// `card`.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    bg: AppColors.darkBg,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    border: AppColors.darkBorder,
    borderStrong: AppColors.darkBorderStrong,
    ink: AppColors.darkInk,
    inkMuted: AppColors.darkInkMuted,
    inkSubtle: AppColors.darkInkSubtle,
    greenTint: AppColors.darkGreenTint,
    purpleTint: AppColors.darkPurpleTint,
    flameTint: AppColors.darkFlameTint,
    goldTint: AppColors.darkGoldTint,
    skyTint: AppColors.darkSkyTint,
    dangerTint: AppColors.darkDangerTint,
    disabledFill: AppColors.darkBorder,
    disabledEdge: AppColors.darkBorderStrong,
    disabledText: AppColors.darkInkSubtle,
    skeleton: AppColors.darkCard,
    skeletonHighlight: Color(0x1FFFFFFF),
    scrim: Color(0xB3000000),
  );

  final Brightness brightness;

  /// Page background.
  final Color bg;

  /// Sections, input fills, progress tracks' surroundings.
  final Color surface;

  /// Tiles, cards, sheets, dialogs.
  final Color card;

  /// 2 px borders.
  final Color border;

  /// Bottom edge of neutral tiles.
  final Color borderStrong;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color inkMuted;

  /// Placeholder / disabled text.
  final Color inkSubtle;

  final Color greenTint;
  final Color purpleTint;
  final Color flameTint;
  final Color goldTint;
  final Color skyTint;
  final Color dangerTint;

  /// Disabled button fill, edge and label.
  final Color disabledFill;
  final Color disabledEdge;
  final Color disabledText;

  /// Skeleton block colour and its shimmer highlight.
  final Color skeleton;
  final Color skeletonHighlight;

  /// Modal barrier behind sheets and dialogs.
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  /// The selected/tinted background for [tone].
  Color tint(AppTone tone) => switch (tone) {
        AppTone.green => greenTint,
        AppTone.purple => purpleTint,
        AppTone.flame => flameTint,
        AppTone.gold => goldTint,
        AppTone.sky => skyTint,
        AppTone.danger => dangerTint,
      };

  /// Readable text/icon colour for [tone] on this palette's backgrounds.
  Color toneText(AppTone tone) => tone.textOn(brightness);

  /// The palette of the nearest [Theme], falling back to [light]/[dark] by
  /// brightness when the extension is missing.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? card,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? greenTint,
    Color? purpleTint,
    Color? flameTint,
    Color? goldTint,
    Color? skyTint,
    Color? dangerTint,
    Color? disabledFill,
    Color? disabledEdge,
    Color? disabledText,
    Color? skeleton,
    Color? skeletonHighlight,
    Color? scrim,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkSubtle: inkSubtle ?? this.inkSubtle,
      greenTint: greenTint ?? this.greenTint,
      purpleTint: purpleTint ?? this.purpleTint,
      flameTint: flameTint ?? this.flameTint,
      goldTint: goldTint ?? this.goldTint,
      skyTint: skyTint ?? this.skyTint,
      dangerTint: dangerTint ?? this.dangerTint,
      disabledFill: disabledFill ?? this.disabledFill,
      disabledEdge: disabledEdge ?? this.disabledEdge,
      disabledText: disabledText ?? this.disabledText,
      skeleton: skeleton ?? this.skeleton,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      card: mix(card, other.card),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkSubtle: mix(inkSubtle, other.inkSubtle),
      greenTint: mix(greenTint, other.greenTint),
      purpleTint: mix(purpleTint, other.purpleTint),
      flameTint: mix(flameTint, other.flameTint),
      goldTint: mix(goldTint, other.goldTint),
      skyTint: mix(skyTint, other.skyTint),
      dangerTint: mix(dangerTint, other.dangerTint),
      disabledFill: mix(disabledFill, other.disabledFill),
      disabledEdge: mix(disabledEdge, other.disabledEdge),
      disabledText: mix(disabledText, other.disabledText),
      skeleton: mix(skeleton, other.skeleton),
      skeletonHighlight: mix(skeletonHighlight, other.skeletonHighlight),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// `context.palette` shorthand for [AppPalette.of].
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
