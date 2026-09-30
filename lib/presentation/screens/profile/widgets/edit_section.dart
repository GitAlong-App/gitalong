import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// A group of related fields on the edit screen: a tile with an
/// illustration, a title, an optional subtitle and the fields. [errorText]
/// flags a problem that isn't a form field (e.g. no intent picked).
class EditSection extends StatelessWidget {
  const EditSection({
    super.key,
    required this.illustration,
    required this.title,
    this.subtitle,
    this.errorText,
    required this.child,
  });

  final String illustration;
  final String title;
  final String? subtitle;
  final String? errorText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subtitle = this.subtitle;
    final errorText = this.errorText;

    return GaTile(
      padding: const EdgeInsets.all(AppTokens.space16),
      borderColor: errorText == null ? null : AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Illustration(illustration, size: 36),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: AppTextStyles.h3(palette.ink)),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySm(palette.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          child,
          if (errorText != null) ...[
            const SizedBox(height: AppTokens.space8),
            InlineError(errorText),
          ],
        ],
      ),
    );
  }
}

/// An error line with an icon (never colour alone), announced to screen
/// readers when it appears.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.toneText(AppTone.danger);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(PhosphorIconsFill.warningCircle, size: 18, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm(color).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UPPERCASE caption above a text field, with an optional "optional" tag.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Text.rich(
        TextSpan(
          text: text.toUpperCase(),
          style: AppTextStyles.caption(palette.inkMuted),
          children: [
            if (optional)
              TextSpan(
                text: '  ·  OPTIONAL',
                style: AppTextStyles.caption(palette.inkMuted).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
