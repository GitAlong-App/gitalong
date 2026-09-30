import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/illustrations.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../widgets/ui/ui.dart';
import 'onboarding_flow/full_bleed_system_bars.dart';

/// Onboarding: three swipeable cards, each with a big illustration and Octo
/// explaining one idea, a progress-dots pill, and the two entry actions.
///
/// Both actions lead to sign-in (GitHub covers new and returning users);
/// the "seen" flag is persisted first because the router reads it on every
/// redirect.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingCard> _cards = [
    _OnboardingCard(
      illustration: Illustrations.rocket,
      accent: Illustrations.sparkles,
      tone: AppTone.green,
      title: "Say what you're building",
      octoSays: 'Co-founder, side project, open source, hackathon or '
          "mentoring: tell me why you're here and I'll find builders who "
          'want the same thing.',
    ),
    _OnboardingCard(
      illustration: Illustrations.laptop,
      accent: Illustrations.glowingStar,
      tone: AppTone.purple,
      title: 'Get matched on real GitHub work',
      octoSays: 'Your repos, stars and languages are your proof of work. I '
          'pair you with people whose skills complement yours.',
    ),
    _OnboardingCard(
      illustration: Illustrations.handshake,
      accent: Illustrations.partyPopper,
      tone: AppTone.gold,
      title: 'Know why you matched',
      octoSays: 'Every match shows why you fit, plus an opener to break the '
          'ice. Then go build something together!',
    ),
  ];

  bool get _isLastPage => _currentPage >= _cards.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    try {
      final box = await Hive.openBox(AppConstants.settingsBox);
      await box.put(AppConstants.hasSeenOnboardingKey, true);
    } catch (_) {
      // Worst case the onboarding shows again next time.
    }
  }

  Future<void> _goToLogin() async {
    // Persist first: the router reads this flag on every redirect.
    await _markSeen();
    if (!mounted) return;
    context.go(RoutePaths.login);
  }

  void _next() {
    if (_isLastPage) {
      _goToLogin();
      return;
    }
    final next = _currentPage + 1;
    if (AppTokens.reduceMotion(context)) {
      // Scroll animations need a non-zero duration; jump instead.
      _pageController.jumpToPage(next);
    } else {
      _pageController.nextPage(
        duration: AppTokens.slow,
        curve: AppTokens.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = AppTokens.reduceMotion(context);

    Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressableButton(
          label: _isLastPage ? 'Get started' : 'Continue',
          onPressed: _next,
        ),
        const SizedBox(height: AppTokens.space12),
        PressableButton(
          label: 'I already have an account',
          variant: PressableVariant.secondary,
          onPressed: _goToLogin,
        ),
      ],
    );
    if (!reduceMotion) {
      actions = actions
          .animate()
          .fadeIn(
            delay: AppTokens.stagger * 4,
            duration: AppTokens.medium,
            curve: AppTokens.curve,
          )
          .moveY(begin: AppTokens.entranceOffset, end: 0);
    }

    return FullBleedSystemBars(
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space12),
                child: _ProgressDots(
                  count: _cards.length,
                  current: _currentPage,
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _cards.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) => _OnboardingPage(
                    card: _cards[index],
                    animate: !reduceMotion,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.gutter,
                  AppTokens.space8,
                  AppTokens.gutter,
                  AppTokens.space16,
                ),
                child: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Content of one onboarding card.
class _OnboardingCard {
  const _OnboardingCard({
    required this.illustration,
    required this.accent,
    required this.tone,
    required this.title,
    required this.octoSays,
  });

  /// The big illustration in the hero disc.
  final String illustration;

  /// A small illustration floating at the disc's top-right.
  final String accent;

  /// Tint of the hero disc.
  final AppTone tone;

  final String title;

  /// Octo's first-person explanation, shown in the speech bubble.
  final String octoSays;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.card, required this.animate});

  final _OnboardingCard card;

  /// False under reduced motion.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Shrinks on short screens, so the text keeps room.
        final heroSize = math.min(
          220.0,
          math.max(140.0, constraints.maxHeight * 0.4),
        );

        Widget title = Semantics(
          header: true,
          child: Text(
            card.title,
            style: AppTextStyles.h1(p.ink),
            textAlign: TextAlign.center,
          ),
        );
        if (animate) {
          title = title
              .animate()
              .fadeIn(
                delay: AppTokens.stagger * 2,
                duration: AppTokens.medium,
                curve: AppTokens.curve,
              )
              .moveY(begin: AppTokens.entranceOffset, end: 0);
        }

        return SingleChildScrollView(
          // Neighbouring pages are built together while swiping: don't let
          // them share the PrimaryScrollController.
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppTokens.space8),
                _Hero(card: card, size: heroSize, animate: animate),
                const SizedBox(height: AppTokens.space24),
                title,
                const SizedBox(height: AppTokens.space20),
                MascotBubble(message: card.octoSays, mascotSize: 72),
                const SizedBox(height: AppTokens.space8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The big illustration on a tinted disc, with a small accent illustration.
class _Hero extends StatelessWidget {
  const _Hero({required this.card, required this.size, required this.animate});

  final _OnboardingCard card;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Widget art = Illustration(card.illustration, size: size * 0.58);
    if (animate) {
      // A gentle idle float.
      art = art
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(
            begin: -5,
            end: 5,
            duration: const Duration(milliseconds: 1800),
            curve: Curves.easeInOut,
          );
    }

    Widget hero = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              color: p.tint(card.tone),
              shape: BoxShape.circle,
              border: Border.all(
                color: card.tone.fill.withValues(alpha: 0.35),
                width: AppTokens.borderWidth,
              ),
            ),
          ),
          art,
          Positioned(
            top: size * 0.02,
            right: size * 0.04,
            child: Illustration(card.accent, size: size * 0.22),
          ),
        ],
      ),
    );

    if (animate) {
      hero = hero
          .animate()
          .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
          .scaleXY(
            begin: 0.85,
            end: 1,
            duration: AppTokens.slow,
            curve: AppTokens.bounceCurve,
          );
    }
    return hero;
  }
}

/// A pill with one dot per card: the current one a wide green bar (≥ 3:1 on
/// the pill), done dots bright green, upcoming ones grey.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final duration = AppTokens.motion(context, AppTokens.fast);

    return Semantics(
      label: 'Page ${current + 1} of $count',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: p.border, width: AppTokens.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: duration,
                curve: AppTokens.curve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == current ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i == current
                      ? AppColors.green
                      : i < current
                          ? AppColors.greenBright
                          : p.borderStrong,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
