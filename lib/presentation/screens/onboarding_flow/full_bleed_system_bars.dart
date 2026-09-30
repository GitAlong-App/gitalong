import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_palette.dart';

/// Keeps the system bars readable on the full-bleed entry screens (splash,
/// onboarding, sign-in, profile setup), which have no app bar to set them
/// from the theme: dark icons on the light page, light icons in dark mode,
/// and a navigation bar that matches `bg`.
class FullBleedSystemBars extends StatelessWidget {
  const FullBleedSystemBars({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base =
        p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: base.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
        systemNavigationBarIconBrightness:
            p.isDark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
