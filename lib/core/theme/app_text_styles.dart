import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography: **Nunito** (Google Fonts, OFL) — docs/DESIGN_SYSTEM.md §2.
///
/// Prefer the spec names for new code: [display], [h1], [h2], [h3], [body],
/// [bodySm], [caption], [button] and [code]. The Material-style names
/// (`titleMedium`, `bodyMedium`, …) are kept for existing screens and map
/// onto the same scale.
///
/// [caption] and [button] are meant for UPPERCASE text: pass
/// `label.toUpperCase()` (the kit components already do).
///
/// Sizes use ScreenUtil's `.sp`, like the rest of the app, so they need a
/// `ScreenUtilInit` ancestor (the app root has one).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _nunito(
    Color color,
    double size,
    FontWeight weight, {
    double height = 1.3,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.nunito(
      fontSize: size.sp,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ── Spec scale ────────────────────────────────────────────────────────────

  /// Display 34 / 900 — hero and celebration titles.
  static TextStyle display(Color color) =>
      _nunito(color, 34, FontWeight.w900, height: 1.15, letterSpacing: -0.5);

  /// H1 28 / 900 — screen titles.
  static TextStyle h1(Color color) =>
      _nunito(color, 28, FontWeight.w900, height: 1.2, letterSpacing: -0.3);

  /// H2 22 / 800 — section titles.
  static TextStyle h2(Color color) =>
      _nunito(color, 22, FontWeight.w800, height: 1.25, letterSpacing: -0.2);

  /// H3 18 / 800 — card titles.
  static TextStyle h3(Color color) =>
      _nunito(color, 18, FontWeight.w800, height: 1.3);

  /// Body 16 / 600 — default text.
  static TextStyle body(Color color) =>
      _nunito(color, 16, FontWeight.w600, height: 1.45);

  /// Body-sm 14 / 600 — secondary text.
  static TextStyle bodySm(Color color) =>
      _nunito(color, 14, FontWeight.w600, height: 1.45);

  /// Caption 12 / 800, +0.8 tracking — UPPERCASE labels and chips.
  static TextStyle caption(Color color) =>
      _nunito(color, 12, FontWeight.w800, height: 1.3, letterSpacing: 0.8);

  /// Button 17 / 800, +0.8 tracking — UPPERCASE button labels.
  static TextStyle button(Color color) =>
      _nunito(color, 17, FontWeight.w800, height: 1.2, letterSpacing: 0.8);

  // ── Material names (kept for existing screens) ────────────────────────────

  // Display
  static TextStyle displayLarge(Color color) =>
      _nunito(color, 48, FontWeight.w900, height: 1.1, letterSpacing: -1);

  static TextStyle displayMedium(Color color) =>
      _nunito(color, 40, FontWeight.w900, height: 1.1, letterSpacing: -0.8);

  static TextStyle displaySmall(Color color) => display(color);

  // Headline
  static TextStyle headlineLarge(Color color) =>
      _nunito(color, 32, FontWeight.w900, height: 1.2, letterSpacing: -0.5);

  static TextStyle headlineMedium(Color color) => h1(color);

  static TextStyle headlineSmall(Color color) =>
      _nunito(color, 24, FontWeight.w800, height: 1.25, letterSpacing: -0.2);

  // Title
  static TextStyle titleLarge(Color color) => h2(color);

  static TextStyle titleMedium(Color color) =>
      _nunito(color, 16, FontWeight.w800, height: 1.35);

  static TextStyle titleSmall(Color color) =>
      _nunito(color, 14, FontWeight.w800, height: 1.35);

  // Body
  static TextStyle bodyLarge(Color color) => body(color);

  static TextStyle bodyMedium(Color color) => bodySm(color);

  static TextStyle bodySmall(Color color) =>
      _nunito(color, 12, FontWeight.w600, height: 1.4);

  // Label
  static TextStyle labelLarge(Color color) =>
      _nunito(color, 14, FontWeight.w800, height: 1.3, letterSpacing: 0.2);

  static TextStyle labelMedium(Color color) =>
      _nunito(color, 12, FontWeight.w800, height: 1.3, letterSpacing: 0.3);

  static TextStyle labelSmall(Color color) =>
      _nunito(color, 11, FontWeight.w800, height: 1.3, letterSpacing: 0.4);

  // Code (JetBrains Mono — code snippets only)
  static TextStyle code(Color color) => GoogleFonts.jetBrainsMono(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.6,
      );

  static TextStyle codeSmall(Color color) => GoogleFonts.jetBrainsMono(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.6,
      );

  /// A full Material [TextTheme] in Nunito, used by [ThemeData.textTheme] so
  /// stock widgets (dialogs, list tiles, text fields, …) match the kit.
  static TextTheme textTheme({required Color ink, required Color muted}) {
    return TextTheme(
      displayLarge: displayLarge(ink),
      displayMedium: displayMedium(ink),
      displaySmall: displaySmall(ink),
      headlineLarge: headlineLarge(ink),
      headlineMedium: headlineMedium(ink),
      headlineSmall: headlineSmall(ink),
      titleLarge: titleLarge(ink),
      titleMedium: titleMedium(ink),
      titleSmall: titleSmall(ink),
      bodyLarge: bodyLarge(ink),
      bodyMedium: bodyMedium(ink),
      bodySmall: bodySmall(muted),
      labelLarge: labelLarge(ink),
      labelMedium: labelMedium(ink),
      labelSmall: labelSmall(muted),
    );
  }
}
