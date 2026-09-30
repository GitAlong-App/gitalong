import 'package:flutter/material.dart';

import '../../../../core/constants/collab_constants.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/user_entity.dart';
import '../../../widgets/ui/ui.dart';
import 'intent_art.dart';

/// Intent, tech-stack, wanted-skills and interest chips in one tile.
/// Renders nothing when the profile has none of them.
class ProfileAboutTile extends StatelessWidget {
  const ProfileAboutTile({super.key, required this.user});

  final UserEntity user;

  /// Languages shown before collapsing the rest into a "+N" chip.
  static const int _maxLanguages = 12;

  static bool hasContent(UserEntity user) =>
      user.lookingFor.any(CollabConstants.isValidIntent) ||
      user.languages.isNotEmpty ||
      user.seekingSkills.isNotEmpty ||
      user.interests.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final intents = user.lookingFor
        .map(CollabConstants.intentFor)
        .whereType<CollabIntent>()
        .toList();
    final languages = user.languages.take(_maxLanguages).toList();
    final hiddenLanguages = user.languages.length - languages.length;

    final groups = <Widget>[
      if (intents.isNotEmpty)
        _ChipGroup(
          title: 'Looking for',
          chips: [
            for (final intent in intents)
              GaChip(
                label: intent.label,
                illustration: intentIllustration(intent.key),
              ),
          ],
        ),
      if (languages.isNotEmpty)
        _ChipGroup(
          title: 'Tech stack',
          chips: [
            for (final language in languages) GaChip(label: language),
            if (hiddenLanguages > 0)
              GaChip(
                label: '+$hiddenLanguages',
                semanticLabel: '$hiddenLanguages more languages',
              ),
          ],
        ),
      if (user.seekingSkills.isNotEmpty)
        _ChipGroup(
          title: 'Skills I want in a partner',
          chips: [
            for (final skill in user.seekingSkills) GaChip(label: skill),
          ],
        ),
      if (user.interests.isNotEmpty)
        _ChipGroup(
          title: 'Interests',
          chips: [
            for (final interest in user.interests) GaChip(label: interest),
          ],
        ),
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return GaTile(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTokens.space20),
            groups[i],
          ],
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.caption(palette.inkMuted),
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: chips,
        ),
      ],
    );
  }
}
