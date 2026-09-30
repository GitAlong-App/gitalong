import 'package:flutter/material.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../widgets/ui/ui.dart';

/// Gold banner tile above the stack: "3 builders already liked you". It
/// never reveals who (the count comes from `get_likes_received_count`).
class LikesTeaserBanner extends StatelessWidget {
  const LikesTeaserBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final who = count == 1 ? '1 builder' : '$count builders';
    return GaTile(
      tone: AppTone.gold,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      semanticLabel: '$who already liked you. Keep swiping to find them.',
      child: Row(
        children: [
          const Illustration(Illustrations.sparklingHeart, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$who already liked you. ',
                    style: AppTextStyles.titleSmall(p.ink),
                  ),
                  TextSpan(
                    text: 'Keep swiping!',
                    style: AppTextStyles.bodySm(p.inkMuted),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
