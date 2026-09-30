import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/feedback_service.dart';
import '../../../../domain/entities/match_entity.dart';
import '../../../widgets/ui/ui.dart';
import '../../chat/widgets/chat_avatar.dart';
import '../../chat/widgets/chat_format.dart';

/// A new match (no messages yet) in the "New matches" row: the avatar in a
/// green ring with a sparkle, and the first name under it. Tapping opens
/// the chat.
class NewMatchAvatar extends StatefulWidget {
  const NewMatchAvatar({super.key, required this.match, required this.onTap});

  final MatchEntity match;
  final VoidCallback onTap;

  /// Width of one item.
  static const double itemWidth = 84;

  static const double _ringSize = 72;
  static const double _verticalPadding = 8;
  static const double _gap = 6;

  /// Height of one item at the current text scale (for the horizontal
  /// list, which needs a fixed height).
  static double heightFor(BuildContext context) {
    final nameLine = MediaQuery.textScalerOf(context).scale(14.sp) * 1.45;
    return _verticalPadding * 2 + _ringSize + _gap + nameLine + 4;
  }

  @override
  State<NewMatchAvatar> createState() => _NewMatchAvatarState();
}

class _NewMatchAvatarState extends State<NewMatchAvatar> {
  bool _pressed = false;

  void _handleTap() {
    FeedbackService.lightTap();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = AppTokens.reduceMotion(context);
    final user = widget.match.user;
    final name = displayNameOf(user);

    // ProgressRing insets its child by strokeWidth + 4 on each side.
    const stroke = 4.0;
    final ring = Stack(
      clipBehavior: Clip.none,
      children: [
        ProgressRing(
          value: 1,
          size: NewMatchAvatar._ringSize,
          strokeWidth: stroke,
          tone: AppTone.green,
          animateOnMount: !reduceMotion,
          child: ChatAvatar(
            name: name,
            imageUrl: user.avatarUrl,
            size: NewMatchAvatar._ringSize - 2 * (stroke + 4),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Illustration(Illustrations.sparkles, size: 24),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: 'New match: $name. Say hi',
      excludeSemantics: true,
      onTap: _handleTap,
      child: InkWell(
        onTap: _handleTap,
        onHighlightChanged: (value) {
          if (value != _pressed) setState(() => _pressed = value);
        },
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: SizedBox(
          width: NewMatchAvatar.itemWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: NewMatchAvatar._verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _pressed && !reduceMotion ? 0.92 : 1,
                  duration: AppTokens.fast,
                  curve: AppTokens.curve,
                  child: ring,
                ),
                const SizedBox(height: NewMatchAvatar._gap),
                Text(
                  firstNameOf(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm(palette.ink)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
