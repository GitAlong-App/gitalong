import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../widgets/ui/ui.dart';

/// One statistic: illustration + big number, an UPPERCASE label and an
/// optional footer (a hint line or a progress bar). Read by screen readers
/// as the single [semanticLabel].
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.illustration,
    required this.value,
    required this.label,
    required this.semanticLabel,
    this.footer,
    this.grayscale = false,
  });

  final String illustration;
  final int value;
  final String label;
  final String semanticLabel;
  final Widget? footer;

  /// Desaturates the illustration (e.g. a streak not extended today).
  final bool grayscale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final numberStyle = AppTextStyles.h2(palette.ink);
    final footer = this.footer;

    return GaTile(
      padding: const EdgeInsets.all(14),
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Illustration(illustration, size: 30, grayscale: grayscale),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: value >= 10000
                      ? Text(compactCount(value), style: numberStyle)
                      : AnimatedCount(value: value, style: numberStyle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.caption(palette.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (footer != null) ...[
            const SizedBox(height: AppTokens.space8),
            footer,
          ],
        ],
      ),
    );
  }
}

/// 12345 → "12.3k", 2500000 → "2.5M"; smaller numbers unchanged.
String compactCount(int value) {
  String trim(double v) {
    final text = v.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (value >= 1000000) return '${trim(value / 1000000)}M';
  if (value >= 1000) return '${trim(value / 1000)}k';
  return '$value';
}

/// "1 day" / "3 days".
String plural(int count, String singular, [String? pluralForm]) =>
    '$count ${count == 1 ? singular : (pluralForm ?? '${singular}s')}';
