import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../widgets/ui/ui.dart';

/// Privacy policy: a friendly header tile, then numbered sections.
///
/// Reachable signed out (from sign-in) and signed in (from Settings). The
/// text is selectable so people can copy the support address.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'Last updated: March 12, 2026';

  static const List<_LegalSection> _sections = [
    _LegalSection(
      title: 'Information We Collect',
      paragraphs: [
        'When you sign in with GitHub, we collect your public profile '
            'information including your username, display name, avatar, bio, '
            'location, company, email address, public repository metadata, '
            'and programming language usage statistics.',
        'We also collect usage data such as swipe activity, matches, and '
            'chat messages that you send through the app.',
      ],
    ),
    _LegalSection(
      title: 'How We Use Your Information',
      bullets: [
        'To create and manage your GitAlong profile.',
        'To generate personalised developer recommendations based on '
            'your languages, interests, and GitHub activity.',
        'To facilitate matches and real-time chat between users.',
        'To improve the app experience and fix issues.',
      ],
    ),
    _LegalSection(
      title: 'Data Sharing',
      paragraphs: [
        'Your public profile information is visible to other GitAlong '
            'users. We do not sell your personal data to third parties. We '
            'may share anonymised, aggregated data for analytics purposes.',
      ],
    ),
    _LegalSection(
      title: 'Data Storage & Security',
      paragraphs: [
        'Your data is stored securely in Supabase (hosted on AWS) with '
            'row-level security policies. Chat messages are transmitted via '
            'encrypted channels. We retain your data for as long as your '
            'account is active.',
      ],
    ),
    _LegalSection(
      title: 'Your Rights',
      paragraphs: [
        'You may view and edit your profile at any time. You can delete '
            'your account and all associated data from the Settings screen. '
            'Upon deletion, your profile, matches, and messages are '
            'permanently removed.',
      ],
    ),
    _LegalSection(
      title: 'Third-Party Services',
      paragraphs: [
        'GitAlong uses the GitHub API to retrieve your public profile '
            "and repository data. Your use of GitHub is subject to GitHub's "
            'own privacy policy. We also use Google Sign-In and Sign in with '
            'Apple as alternative authentication methods, each governed by '
            'their respective privacy policies.',
      ],
    ),
    _LegalSection(
      title: 'Changes to This Policy',
      paragraphs: [
        'We may update this privacy policy from time to time. We will '
            'notify you of significant changes via the app or email.',
      ],
    ),
    _LegalSection(
      title: 'Contact Us',
      paragraphs: [
        'If you have questions about this privacy policy, please contact '
            'us at support@gitalong.app.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        // Opened directly (e.g. from a link) there is nothing to pop: offer
        // a way out; the router sends people to sign-in or home.
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: 'Close',
                icon: const Icon(PhosphorIconsBold.x),
                onPressed: () => context.go(RoutePaths.splash),
              ),
      ),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.gutter,
              AppTokens.space8,
              AppTokens.gutter,
              AppTokens.space32,
            ),
            children: [
              const _LegalHeader(
                illustration: Illustrations.shield,
                summary: 'What we collect, how we use it, and the choices '
                    'you have.',
                lastUpdated: _lastUpdated,
              ),
              const SizedBox(height: AppTokens.space32),
              for (var i = 0; i < _sections.length; i++)
                _LegalSectionView(number: i + 1, section: _sections[i]),
            ],
          ),
        ),
      ),
    );
  }
}

/// One numbered section: paragraphs first, then bullets.
class _LegalSection {
  const _LegalSection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader({
    required this.illustration,
    required this.summary,
    required this.lastUpdated,
  });

  final String illustration;
  final String summary;
  final String lastUpdated;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GaTile(
      padding: const EdgeInsets.all(AppTokens.space20),
      child: Row(
        children: [
          Illustration(illustration, size: 56),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: AppTextStyles.h3(p.ink)),
                const SizedBox(height: AppTokens.space4),
                Text(lastUpdated, style: AppTextStyles.bodySm(p.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.number, required this.section});

  final int number;
  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bodyStyle = AppTextStyles.body(p.inkMuted);
    final bulletColor = p.toneText(AppTone.green);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label: '$number. ${section.title}',
            excludeSemantics: true,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.greenTint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: AppTextStyles.caption(bulletColor),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(section.title, style: AppTextStyles.h3(p.ink)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space12),
          for (final paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: Text(paragraph, style: bodyStyle),
            ),
          for (final bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: bodyStyle.copyWith(
                      color: bulletColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(child: Text(bullet, style: bodyStyle)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
