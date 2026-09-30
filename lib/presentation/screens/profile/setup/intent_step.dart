import 'package:flutter/material.dart';

import '../../../../core/constants/collab_constants.dart';
import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';
import 'setup_step_layout.dart';

/// Setup step 1: "What brings you here?" One multi-select OptionCard per
/// collaboration intent (`looking_for`).
class IntentStep extends StatelessWidget {
  const IntentStep({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });

  final int stepNumber;
  final int stepCount;

  /// Selected intent keys.
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// False while saving.
  final bool enabled;

  /// Art per intent key (docs/DESIGN_SYSTEM.md §5).
  static const Map<String, String> _art = {
    'cofounder': Illustrations.rocket,
    'side_project': Illustrations.hammerAndWrench,
    'open_source': Illustrations.globe,
    'hackathon': Illustrations.highVoltage,
    'mentor': Illustrations.graduationCap,
    'mentee': Illustrations.seedling,
  };

  /// One-line explanation per intent key.
  static const Map<String, String> _blurbs = {
    'cofounder': 'Start a company together',
    'side_project': 'Build something fun on nights and weekends',
    'open_source': 'Contribute to projects in the open',
    'hackathon': 'Team up and ship fast at events',
    'mentor': 'Share what you know with newer developers',
    'mentee': "Learn from someone who's been there",
  };

  @override
  Widget build(BuildContext context) {
    const intents = CollabConstants.intents;

    return SetupStepLayout(
      stepNumber: stepNumber,
      stepCount: stepCount,
      title: 'What brings you here?',
      subtitle: 'Pick all that apply. We match you with people who want the '
          'same thing.',
      children: [
        for (var i = 0; i < intents.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space12),
            child: setupEntrance(
              context,
              OptionCard(
                title: intents[i].label,
                subtitle: _blurbs[intents[i].key],
                illustration: _art[intents[i].key] ?? Illustrations.sparkles,
                selected: selected.contains(intents[i].key),
                onTap: enabled ? () => onToggle(intents[i].key) : null,
              ),
              i,
            ),
          ),
      ],
    );
  }
}
