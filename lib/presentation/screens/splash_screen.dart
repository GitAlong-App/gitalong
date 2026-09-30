import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/illustrations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../widgets/ui/ui.dart';
import 'onboarding_flow/full_bleed_system_bars.dart';

/// Splash: Octo bounces in on `bg` above the GitAlong wordmark.
///
/// Purely visual. The GoRouter redirect (listening to AuthBloc) moves on as
/// soon as the session is resolved, so there is nothing to tap here.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Loading dots only appear if resolving the session takes a moment, so a
  /// fast start doesn't flash them.
  static const Duration _loaderDelay = Duration(milliseconds: 700);

  /// A friendly nudge when the session takes unusually long (bad network).
  static const Duration _slowHintDelay = Duration(seconds: 8);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = AppTokens.reduceMotion(context);

    Widget octo = const Illustration(Illustrations.mascot, size: 132);
    Widget wordmark = Text(
      AppConstants.appName,
      style: AppTextStyles.h1(AppColors.green),
      textAlign: TextAlign.center,
    );
    Widget tagline = Text(
      AppConstants.appDescription,
      style: AppTextStyles.body(p.inkMuted),
      textAlign: TextAlign.center,
    );

    if (reduceMotion) {
      // Cross-fades only.
      octo = octo
          .animate()
          .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve);
    } else {
      // Octo is the mascot, so it may bounce (elastic scale-in).
      octo = octo
          .animate()
          .fadeIn(duration: AppTokens.fast, curve: AppTokens.curve)
          .scaleXY(
            begin: 0.4,
            end: 1,
            duration: const Duration(milliseconds: 900),
            curve: AppTokens.elasticCurve,
          );
      wordmark = wordmark
          .animate()
          .fadeIn(
            delay: const Duration(milliseconds: 200),
            duration: AppTokens.medium,
            curve: AppTokens.curve,
          )
          .moveY(begin: AppTokens.entranceOffset, end: 0);
      tagline = tagline
          .animate()
          .fadeIn(
            delay: const Duration(milliseconds: 280),
            duration: AppTokens.medium,
            curve: AppTokens.curve,
          )
          .moveY(begin: AppTokens.entranceOffset, end: 0);
    }

    final loader = _LoadingDots(pulsing: !reduceMotion)
        .animate()
        .fadeIn(delay: _loaderDelay, duration: AppTokens.medium);

    final slowHint = Text(
      'Still connecting… check your internet connection.',
      style: AppTextStyles.bodySm(p.inkMuted),
      textAlign: TextAlign.center,
    ).animate().fadeIn(delay: _slowHintDelay, duration: AppTokens.slow);

    return FullBleedSystemBars(
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Center(
            // Scrolls instead of overflowing on tiny screens with large text.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.gutter,
                vertical: AppTokens.space24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  octo,
                  const SizedBox(height: AppTokens.space20),
                  wordmark,
                  const SizedBox(height: AppTokens.space8),
                  tagline,
                  const SizedBox(height: AppTokens.space40),
                  loader,
                  const SizedBox(height: AppTokens.space16),
                  slowHint,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three green dots hopping in turn (≥ 3:1 on `bg`). Static under reduced
/// motion.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.pulsing});

  /// Whether the dots pulse (false under reduced motion). Not named
  /// `animate`, which would hide flutter_animate's `.animate()` extension.
  final bool pulsing;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;
  static const double _dotSize = 10;
  static const double _hop = 8;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _LoadingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Upward offset of dot [index]: one hop per cycle, a third of a cycle
  /// after the previous dot.
  double _offsetFor(int index) {
    final phase = (_controller.value - index / _dotCount) % 1.0;
    if (phase >= 0.5) return 0;
    return -_hop * math.sin(phase * 2 * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        height: _dotSize + _hop * 2,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _dotCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Transform.translate(
                    offset: Offset(0, _offsetFor(i)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: _dotSize),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
