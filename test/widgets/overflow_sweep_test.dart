import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/achievements.dart';
import 'package:gitalong/core/constants/illustrations.dart';
import 'package:gitalong/core/theme/app_colors.dart';
import 'package:gitalong/core/theme/app_tokens.dart';
import 'package:gitalong/domain/entities/progress_entity.dart';
import 'package:gitalong/presentation/bloc/progress/progress_state.dart';
import 'package:gitalong/presentation/screens/chat/widgets/conversation_tile.dart';
import 'package:gitalong/presentation/screens/chat/widgets/icebreaker_panel.dart';
import 'package:gitalong/presentation/screens/chat/widgets/message_bubble.dart';
import 'package:gitalong/presentation/screens/profile/widgets/equal_height_row.dart';
import 'package:gitalong/presentation/screens/profile/widgets/stat_tile.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/discover_header.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/likes_teaser_banner.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

/// Small phone at the default and at a large text scale.
const List<({Size size, double scale})> _configs = [
  (size: kSmallPhone, scale: 1.0),
  (size: kSmallPhone, scale: 1.5),
  (size: kDesignSize, scale: 2.0),
];

/// Pumps [build] (in a gutter, vertically scrollable unless [scroll] is
/// false) for every config and fails on any exception, e.g. a RenderFlex
/// overflow.
void sweep(String name, Widget Function() build, {bool scroll = true}) {
  for (final config in _configs) {
    final label = '${config.size.width.toInt()}x${config.size.height.toInt()}'
        ' @${config.scale}x';
    testWidgets('$name fits at $label', (tester) async {
      await pumpApp(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
          child: build(),
        ),
        surfaceSize: config.size,
        textScale: config.scale,
        scrollable: scroll,
      );
      expectNoExceptions(tester, reason: '$name at $label');
      await settle(tester, total: const Duration(milliseconds: 1500));
      expectNoExceptions(tester, reason: '$name at $label (after animations)');
    });
  }
}

const String _longText =
    'Collaborating on an open-source distributed database written in Rust';

void main() {
  group('overflow sweep: UI kit', () {
    sweep(
      'PressableButton (two in a row, long labels, icons)',
      () => Row(
        children: [
          Expanded(
            child: PressableButton(
              label: 'Continue with GitHub account',
              icon: Icons.code,
              trailingIcon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PressableButton(
              label: 'Maybe later please',
              variant: PressableVariant.secondary,
              size: PressableSize.small,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );

    sweep(
      'GaChip wrap',
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          GaChip(label: 'Open-source collaborators', onTap: () {}),
          GaChip(
            label: _longText,
            illustration: Illustrations.rocket,
            selected: true,
            onRemove: () {},
            onTap: () {},
          ),
          const GaChip(label: 'TypeScript', icon: Icons.code, uppercase: false),
        ],
      ),
    );

    sweep(
      // Each chip must fit on its own; the Discover header (swept below)
      // covers how the app lays them out side by side.
      'Streak, XP and level chips (big numbers)',
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StreakChip(days: 365, activeToday: true, onTap: () {}),
          XpChip(xp: 123456, onTap: () {}),
          const LevelBadge(level: 42),
        ],
      ),
    );

    sweep(
      'EmptyState',
      () => EmptyState(
        illustration: Illustrations.thinkingFace,
        title: 'No builders match your filters right now',
        message: '$_longText. Want to widen your filters and look again?',
        actionLabel: 'Widen my filters',
        onAction: () {},
      ),
    );

    sweep(
      'OptionCard (long title and subtitle, selected)',
      () => OptionCard(
        title: 'Side-project partner for weekends',
        subtitle: _longText,
        illustration: Illustrations.hammerAndWrench,
        selected: true,
        onTap: () {},
      ),
    );

    sweep(
      'GaSegmentedTabs (three long labels)',
      () => GaSegmentedTabs(
        labels: const ['New matches', 'All conversations', 'Archived'],
        selectedIndex: 1,
        onChanged: (_) {},
      ),
    );

    sweep(
      'SectionHeader (long title and action)',
      () => SectionHeader(
        title: 'Achievements you have unlocked so far',
        subtitle: '3 of 10 unlocked, keep going',
        actionLabel: 'See all',
        onAction: () {},
      ),
    );

    sweep(
      'MascotBubble',
      () => const MascotBubble(
        message: "Hi! I'm Octo. $_longText? Let's find your people.",
      ),
    );

    sweep(
      'GaToast',
      () => const GaToast(
        eyebrow: 'Achievement unlocked',
        title: 'Real talk: a very long achievement title here',
        message: _longText,
        tone: AppTone.gold,
      ),
    );

    sweep(
      'AchievementTiles three per row',
      () => EqualHeightRow(
        spacing: AppTokens.space12,
        children: [
          for (final a in Achievements.all.take(3))
            AchievementTile(
              achievement: a,
              unlocked: a.key == Achievements.firstSwipe,
              isNew: true,
              showDescription: false,
              onTap: () {},
            ),
        ],
      ),
    );

    sweep(
      'Progress bar and ring',
      () => const Column(
        children: [
          GaProgressBar(value: 0.6),
          SizedBox(height: 12),
          ProgressRing(value: 0.4, size: 56, child: Text('3/8')),
        ],
      ),
    );
  });

  group('overflow sweep: screen pieces', () {
    sweep(
      'DiscoverHeader (loaded, big numbers)',
      () => const DiscoverHeader(
        progress: ProgressLoaded(
          progress: ProgressEntity(
            streakDays: 365,
            activeToday: true,
            xp: 123456,
            todaySwipes: 7,
            level: 42,
          ),
        ),
      ),
    );

    sweep(
      'DiscoverHeader (loading)',
      () => const DiscoverHeader(progress: ProgressInitial()),
    );

    sweep('LikesTeaserBanner', () => const LikesTeaserBanner(count: 128));

    sweep(
      'StatTiles two per row',
      () => const EqualHeightRow(
        spacing: AppTokens.space12,
        children: [
          StatTile(
            illustration: Illustrations.fire,
            value: 1234,
            label: 'Day streak record',
            semanticLabel: 'streak',
            footer: GaProgressBar(value: 0.5),
          ),
          StatTile(
            illustration: Illustrations.star,
            value: 9876543,
            label: 'Stars across all repositories',
            semanticLabel: 'stars',
          ),
        ],
      ),
    );

    sweep(
      'ConversationTile (unread, long name and message)',
      () => ConversationTile(
        match: sampleMatch(
          user: longUser(),
          lastMessage: '$_longText. ' * 3,
          isRead: false,
        ),
        myUserId: 'me',
        onTap: () {},
      ),
    );

    sweep(
      'ConversationTile (new match)',
      () => ConversationTile(
        match: sampleMatch(user: longUser(), lastMessage: null),
        onTap: () {},
      ),
    );

    sweep(
      'MessageBubbles (long words, code, mine and theirs)',
      () => Column(
        children: [
          MessageBubble(
            message: sampleMessage(
              content: 'https://github.com/${'a' * 120}/repository',
            ),
            isMine: true,
            senderName: 'Ada',
            isGroupTop: true,
            showTime: true,
          ),
          MessageBubble(
            message: sampleMessage(
              content: 'fn main() {\n  let x = "${'y' * 80}";\n}',
              senderId: 'u1',
            ),
            isMine: false,
            senderName: 'Ada',
            isGroupTop: true,
            showTime: true,
          ),
          const DaySeparator(label: 'Wednesday, January 15, 2025'),
        ],
      ),
    );

    sweep(
      'IcebreakerPanel',
      () => SizedBox(
        height: 520,
        child: IcebreakerPanel(
          name: 'Maximiliana Alexandrina Wolfeschlegelsteinhausen',
          icebreakers: const [_longText, 'Rust or Go?', '$_longText?'],
          loading: false,
          onPick: (_) {},
        ),
      ),
    );
  });
}
