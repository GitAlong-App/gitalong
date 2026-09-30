import 'package:flutter/material.dart';

import '../../../../core/constants/illustrations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../domain/entities/match_entity.dart';
import '../../../widgets/ui/ui.dart';
import 'chat_avatar.dart';
import 'chat_format.dart';

/// Whether [match] has a message the signed-in user hasn't read.
///
/// `MatchEntity.isRead` already applies the contract rule (last message from
/// the other person and `is_read == false`); a match without messages is
/// never unread.
bool isMatchUnread(MatchEntity match) =>
    !match.isRead && match.lastMessage != null;

/// Newest activity first: the last message, or the match itself.
int compareByRecency(MatchEntity a, MatchEntity b) {
  final aTime = a.lastMessageAt ?? a.matchedAt;
  final bTime = b.lastMessageAt ?? b.matchedAt;
  return bTime.compareTo(aTime);
}

/// One conversation in the Matches and Chats lists: avatar, name, the last
/// message (or a nudge to say hi), relative time and an unread pill.
///
/// Unread rows get a green border and edge, bold text and a NEW pill.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.match,
    required this.onTap,
    this.myUserId,
  });

  final MatchEntity match;
  final VoidCallback onTap;

  /// The signed-in user's id, to prefix your own last message with "You:".
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = palette.toneText(AppTone.green);
    final name = displayNameOf(match.user);
    final unread = isMatchUnread(match);
    final lastMessage = match.lastMessage;
    final me = myUserId;
    final sentByMe = lastMessage != null &&
        me != null &&
        me.isNotEmpty &&
        match.lastMessageSenderId == me;
    final time = match.lastMessageAt ?? match.matchedAt;
    final preview = lastMessage == null
        ? 'New match! Say hi'
        : '${sentByMe ? 'You: ' : ''}${previewLine(lastMessage)}';

    final semanticLabel = [
      name,
      if (unread) 'Unread message',
      lastMessage == null ? 'New match, no messages yet' : preview,
      longRelativeTime(context, time),
    ].join('. ');

    final TextStyle previewStyle;
    if (unread) {
      previewStyle =
          AppTextStyles.bodySm(palette.ink).copyWith(fontWeight: FontWeight.w800);
    } else if (lastMessage == null) {
      previewStyle =
          AppTextStyles.bodySm(accent).copyWith(fontWeight: FontWeight.w700);
    } else {
      previewStyle = AppTextStyles.bodySm(palette.inkMuted);
    }

    return GaTile(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: unread ? AppColors.green : null,
      edgeColor: unread ? AppColors.greenEdge : null,
      semanticLabel: semanticLabel,
      child: Row(
        children: [
          ChatAvatar(name: name, imageUrl: match.user.avatarUrl, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3(palette.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      shortRelativeTime(context, time),
                      style: AppTextStyles.bodySmall(
                        unread ? accent : palette.inkMuted,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (lastMessage == null) ...[
                      Illustration(Illustrations.wavingHand, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: previewStyle,
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      const UnreadPill(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small "NEW" pill for unread conversations.
///
/// The match list only knows *whether* something is unread, not how many
/// messages, so this shows a label instead of a count. Green tint with a
/// green border and AA-contrast green text in both themes.
class UnreadPill extends StatelessWidget {
  const UnreadPill({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: palette.greenTint,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: AppColors.green,
            width: AppTokens.borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'NEW',
              style: AppTextStyles.caption(palette.toneText(AppTone.green)),
            ),
          ],
        ),
      ),
    );
  }
}
