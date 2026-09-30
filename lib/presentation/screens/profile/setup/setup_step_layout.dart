import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';

/// The shared layout of one profile-setup question: a "STEP 2 OF 5"
/// eyebrow, the question in H1, an optional hint and the answer area. The
/// whole step scrolls, so large text and small screens never clip.
class SetupStepLayout extends StatelessWidget {
  const SetupStepLayout({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.title,
    this.subtitle,
    this.optional = false,
    required this.children,
  });

  /// 1-based position of this step.
  final int stepNumber;
  final int stepCount;
  final String title;
  final String? subtitle;

  /// Adds "· OPTIONAL" to the eyebrow.
  final bool optional;

  /// The answer area.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subtitle = this.subtitle;
    final eyebrow =
        'STEP $stepNumber OF $stepCount${optional ? ' · OPTIONAL' : ''}';

    return ListView(
      // Two steps are on screen while they switch: don't let both attach to
      // the PrimaryScrollController.
      primary: false,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.gutter,
        AppTokens.space12,
        AppTokens.gutter,
        AppTokens.space32,
      ),
      children: [
        Text(eyebrow, style: AppTextStyles.caption(p.inkMuted)),
        const SizedBox(height: AppTokens.space8),
        Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.h1(p.ink)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTokens.space8),
          Text(subtitle, style: AppTextStyles.body(p.inkMuted)),
        ],
        const SizedBox(height: AppTokens.space24),
        ...children,
      ],
    );
  }
}

/// Fade + 12 px slide-up entrance, staggered by [index] × 40 ms. Returns
/// [child] untouched under reduced motion.
Widget setupEntrance(BuildContext context, Widget child, int index) {
  if (AppTokens.reduceMotion(context)) return child;
  return child
      .animate()
      .fadeIn(
        delay: AppTokens.stagger * index,
        duration: AppTokens.medium,
        curve: AppTokens.curve,
      )
      .moveY(begin: AppTokens.entranceOffset, end: 0);
}
