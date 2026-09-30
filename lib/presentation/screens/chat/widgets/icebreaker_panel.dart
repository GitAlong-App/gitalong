import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// The empty-chat state: a wave, a friendly nudge and icebreaker cards
/// (with a light bulb) that fill the composer when tapped.
class IcebreakerPanel extends StatelessWidget {
  const IcebreakerPanel({
    super.key,
    required this.name,
    required this.icebreakers,
    required this.loading,
    required this.onPick,
  });

  /// The other person's name.
  final String name;

  final List<String> icebreakers;

  /// The other profile is still loading: show placeholder cards.
  final bool loading;

  /// Null disables the cards (e.g. sending isn't possible yet).
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = AppTokens.reduceMotion(context);
    final pick = onPick;

    Widget wave = Illustration(Illustrations.wavingHand, size: 88);
    if (!reduceMotion) {
      wave = wave
          .animate(delay: const Duration(milliseconds: 250))
          .shake(
            hz: 2.5,
            rotation: 0.12,
            offset: Offset.zero,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
          );
    }

    final cards = <Widget>[];
    if (loading) {
      for (var i = 0; i < 3; i++) {
        cards.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.space12),
          child: GaSkeleton(height: 76, radius: AppTokens.radiusLg),
        ));
      }
    } else {
      for (var i = 0; i < icebreakers.length; i++) {
        final text = icebreakers[i];
        Widget card = OptionCard(
          title: text,
          illustration: Illustrations.lightBulb,
          illustrationSize: 40,
          selectionMode: OptionSelectionMode.none,
          onTap: pick == null ? null : () => pick(text),
        );
        if (!reduceMotion) {
          card = card
              .animate(delay: AppTokens.stagger * (i + 2))
              .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
              .moveY(
                begin: AppTokens.entranceOffset,
                end: 0,
                duration: AppTokens.medium,
                curve: AppTokens.curve,
              );
        }
        cards.add(Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.space12),
          child: card,
        ));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const vertical = AppTokens.space24;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            vertical,
            AppTokens.gutter,
            vertical,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? math.max(0.0, constraints.maxHeight - vertical * 2)
                  : 0.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: wave),
                const SizedBox(height: AppTokens.space12),
                Text(
                  'Say hi to $name!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2(palette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'You matched! The first message is the hardest, so here '
                  'are a few openers.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(palette.inkMuted),
                ),
                const SizedBox(height: AppTokens.space24),
                Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Illustration(Illustrations.speechBalloon, size: 22),
                      const SizedBox(width: AppTokens.space8),
                      Expanded(
                        child: Text(
                          'TAP AN ICEBREAKER TO USE IT',
                          semanticsLabel: 'Tap an icebreaker to use it',
                          style: AppTextStyles.caption(palette.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space12),
                if (loading)
                  Semantics(
                    label: 'Loading icebreakers',
                    child: ExcludeSemantics(child: Column(children: cards)),
                  )
                else
                  ...cards,
              ],
            ),
          ),
        );
      },
    );
  }
}
