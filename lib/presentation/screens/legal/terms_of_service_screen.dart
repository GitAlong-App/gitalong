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

/// Terms of service: a friendly header tile, then numbered sections.
///
/// Reachable signed out (from sign-in) and signed in (from Settings). The
/// text is selectable.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const String _lastUpdated = 'Last updated: March 12, 2026';

  static const List<_LegalSection> _sections = [
    _LegalSection(
      title: 'Service Description',
      paragraphs: [
        'GitAlong is a developer-matching platform that connects '
            'software developers based on shared programming languages, '
            'interests, and GitHub activity. The service is provided '
            '"as is" and is intended for personal, non-commercial use.',
      ],
    ),
    _LegalSection(
      title: 'Eligibility',
      paragraphs: [
        'You must be at least 13 years of age to use GitAlong. By '
            'creating an account, you represent that you meet this '
            'requirement and have the authority to agree to these terms.',
      ],
    ),
    _LegalSection(
      title: 'User Accounts',
      paragraphs: [
        'You are responsible for maintaining the security of your '
            'account. You may not impersonate another person or create '
            'multiple accounts. We reserve the right to suspend or '
            'terminate accounts that violate these terms.',
      ],
    ),
    _LegalSection(
      title: 'Acceptable Use',
      paragraphs: ['You agree not to:'],
      bullets: [
        'Harass, abuse, or threaten other users.',
        'Post spam, misleading content, or malicious links.',
        'Attempt to reverse-engineer or exploit the service.',
        'Use the platform for any illegal activity.',
        'Scrape or bulk-collect user data.',
      ],
    ),
    _LegalSection(
      title: 'Content & Intellectual Property',
      paragraphs: [
        'You retain ownership of the content you submit (profile info, '
            'messages). By submitting content, you grant GitAlong a limited '
            "licence to display it within the service. GitAlong's branding, "
            'design, and code remain our intellectual property.',
      ],
    ),
    _LegalSection(
      title: 'Termination',
      paragraphs: [
        'You may delete your account at any time from the Settings '
            'screen. We may also suspend or terminate your access if you '
            'violate these terms, with or without prior notice.',
      ],
    ),
    _LegalSection(
      title: 'Disclaimers',
      paragraphs: [
        'GitAlong is provided "as is" without warranty of any kind. We '
            'do not guarantee uninterrupted service, the accuracy of '
            'recommendations, or the behaviour of other users.',
      ],
    ),
    _LegalSection(
      title: 'Limitation of Liability',
      paragraphs: [
        'To the maximum extent permitted by law, GitAlong shall not be '
            'liable for any indirect, incidental, special, or consequential '
            'damages arising from your use of the service.',
      ],
    ),
    _LegalSection(
      title: 'Changes to These Terms',
      paragraphs: [
        'We may update these terms from time to time. Continued use of '
            'the app after changes are posted constitutes acceptance of the '
            'revised terms.',
      ],
    ),
    _LegalSection(
      title: 'Contact',
      paragraphs: [
        'For questions about these terms, contact us at '
            'support@gitalong.app.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
                illustration: Illustrations.memo,
                summary: 'The rules for using GitAlong, and what you can '
                    'expect from us.',
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
