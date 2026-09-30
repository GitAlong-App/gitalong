import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/ui/ui.dart';
import '../onboarding_flow/full_bleed_system_bars.dart';

/// Sign-in: Octo says hi, one big "Continue with GitHub" button and the
/// legal caption.
///
/// Signing in opens GitHub in the browser; the OAuth deep link brings the
/// session back, AuthBloc emits [AuthAuthenticated] and the router moves on
/// (to profile setup or home). This screen only tracks the waiting state.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Waiting for the browser round trip.
  bool _loading = false;

  void _signInWithGitHub() {
    if (_loading) return;
    setState(() => _loading = true);
    context.read<AuthBloc>().add(SignInWithGitHubEvent());
  }

  /// The browser may be dismissed without a callback: let the user retry.
  void _cancel() => setState(() => _loading = false);

  void _onAuthState(BuildContext context, AuthState state) {
    if (state is AuthError) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    } else if (state is AuthAuthenticated || state is AuthUnauthenticated) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = AppTokens.reduceMotion(context);

    Widget entrance(Widget child, int index) {
      if (reduceMotion) return child;
      return child
          .animate()
          .fadeIn(
            delay: AppTokens.stagger * index,
            duration: AppTokens.medium,
            curve: AppTokens.curve,
          )
          .moveY(begin: AppTokens.entranceOffset, end: 0);
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: _onAuthState,
      child: FullBleedSystemBars(
        child: Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand, Octo and the promise.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppTokens.space24),
                          entrance(
                            Text(
                              AppConstants.appName,
                              // AA-safe green: H2 can drop below large-text
                              // size on small phones.
                              style:
                                  AppTextStyles.h2(p.toneText(AppTone.green)),
                            ),
                            0,
                          ),
                          const SizedBox(height: AppTokens.space32),
                          // Animates itself (Octo bounces, the text types on).
                          MascotBubble(
                            message: "Hi! I'm Octo. Let's find your people.",
                            mascotSize: 96,
                          ),
                          const SizedBox(height: AppTokens.space32),
                          entrance(
                            Semantics(
                              header: true,
                              child: Text(
                                AppConstants.appDescription,
                                style: AppTextStyles.h1(p.ink),
                              ),
                            ),
                            2,
                          ),
                          const SizedBox(height: AppTokens.space12),
                          entrance(
                            Text(
                              'Sign in with GitHub and your repos, stars and '
                              'languages become your developer card.',
                              style: AppTextStyles.body(p.inkMuted),
                            ),
                            3,
                          ),
                        ],
                      ),
                      // Sign-in and the legal caption.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppTokens.space32),
                          entrance(
                            PressableButton(
                              label: 'Continue with GitHub',
                              variant: PressableVariant.ink,
                              icon: PhosphorIconsFill.githubLogo,
                              size: PressableSize.large,
                              loading: _loading,
                              onPressed: _signInWithGitHub,
                            ),
                            4,
                          ),
                          AnimatedSize(
                            duration:
                                AppTokens.motion(context, AppTokens.fast),
                            curve: AppTokens.curve,
                            alignment: Alignment.topCenter,
                            child: _loading
                                ? _WaitingForBrowser(onCancel: _cancel)
                                : const SizedBox(width: double.infinity),
                          ),
                          const SizedBox(height: AppTokens.space16),
                          entrance(const _LegalCaption(), 5),
                          const SizedBox(height: AppTokens.space8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown under the button while the GitHub page is open in the browser.
class _WaitingForBrowser extends StatelessWidget {
  const _WaitingForBrowser({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTokens.space12),
        Semantics(
          container: true,
          liveRegion: true,
          child: Text(
            'Finish signing in on GitHub in your browser, then come back here.',
            style: AppTextStyles.bodySm(p.inkMuted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        PressableButton(
          label: 'Cancel',
          variant: PressableVariant.ghost,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

/// "By continuing, you agree to our Terms of Service and Privacy Policy",
/// with both documents as real buttons (48 px targets) rather than tiny
/// inline links.
class _LegalCaption extends StatelessWidget {
  const _LegalCaption();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final linkColor = p.toneText(AppTone.green);
    final linkStyle = TextButton.styleFrom(
      foregroundColor: linkColor,
      minimumSize: const Size(
        AppTokens.minTouchTarget,
        AppTokens.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
      textStyle: AppTextStyles.bodySm(linkColor).copyWith(
        fontWeight: FontWeight.w800,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
    );
    final captionStyle = AppTextStyles.bodySm(p.inkMuted);

    return Column(
      children: [
        Text(
          'By continuing, you agree to our',
          style: captionStyle,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              style: linkStyle,
              onPressed: () => context.push(RoutePaths.termsOfService),
              child: const Text('Terms of Service'),
            ),
            Text('and', style: captionStyle),
            TextButton(
              style: linkStyle,
              onPressed: () => context.push(RoutePaths.privacyPolicy),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }
}
