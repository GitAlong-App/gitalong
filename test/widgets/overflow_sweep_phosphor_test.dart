import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/theme/app_tokens.dart';
import 'package:gitalong/domain/usecases/progress/profile_strength.dart';
import 'package:gitalong/presentation/screens/chat/widgets/chat_composer.dart';
import 'package:gitalong/presentation/screens/profile/widgets/achievements_grid.dart';
import 'package:gitalong/presentation/screens/profile/widgets/profile_checklist_tile.dart';
import 'package:gitalong/presentation/screens/profile/widgets/profile_header.dart';
import 'package:gitalong/presentation/screens/settings/widgets/settings_group.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/discover_card.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/swipe_action_bar.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/swipe_stamp.dart';

import 'helpers.dart';

/// The same configs as overflow_sweep_test.dart.
const List<({Size size, double scale})> _configs = [
  (size: kSmallPhone, scale: 1.0),
  (size: kSmallPhone, scale: 1.5),
  (size: kDesignSize, scale: 2.0),
];

void sweep(
  String name,
  Widget Function() build, {
  bool scroll = true,
  bool gutter = true,
}) {
  for (final config in _configs) {
    final label = '${config.size.width.toInt()}x${config.size.height.toInt()}'
        ' @${config.scale}x';
    testWidgets('$name fits at $label', (tester) async {
      await pumpApp(
        tester,
        gutter
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
                child: build(),
              )
            : build(),
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

void main() {
  group('overflow sweep: phosphor-dependent screen pieces', () {
    for (final height in [300.0, 420.0, 560.0]) {
      sweep(
        'DiscoverCard (long profile, ${height.toInt()} px tall)',
        () => SizedBox(height: height, child: DiscoverCard(user: longUser())),
      );
      sweep(
        'DiscoverCard (sample profile, ${height.toInt()} px tall)',
        () => SizedBox(
          height: height,
          child: DiscoverCard(
            user: sampleUser(),
            viewerIntents: const ['cofounder'],
          ),
        ),
      );
    }

    sweep(
      'SwipeActionBar',
      () => SwipeActionBar(
        drag: ValueNotifier(const Offset(60, 0)),
        threshold: 120,
        onNope: () {},
        onSuperLike: () {},
        onLike: () {},
      ),
      gutter: false,
    );

    sweep(
      'SwipeStampsOverlay',
      () => const SizedBox(
        height: 400,
        child: SwipeStampsOverlay(like: 1, nope: 1, superLike: 1),
      ),
    );

    sweep(
      'ChatComposer (near the limit)',
      () => ChatComposer(
        controller: TextEditingController(text: 'x' * 3800),
        enabled: true,
        canSend: true,
        hintText: 'Message Maximiliana Alexandrina Wolfeschlegelsteinhausen',
        onSend: () {},
      ),
      gutter: false,
    );

    sweep(
      'ChatComposer (empty, long hint)',
      () => ChatComposer(
        controller: TextEditingController(),
        enabled: false,
        canSend: false,
        hintText: 'Message Maximiliana Alexandrina Wolfeschlegelsteinhausen '
            'once their profile has loaded',
        onSend: () {},
      ),
      gutter: false,
    );

    sweep(
      'ProfileHeader (long profile)',
      () => ProfileHeader(
        user: longUser(),
        strengthDone: 5,
        strengthTotal: 8,
        level: 99,
      ),
    );

    sweep(
      'ProfileChecklistTile (all checks missing)',
      () => ProfileChecklistTile(
        done: 0,
        total: 8,
        missing: ProfileChecks.all,
        onEdit: () {},
        onRefreshGitHub: () {},
        showXpReward: true,
      ),
    );

    sweep(
      'AchievementsGrid',
      () => AchievementsGrid(isUnlocked: (key) => key.startsWith('first')),
    );

    sweep(
      'SettingsGroup (long titles, switch)',
      () => SettingsGroup(
        children: [
          SettingsRow(
            title: 'Notifications for new matches and messages',
            subtitle: 'We will only ping you when something important '
                'happens in your conversations',
            leading: const Icon(Icons.notifications),
            onTap: () {},
          ),
          SettingsSwitchRow(
            title: 'Reduce motion and celebration effects everywhere',
            subtitle: 'Turns off confetti and bouncy animations',
            leading: const Icon(Icons.motion_photos_off),
            value: true,
            onChanged: (_) {},
          ),
          const SettingsRow(
            title: 'Version',
            trailing: Text('1.0.0+123 (build 2025-01-15)'),
          ),
        ],
      ),
    );
  });
}
