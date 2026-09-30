import 'package:flutter/widgets.dart';

/// Shape, spacing and motion tokens (docs/DESIGN_SYSTEM.md §2 and §4).
///
/// Values are logical pixels. They are intentionally *not* scaled with
/// ScreenUtil so every component keeps the exact proportions of the spec.
class AppTokens {
  AppTokens._();

  // ── Radii ─────────────────────────────────────────────────────────────────

  static const double radiusSm = 12;

  /// Buttons, inputs.
  static const double radiusMd = 16;

  /// Cards and tiles.
  static const double radiusLg = 20;

  /// Sheets, dialogs, hero cards.
  static const double radiusXl = 28;

  /// Pills and chips.
  static const double radiusPill = 999;

  // ── Borders and 3D edges ──────────────────────────────────────────────────

  /// Every border is 2 px.
  static const double borderWidth = 2;

  /// Solid bottom edge under buttons.
  static const double buttonEdge = 4;

  /// Solid bottom edge under tiles and cards.
  static const double tileEdge = 3;

  /// Width of the keyboard focus ring (web: 3 px `green-bright`).
  static const double focusRingWidth = 3;

  // ── Spacing scale ─────────────────────────────────────────────────────────

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;

  /// Horizontal page gutter on mobile.
  static const double gutter = 20;

  // ── Sizes ─────────────────────────────────────────────────────────────────

  /// Minimum touch target for anything tappable.
  static const double minTouchTarget = 48;

  /// Total height (face + edge) of a medium `PressableButton`.
  static const double buttonHeight = 52;

  // ── Motion ────────────────────────────────────────────────────────────────

  /// Press-down of a 3D button (edge collapses).
  static const Duration pressDuration = Duration(milliseconds: 90);

  /// Spring back after a press.
  static const Duration releaseDuration = Duration(milliseconds: 180);

  /// Small state changes (colours, selection).
  static const Duration fast = Duration(milliseconds: 200);

  /// Default entrance / transition.
  static const Duration medium = Duration(milliseconds: 250);

  /// Larger transitions (screens, sheets).
  static const Duration slow = Duration(milliseconds: 300);

  /// Progress bars and rings.
  static const Duration progressDuration = Duration(milliseconds: 500);

  /// Numbers ticking up (XP, streak).
  static const Duration countDuration = Duration(milliseconds: 800);

  /// Delay between staggered entrance items.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Upper bound for the mascot's type-on text.
  static const Duration typeOnMax = Duration(milliseconds: 600);

  /// Confetti burst length.
  static const Duration confettiDuration = Duration(milliseconds: 1800);

  /// How long a toast stays on screen.
  static const Duration toastHold = Duration(seconds: 3);

  /// Distance entrances slide up from.
  static const double entranceOffset = 12;

  /// Default curve: everything that isn't a celebration.
  static const Curve curve = Curves.easeOutCubic;

  /// Delight curve: selection bounces, mascot. Never for plain UI.
  static const Curve bounceCurve = Curves.easeOutBack;

  /// Celebration curve (elastic scale-in).
  static const Curve elasticCurve = Curves.elasticOut;

  /// Whether the user asked the OS to reduce motion. When true: no confetti,
  /// no elastic/bouncy motion, no type-on, cross-fades only.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or [Duration.zero] when [reduceMotion] is on.
  static Duration motion(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}
