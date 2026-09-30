import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/usecases/progress/profile_strength.dart';
import '../../../widgets/ui/ui.dart';

/// "Complete your profile": strength ring, the checks still missing and a
/// CTA. Only shown while the profile is incomplete.
///
/// The CTA opens Edit profile, except when only the photo is missing: that
/// comes from GitHub, so it offers a GitHub refresh instead.
class ProfileChecklistTile extends StatelessWidget {
  const ProfileChecklistTile({
    super.key,
    required this.done,
    required this.total,
    required this.missing,
    required this.onEdit,
    required this.onRefreshGitHub,
    this.refreshingGitHub = false,
    this.showXpReward = false,
  });

  final int done;
  final int total;

  /// The checks still to do, in spec order.
  final List<ProfileCheck> missing;
  final VoidCallback onEdit;
  final VoidCallback onRefreshGitHub;
  final bool refreshingGitHub;

  /// Mention the one-off XP bonus for a complete profile (only when the
  /// progress system is available).
  final bool showXpReward;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();
    final onlyPhoto =
        missing.length == 1 && missing.first.key == ProfileChecks.avatar;

    return GaTile(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: value,
                size: 56,
                strokeWidth: 6,
                semanticLabel: 'Profile strength',
                semanticValue: '$done of $total done',
                child: ExcludeSemantics(
                  child: Text(
                    '$done/$total',
                    style: AppTextStyles.caption(palette.ink),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Complete your profile',
                        style: AppTextStyles.h3(palette.ink),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A complete profile helps the right builders find you.',
                      style: AppTextStyles.bodySm(palette.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          for (final check in missing) _ChecklistRow(check: check),
          if (showXpReward) ...[
            const SizedBox(height: AppTokens.space8),
            Row(
              children: [
                Illustration(Illustrations.highVoltage, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Finish it for +50 XP',
                    style: AppTextStyles.bodySm(palette.toneText(AppTone.gold))
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTokens.space16),
          if (onlyPhoto)
            PressableButton(
              label: 'Refresh from GitHub',
              icon: PhosphorIconsBold.arrowClockwise,
              loading: refreshingGitHub,
              onPressed: onRefreshGitHub,
            )
          else
            PressableButton(
              label: 'Finish my profile',
              icon: PhosphorIconsBold.pencilSimple,
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.check});

  final ProfileCheck check;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hint = check.hint.trim();

    return MergeSemantics(
      child: Semantics(
        label: 'To do:',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  PhosphorIconsBold.circle,
                  size: 22,
                  color: palette.inkSubtle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(check.label, style: AppTextStyles.body(palette.ink)),
                    if (hint.isNotEmpty)
                      Text(hint, style: AppTextStyles.bodySm(palette.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
