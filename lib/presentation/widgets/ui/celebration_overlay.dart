import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import 'animated_count.dart';
import 'confetti_burst.dart';
import 'illustration.dart';
import 'pressable_button.dart';

/// Full-screen celebration content: a confetti burst, a big illustration
/// that scales in elastically, a Display title, an optional "+N XP" counter
/// that ticks up, and a primary CTA (plus an optional ghost action).
///
/// Under reduced motion: no confetti, no elastic motion, just fades.
/// Usually shown with [showCelebration]; embed it directly to build a
/// celebration page.
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({
    super.key,
    required this.title,
    this.message,
    this.illustration = Illustrations.partyPopper,
    this.hero,
    this.xpGained = 0,
    required this.ctaLabel,
    required this.onCta,
    this.secondaryLabel,
    this.onSecondary,
    this.confetti = true,
  });

  final String title;
  final String? message;

  /// Illustration name (ignored when [hero] is set).
  final String illustration;

  /// Custom centrepiece, e.g. two avatars sliding together.
  final Widget? hero;

  /// Shows "+N XP" ticking up from 0 when > 0.
  final int xpGained;

  final String ctaLabel;
  final VoidCallback onCta;

  /// Optional low-emphasis action (ghost button), e.g. "Keep swiping".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final bool confetti;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduced = AppTokens.reduceMotion(context);
    final note = message;
    final secondary = secondaryLabel;

    Widget entrance(Widget child, int step) {
      if (reduced) {
        return child.animate().fadeIn(duration: AppTokens.medium);
      }
      return child
          .animate(delay: Duration(milliseconds: 120 + step * 80))
          .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
          .moveY(
            begin: AppTokens.entranceOffset,
            end: 0,
            duration: AppTokens.medium,
            curve: AppTokens.curve,
          );
    }

    Widget centrepiece = hero ?? Illustration(illustration, size: 168);
    centrepiece = reduced
        ? centrepiece.animate().fadeIn(duration: AppTokens.medium)
        : centrepiece
            .animate()
            .fadeIn(duration: AppTokens.fast)
            .scaleXY(
              begin: 0.3,
              end: 1,
              duration: const Duration(milliseconds: 900),
              curve: AppTokens.elasticCurve,
            );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        centrepiece,
        const SizedBox(height: AppTokens.space24),
        entrance(
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.display(p.ink),
              textAlign: TextAlign.center,
            ),
          ),
          0,
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space8),
          entrance(
            Text(
              note,
              style: AppTextStyles.body(p.inkMuted),
              textAlign: TextAlign.center,
            ),
            1,
          ),
        ],
        if (xpGained > 0) ...[
          const SizedBox(height: AppTokens.space20),
          entrance(_XpGain(xp: xpGained), 2),
        ],
      ],
    );

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        entrance(PressableButton(label: ctaLabel, onPressed: onCta), 3),
        if (secondary != null) ...[
          const SizedBox(height: AppTokens.space8),
          entrance(
            PressableButton(
              label: secondary,
              variant: PressableVariant.ghost,
              onPressed: onSecondary,
            ),
            4,
          ),
        ],
      ],
    );

    return Material(
      color: p.bg,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: AppTokens.space32),
                        content,
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppTokens.space32,
                            bottom: AppTokens.space16,
                          ),
                          child: actions,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (confetti && !reduced)
              const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }
}

class _XpGain extends StatefulWidget {
  const _XpGain({required this.xp});

  final int xp;

  @override
  State<_XpGain> createState() => _XpGainState();
}

class _XpGainState extends State<_XpGain> {
  Timer? _start;
  bool _counting = false;

  @override
  void initState() {
    super.initState();
    // Start ticking once the pill has faded in, so the count is seen.
    _start = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _counting = true);
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final xp = widget.xp;
    final showTotal = _counting || AppTokens.reduceMotion(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      decoration: BoxDecoration(
        color: p.goldTint,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: AppColors.gold, width: AppTokens.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Illustration(Illustrations.highVoltage, size: 24),
          const SizedBox(width: 6),
          AnimatedCount(
            from: 0,
            value: showTotal ? xp : 0,
            prefix: '+',
            suffix: ' XP',
            duration: AppTokens.countDuration,
            semanticsLabel: '+$xp XP',
            style: AppTextStyles.h2(p.toneText(AppTone.gold)),
          ),
        ],
      ),
    );
  }
}

/// Shows a full-screen [CelebrationOverlay] above everything and waits for
/// the user. Returns true if the primary CTA was pressed, false for the
/// secondary action or back.
///
/// ```dart
/// final sayHi = await showCelebration(
///   context,
///   title: "It's a match!",
///   illustration: Illustrations.handshake,
///   xpGained: 10,
///   ctaLabel: 'Say hi',
///   secondaryLabel: 'Keep swiping',
/// );
/// if (sayHi && context.mounted) context.push('/chats/$matchId');
/// ```
Future<bool> showCelebration(
  BuildContext context, {
  required String title,
  String? message,
  String illustration = Illustrations.partyPopper,
  Widget? hero,
  int xpGained = 0,
  String ctaLabel = 'Continue',
  String? secondaryLabel,
  bool confetti = true,
  bool haptics = true,
}) async {
  if (haptics) FeedbackService.mediumTap();
  // A second tap during the fade-out must not pop the screen underneath.
  var closed = false;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: AppTokens.slow,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      void close(bool value) {
        // Also ignore taps while the overlay is already leaving (e.g. after
        // the back button).
        if (closed || ModalRoute.isCurrentOf(dialogContext) == false) return;
        closed = true;
        Navigator.of(dialogContext).pop(value);
      }

      return CelebrationOverlay(
        title: title,
        message: message,
        illustration: illustration,
        hero: hero,
        xpGained: xpGained,
        ctaLabel: ctaLabel,
        onCta: () => close(true),
        secondaryLabel: secondaryLabel,
        onSecondary: secondaryLabel == null ? null : () => close(false),
        confetti: confetti,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: AppTokens.curve)),
        child: child,
      );
    },
  );
  return result ?? false;
}
