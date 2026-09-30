import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// A section title (H2) with an optional subtitle and an optional action
/// ("SEE ALL" in the link colour) or a custom [trailing] widget.
///
/// ```dart
/// SectionHeader(title: 'Achievements', actionLabel: 'See all', onAction: _openAll)
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Replaces the action button.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sub = subtitle;
    final label = actionLabel;
    final linkColor = p.toneText(AppTone.sky);

    Widget? end = trailing;
    if (end == null && label != null && onAction != null) {
      end = TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          foregroundColor: linkColor,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.caption(linkColor),
          semanticsLabel: label,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: AppTextStyles.h2(p.ink)),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: AppTextStyles.bodySm(p.inkMuted)),
                ],
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: 8), end],
        ],
      ),
    );
  }
}
