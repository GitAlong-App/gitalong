import 'package:flutter/material.dart';

/// GitAlong "Play" colour tokens (docs/DESIGN_SYSTEM.md §2).
///
/// Raw, brightness-independent constants. For colours that change between
/// light and dark mode (backgrounds, text, borders, tints) prefer
/// `AppPalette.of(context)` / `context.palette`, which resolves the right
/// value for the current theme.
///
/// The legacy names at the bottom (`primary`, `swipeLike`, `lightText`, …) are
/// kept so older screens keep compiling; they map onto the new palette.
class AppColors {
  AppColors._();

  // ── Brand hues (identical in light and dark) ─────────────────────────────

  /// Primary buttons, selected state, success.
  static const Color green = Color(0xFF16A34A);

  /// 3D bottom edge of green elements. Also the AA-safe green for text on
  /// light backgrounds (5.4:1 on white).
  static const Color greenEdge = Color(0xFF117A38);

  /// Progress fills, highlights, focus rings.
  static const Color greenBright = Color(0xFF22C55E);

  /// Selected card background (light mode).
  static const Color greenTint = Color(0xFFDCFCE7);

  /// Super-like, levels, "pro".
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleEdge = Color(0xFF5B21B6);
  static const Color purpleTint = Color(0xFFEDE9FE);

  /// Streaks.
  static const Color flame = Color(0xFFF97316);
  static const Color flameEdge = Color(0xFFC2410C);
  static const Color flameTint = Color(0xFFFFEDD5);

  /// XP, achievements.
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldEdge = Color(0xFFB45309);
  static const Color goldTint = Color(0xFFFEF3C7);

  /// Links, info.
  static const Color sky = Color(0xFF0EA5E9);
  static const Color skyEdge = Color(0xFF0369A1);
  static const Color skyTint = Color(0xFFE0F2FE);

  /// Nope, destructive.
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerEdge = Color(0xFFB91C1C);
  static const Color dangerTint = Color(0xFFFEE2E2);

  // Lighter shades used only for text/icons of a hue on dark backgrounds,
  // where the base hue would fall below AA contrast (e.g. purple on #1F2937
  // is 2.6:1, #A78BFA is 5.4:1).
  static const Color purpleBright = Color(0xFFA78BFA);
  static const Color flameBright = Color(0xFFFB923C);
  static const Color goldBright = Color(0xFFFBBF24);
  static const Color skyBright = Color(0xFF38BDF8);
  static const Color dangerBright = Color(0xFFF87171);

  // ── Neutrals, light ───────────────────────────────────────────────────────

  /// Primary text.
  static const Color ink = Color(0xFF0F172A);

  /// Secondary text.
  static const Color inkMuted = Color(0xFF64748B);

  /// Placeholder and disabled text.
  static const Color inkSubtle = Color(0xFF94A3B8);

  /// Page background.
  static const Color bg = Color(0xFFFFFFFF);

  /// Sections, input fills.
  static const Color surface = Color(0xFFF8FAFC);

  /// Tiles and cards.
  static const Color card = Color(0xFFFFFFFF);

  /// 2 px borders.
  static const Color border = Color(0xFFE2E8F0);

  /// Bottom edges of neutral tiles.
  static const Color borderStrong = Color(0xFFCBD5E1);

  /// Disabled button fill / edge.
  static const Color disabledFill = Color(0xFFE5E7EB);
  static const Color disabledEdge = Color(0xFFCBD5E1);

  /// Near-black used for the 3D edge of ink-filled buttons.
  static const Color inkEdge = Color(0xFF020617);

  // ── Neutrals, dark ────────────────────────────────────────────────────────

  static const Color darkBg = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1F2937);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkBorderStrong = Color(0xFF475569);
  static const Color darkInk = Color(0xFFF1F5F9);
  static const Color darkInkMuted = Color(0xFF94A3B8);
  static const Color darkInkSubtle = Color(0xFF64748B);

  // Dark tints = the brand colour at 15% opacity over `darkCard`, flattened
  // so they look the same on any surface.
  static const Color darkGreenTint = Color(0xFF1E3B3A);
  static const Color darkPurpleTint = Color(0xFF2D2C52);
  static const Color darkFlameTint = Color(0xFF403432);
  static const Color darkGoldTint = Color(0xFF3F3B30);
  static const Color darkSkyTint = Color(0xFF1C3C52);
  static const Color darkDangerTint = Color(0xFF3E2D39);

  /// Confetti / celebration colours.
  static const List<Color> confetti = [
    green,
    greenBright,
    purple,
    flame,
    gold,
    sky,
    danger,
  ];

  // ── Legacy names (kept for existing screens) ─────────────────────────────

  static const Color primary = green;
  static const Color primaryDark = greenEdge;
  static const Color primaryLight = greenBright;

  static const Color secondary = ink;
  static const Color secondaryDark = inkEdge;
  static const Color secondaryLight = Color(0xFF1E293B);

  static const Color accent = purple;
  static const Color accentDark = purpleEdge;
  static const Color accentLight = purpleBright;

  static const Color lightBackground = bg;
  static const Color lightSurface = card;
  static const Color lightSurfaceVariant = surface;

  static const Color lightText = ink;
  static const Color lightTextSecondary = inkMuted;
  static const Color lightTextTertiary = inkSubtle;

  static const Color darkBackground = darkBg;
  static const Color darkSurfaceVariant = darkCard;

  static const Color darkText = darkInk;
  static const Color darkTextSecondary = darkInkMuted;
  static const Color darkTextTertiary = darkInkSubtle;

  static const Color success = green;
  static const Color warning = gold;
  static const Color error = danger;
  static const Color info = sky;

  static const Color swipeLike = green;
  static const Color swipeDislike = danger;
  static const Color swipeSuperLike = purple;

  static const Color github = ink;
  static const Color google = Color(0xFF4285F4);
  static const Color apple = Color(0xFF000000);

  static const Color overlay = Color(0x800F172A);
  static const Color overlayLight = Color(0x400F172A);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [greenBright, green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [purpleBright, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [green, greenEdge],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// A brand hue with its fill, 3D edge, and bright shade.
///
/// Components take an [AppTone] instead of raw colours so the fill, edge,
/// tint and the readable text colour always come as a matching set.
/// Tints depend on brightness: use `context.palette.tint(tone)`.
enum AppTone {
  green(AppColors.green, AppColors.greenEdge, AppColors.greenBright),
  purple(AppColors.purple, AppColors.purpleEdge, AppColors.purpleBright),
  flame(AppColors.flame, AppColors.flameEdge, AppColors.flameBright),
  gold(AppColors.gold, AppColors.goldEdge, AppColors.goldBright),
  sky(AppColors.sky, AppColors.skyEdge, AppColors.skyBright),
  danger(AppColors.danger, AppColors.dangerEdge, AppColors.dangerBright);

  const AppTone(this.fill, this.edge, this.bright);

  /// The main hue (button fills, icons, badges).
  final Color fill;

  /// The darker shade used for the 3D bottom edge.
  final Color edge;

  /// A lighter shade (progress fills for green; text on dark backgrounds).
  final Color bright;

  /// Text/icon colour on top of [fill]: white, except ink on gold and sky
  /// (spec §2: "Text on gold and green-bright fills is ink").
  Color get onFill =>
      this == AppTone.gold || this == AppTone.sky ? AppColors.ink : Colors.white;

  /// The fill of progress bars and rings: `green-bright` for green (spec),
  /// the base hue for the other tones.
  Color get progress => this == AppTone.green ? AppColors.greenBright : fill;

  /// A readable colour for text or small icons in this hue on the page
  /// background: the edge shade in light mode (≥ 4.5:1 on white) and the
  /// bright shade in dark mode.
  Color textOn(Brightness brightness) =>
      brightness == Brightness.dark ? bright : edge;
}
