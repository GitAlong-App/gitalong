import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';
import 'app_tokens.dart';

/// Light and dark Material 3 themes for the "Play" design system.
///
/// Stock Material widgets are themed to sit next to the kit in
/// `lib/presentation/widgets/ui/`: flat surfaces, 2 px borders, Nunito, the
/// green brand colour and generous radii. The [AppPalette] extension is
/// installed on both themes (`context.palette`).
class AppTheme {
  AppTheme._();

  /// Light theme.
  static ThemeData get lightTheme => _build(AppPalette.light);

  /// Dark theme.
  static ThemeData get darkTheme => _build(AppPalette.dark);

  /// Slate-100: a visible fill for containers on a white page.
  static const Color _lightContainerHigh = Color(0xFFF1F5F9);

  static ThemeData _build(AppPalette p) {
    final brightness = p.brightness;
    final isDark = p.isDark;
    final greenText = AppTone.green.textOn(brightness);
    final errorColor = isDark ? AppColors.dangerBright : AppColors.dangerEdge;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.green,
      onPrimary: Colors.white,
      primaryContainer: p.greenTint,
      onPrimaryContainer: greenText,
      secondary: AppColors.purple,
      onSecondary: Colors.white,
      secondaryContainer: p.purpleTint,
      onSecondaryContainer: AppTone.purple.textOn(brightness),
      tertiary: isDark ? AppColors.sky : AppColors.skyEdge,
      onTertiary: isDark ? AppColors.ink : Colors.white,
      tertiaryContainer: p.skyTint,
      onTertiaryContainer: AppTone.sky.textOn(brightness),
      error: errorColor,
      onError: isDark ? AppColors.ink : Colors.white,
      errorContainer: p.dangerTint,
      onErrorContainer: AppTone.danger.textOn(brightness),
      surface: p.bg,
      onSurface: p.ink,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: isDark ? p.card : _lightContainerHigh,
      surfaceContainerHighest: isDark ? p.card : _lightContainerHigh,
      onSurfaceVariant: p.inkMuted,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? AppColors.darkInk : AppColors.ink,
      onInverseSurface: isDark ? AppColors.ink : Colors.white,
      inversePrimary: isDark ? AppColors.green : AppColors.greenBright,
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTextStyles.textTheme(ink: p.ink, muted: p.inkMuted);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
    );
    final buttonText = AppTextStyles.button(p.ink);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    const buttonMinSize = Size(64, AppTokens.buttonHeight);

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      disabledBackgroundColor: p.disabledFill,
      disabledForegroundColor: p.disabledText,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      minimumSize: buttonMinSize,
      padding: buttonPadding,
      shape: buttonShape,
      textStyle: buttonText,
    );

    OutlineInputBorder outline(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: color, width: AppTokens.borderWidth),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[p],
      textTheme: textTheme,
      // Text drawn on the primary (green) colour.
      primaryTextTheme: AppTextStyles.textTheme(
        ink: Colors.white,
        muted: Colors.white70,
      ),
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.border,
      iconTheme: IconThemeData(color: p.ink, size: 24),

      // Screens: slide in from the right; a cross-fade under reduced motion.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _GaPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _GaPageTransitionsBuilder(),
          TargetPlatform.linux: _GaPageTransitionsBuilder(),
          TargetPlatform.windows: _GaPageTransitionsBuilder(),
          // iOS and macOS keep the platform default (Cupertino slide with the
          // interactive back swipe).
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle:
            AppTextStyles.h3(p.ink).copyWith(fontWeight: FontWeight.w900),
        iconTheme: IconThemeData(color: p.ink, size: 24),
        actionsIconTheme: IconThemeData(color: p.ink, size: 24),
      ),

      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: p.border, width: AppTokens.borderWidth),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: AppTextStyles.body(p.inkSubtle),
        labelStyle: AppTextStyles.body(p.inkMuted),
        floatingLabelStyle: AppTextStyles.bodySm(p.inkMuted),
        helperStyle: AppTextStyles.bodySmall(p.inkMuted),
        errorStyle: AppTextStyles.bodySmall(errorColor),
        counterStyle: AppTextStyles.bodySmall(p.inkMuted),
        prefixIconColor: p.inkMuted,
        suffixIconColor: p.inkMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: outline(p.border),
        enabledBorder: outline(p.border),
        focusedBorder: outline(AppColors.greenBright),
        errorBorder: outline(AppColors.danger),
        focusedErrorBorder: outline(AppColors.danger),
        disabledBorder: outline(p.border.withValues(alpha: 0.6)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.disabledFill,
          disabledForegroundColor: p.disabledText,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          backgroundColor: p.card,
          disabledForegroundColor: p.disabledText,
          side: BorderSide(color: p.border, width: AppTokens.borderWidth),
          elevation: 0,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: greenText,
          disabledForegroundColor: p.disabledText,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: buttonShape,
          textStyle: AppTextStyles.titleMedium(greenText),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: p.greenTint,
        disabledColor: p.disabledFill,
        checkmarkColor: greenText,
        deleteIconColor: p.inkMuted,
        labelStyle: AppTextStyles.labelLarge(p.ink),
        secondaryLabelStyle: AppTextStyles.labelLarge(greenText),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.green
                : p.border,
            width: AppTokens.borderWidth,
          ),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
        brightness: brightness,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkInk : AppColors.ink,
        contentTextStyle:
            AppTextStyles.bodySm(isDark ? AppColors.ink : Colors.white),
        actionTextColor: isDark ? AppColors.greenEdge : AppColors.greenBright,
        closeIconColor: isDark ? AppColors.ink : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        modalBackgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: p.scrim,
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        dragHandleSize: const Size(40, 5),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusXl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: p.scrim,
        titleTextStyle: AppTextStyles.h2(p.ink),
        contentTextStyle: AppTextStyles.body(p.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          side: BorderSide(color: p.border, width: AppTokens.borderWidth),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: greenText,
        unselectedLabelColor: p.inkMuted,
        indicatorColor: AppColors.green,
        dividerColor: p.border,
        labelStyle: AppTextStyles.labelLarge(greenText),
        unselectedLabelStyle: AppTextStyles.labelLarge(p.inkMuted),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: p.bg,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.greenTint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: const BorderSide(
            color: AppColors.greenBright,
            width: AppTokens.borderWidth,
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? AppColors.green
                : p.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.labelMedium(
            states.contains(WidgetState.selected) ? greenText : p.inkMuted,
          ),
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? AppColors.green.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.inkMuted,
        textColor: p.ink,
        titleTextStyle: AppTextStyles.titleMedium(p.ink),
        subtitleTextStyle: AppTextStyles.bodyMedium(p.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppTextStyles.body(p.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: p.border, width: AppTokens.borderWidth),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.green,
        linearTrackColor: p.border,
        circularTrackColor: Colors.transparent,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.green,
        selectionColor: AppColors.greenBright.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.green,
      ),

      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: AppTokens.borderWidth,
        space: AppTokens.borderWidth,
      ),
    );
  }
}

/// Push transition: the new page slides in from the right while the old one
/// drifts left. Under reduced motion it is a plain cross-fade.
class _GaPageTransitionsBuilder extends PageTransitionsBuilder {
  const _GaPageTransitionsBuilder();

  static final Animatable<Offset> _enter = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: AppTokens.curve));

  static final Animatable<Offset> _exit = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.25, 0),
  ).chain(CurveTween(curve: AppTokens.curve));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppTokens.reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SlideTransition(
      position: secondaryAnimation.drive(_exit),
      child: SlideTransition(
        position: animation.drive(_enter),
        child: child,
      ),
    );
  }
}
