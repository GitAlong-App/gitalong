import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';
import 'setup_step_layout.dart';

/// Setup steps 2–4: a grid of selectable chips, an "Add your own" chip and a
/// running count of what's selected.
class ChipPickerStep extends StatelessWidget {
  const ChipPickerStep({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onAddCustom,
    required this.addLabel,
    this.optional = false,
    this.banner,
    this.enabled = true,
  });

  final int stepNumber;
  final int stepCount;
  final String title;
  final String subtitle;

  /// Every chip, in display order.
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// Opens the "Add your own" prompt.
  final VoidCallback onAddCustom;

  /// Label of the add chip, e.g. "Add a language".
  final String addLabel;

  /// Optional steps can be skipped with nothing selected.
  final bool optional;

  /// Shown above the chips, e.g. the GitHub import status.
  final Widget? banner;

  /// False while saving.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final banner = this.banner;
    final count = selected.length;

    final String status;
    if (count > 0) {
      status = '$count selected';
    } else if (optional) {
      status = 'Nothing selected yet. You can skip this one.';
    } else {
      status = 'Pick at least one to continue.';
    }

    return SetupStepLayout(
      stepNumber: stepNumber,
      stepCount: stepCount,
      title: title,
      subtitle: subtitle,
      optional: optional,
      children: [
        if (banner != null) ...[
          banner,
          const SizedBox(height: AppTokens.space16),
        ],
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space4,
          children: [
            for (final option in options)
              GaChip(
                label: option,
                selected: selected.contains(option),
                onTap: enabled ? () => onToggle(option) : null,
              ),
            GaChip(
              label: addLabel,
              icon: PhosphorIconsBold.plus,
              onTap: enabled ? onAddCustom : null,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space16),
        Text(status, style: AppTextStyles.bodySm(p.inkMuted)),
      ],
    );
  }
}
