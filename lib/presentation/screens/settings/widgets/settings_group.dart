import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../widgets/ui/ui.dart';

/// Rows grouped in one rounded tile, separated by 2 px dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GaTile(
      // Rows sit just inside the 2 px border, and their highlights are
      // clipped to its inner corners.
      padding: const EdgeInsets.all(AppTokens.borderWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppTokens.radiusLg - AppTokens.borderWidth,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: AppTokens.borderWidth,
                    thickness: AppTokens.borderWidth,
                    color: palette.border,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One settings row: leading art, title, optional subtitle and a trailing
/// widget (a chevron by default when tappable). Read as a single item.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isToggle = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// The trailing widget is a switch: the row reads as a toggle, not a
  /// button.
  final bool isToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subtitle = this.subtitle;
    final leading = this.leading;
    final onTap = this.onTap;
    final trailing = this.trailing ??
        (onTap == null
            ? null
            : Icon(
                PhosphorIconsBold.caretRight,
                size: 20,
                color: palette.inkSubtle,
              ));

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space12,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 36, child: Center(child: leading)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body(palette.ink).copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySm(palette.inkMuted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTokens.space12),
              trailing,
            ],
          ],
        ),
      ),
    );

    if (onTap != null) {
      row = InkWell(
        onTap: () {
          FeedbackService.lightTap();
          onTap();
        },
        highlightColor: palette.surface,
        splashColor: palette.border.withValues(alpha: 0.5),
        child: row,
      );
    }

    return MergeSemantics(
      child: Semantics(button: onTap != null && !isToggle, child: row),
    );
  }
}

/// A [SettingsRow] with a brand switch; tapping anywhere on the row toggles.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      leading: leading,
      isToggle: true,
      trailing: BrandSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }
}

/// A Material switch in brand colours: green track with a check when on,
/// neutral with a cross when off (never colour alone).
class BrandSwitch extends StatelessWidget {
  const BrandSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onChanged = this.onChanged;

    return Switch(
      value: value,
      onChanged: onChanged == null
          ? null
          : (next) {
              FeedbackService.selectionTick();
              onChanged(next);
            },
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) return palette.disabledFill;
        return states.contains(WidgetState.selected)
            ? Colors.white
            : palette.inkMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.green
            : palette.surface,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.greenEdge
            : palette.borderStrong,
      ),
      thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
        (states) => states.contains(WidgetState.selected)
            ? const Icon(Icons.check_rounded, size: 16, color: AppColors.green)
            : Icon(Icons.close_rounded, size: 16, color: palette.card),
      ),
    );
  }
}

/// A round tinted badge with an icon, the size of a row illustration.
class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({
    super.key,
    required this.icon,
    this.tone = AppTone.purple,
  });

  final IconData icon;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: palette.tint(tone),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: palette.toneText(tone)),
    );
  }
}
