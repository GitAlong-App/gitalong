import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/message_entity.dart';
import 'chat_format.dart';

/// One chat message.
///
/// Mine: a `green` bubble with white 17 px bold text (the design system's
/// rule for text on green) and a `green-edge` bottom edge. Theirs: a tile —
/// card fill, 2 px border and a 3 px `border-strong` edge. Consecutive
/// messages from one person are grouped: tighter corners on the sender's
/// side and the sent time under the last one only.
///
/// The content is shown verbatim; code-looking messages use JetBrains Mono
/// on a darker inset panel so they stay readable.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.senderName,
    required this.isGroupTop,
    required this.showTime,
    this.onLongPress,
  });

  final MessageEntity message;
  final bool isMine;

  /// The other person's name, for screen readers.
  final String senderName;

  /// First (visually top) message of a group from the same sender.
  final bool isGroupTop;

  /// Show the sent time under the bubble (last message of a group).
  final bool showTime;

  /// Long press, e.g. to copy the message.
  final VoidCallback? onLongPress;

  static const double _round = 20;
  static const double _tight = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = message.content;
    final isCode = looksLikeCode(content);
    final time = clockTime(context, message.sentAt);

    // The sender's side has a tight bottom corner (a small "tail") and a
    // tight top corner when the bubble continues a group.
    const round = Radius.circular(_round);
    const tight = Radius.circular(_tight);
    final radius = isMine
        ? BorderRadius.only(
            topLeft: round,
            bottomLeft: round,
            topRight: isGroupTop ? round : tight,
            bottomRight: tight,
          )
        : BorderRadius.only(
            topRight: round,
            bottomRight: round,
            topLeft: isGroupTop ? round : tight,
            bottomLeft: tight,
          );

    final fill = isMine ? AppColors.green : palette.card;
    final edge = isMine ? AppColors.greenEdge : palette.borderStrong;
    final textColor = isMine ? Colors.white : palette.ink;

    final Widget text;
    if (isCode) {
      text = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          // White mono text on green-edge is 5.4:1; ink on surface for theirs.
          color: isMine ? AppColors.greenEdge : palette.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Text(content, style: AppTextStyles.code(textColor)),
      );
    } else {
      text = Text(
        content,
        style: AppTextStyles.body(textColor).copyWith(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // Face over a same-shaped block in the edge colour: the 3D bottom edge.
    Widget bubble = DecoratedBox(
      decoration: BoxDecoration(color: edge, borderRadius: radius),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.tileEdge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: isMine
                ? null
                : Border.all(
                    color: palette.border,
                    width: AppTokens.borderWidth,
                  ),
          ),
          child: Padding(
            padding: isCode
                ? const EdgeInsets.all(6)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: text,
          ),
        ),
      ),
    );

    bubble = MergeSemantics(
      child: Semantics(
        label: '${isMine ? 'You' : senderName}, $time.',
        onLongPressHint: onLongPress == null ? null : 'Copy message',
        child: GestureDetector(
          onLongPress: onLongPress,
          child: bubble,
        ),
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.8, 560.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            bubble,
            if (showTime)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: ExcludeSemantics(
                  child: Text(
                    time,
                    style: AppTextStyles.bodySmall(palette.inkMuted)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Today" / "Yesterday" / date pill between days of messages.
class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = Expanded(
      child: Container(height: AppTokens.borderWidth, color: palette.border),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
      child: Semantics(
        header: true,
        label: label,
        excludeSemantics: true,
        child: Row(
          children: [
            line,
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                border: Border.all(
                  color: palette.border,
                  width: AppTokens.borderWidth,
                ),
              ),
              child: Text(
                label.toUpperCase(),
                style: AppTextStyles.caption(palette.inkMuted),
              ),
            ),
            line,
          ],
        ),
      ),
    );
  }
}
