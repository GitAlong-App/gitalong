import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/achievements.dart';
import 'package:gitalong/domain/usecases/progress/profile_strength.dart';
import 'package:gitalong/presentation/screens/profile/widgets/achievements_grid.dart';
import 'package:gitalong/presentation/screens/profile/widgets/profile_checklist_tile.dart';
import 'package:gitalong/presentation/screens/profile/widgets/profile_header.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

List<ProfileCheck> _checks(List<String> keys) =>
    [for (final key in keys) ProfileChecks.byKey(key)!];

void main() {
  group('ProfileHeader', () {
    testWidgets('name, handle, strength pill, bio, meta and level badge',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        ProfileHeader(
          user: sampleUser(websiteUrl: 'https://www.ada.dev'),
          strengthDone: 6,
          strengthTotal: 8,
          level: 4,
        ),
        scrollable: true,
      );
      await settle(tester, total: const Duration(milliseconds: 800));

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('@ada-dev'), findsOneWidget);
      expect(find.text('PROFILE 75% COMPLETE'), findsOneWidget);
      expect(find.text('Building tools for analytical engines.'),
          findsOneWidget);
      expect(find.text('London, UK'), findsOneWidget);
      expect(find.text('Analytical Co'), findsOneWidget);
      // Website shows the bare host, as a link.
      expect(find.text('ada.dev'), findsOneWidget);
      expect(
        // The node that owns the host text is the merged link node.
        tester.getSemantics(find.text('ada.dev')),
        isSemantics(isLink: true),
      );
      expect(find.bySemanticsLabel('Level 4'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Profile strength'))),
        isSemantics(value: '75 percent'),
      );
      semantics.dispose();
    });

    testWidgets('complete profile; no level, no meta; username fallback',
        (tester) async {
      await pumpApp(
        tester,
        ProfileHeader(
          user: sampleUser(
            name: null,
            bio: null,
            location: null,
            company: null,
            githubUrl: null,
          ),
          strengthDone: 8,
          strengthTotal: 8,
        ),
        scrollable: true,
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      expect(find.text('ada-dev'), findsOneWidget);
      expect(find.text('PROFILE COMPLETE'), findsOneWidget);
      expect(find.byType(LevelBadge), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('zero total does not divide by zero', (tester) async {
      await pumpApp(
        tester,
        ProfileHeader(user: sampleUser(), strengthDone: 0, strengthTotal: 0),
        scrollable: true,
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      expect(find.text('PROFILE 0% COMPLETE'), findsOneWidget);
      expectNoExceptions(tester);
    });
  });

  group('AchievementsGrid', () {
    testWidgets('all achievements, locked and unlocked', (tester) async {
      final semantics = tester.ensureSemantics();
      const unlocked = {Achievements.firstSwipe, Achievements.firstMatch};
      await pumpApp(
        tester,
        AchievementsGrid(isUnlocked: unlocked.contains),
        scrollable: true,
      );
      await settle(tester, total: const Duration(milliseconds: 500));

      expect(find.byType(AchievementTile), findsNWidgets(Achievements.all.length));
      expect(
        find.bySemanticsLabel(
          'Achievement: First steps. Review your first builder. Unlocked',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Achievement: On fire. Reach a 3-day streak. Locked',
        ),
        findsOneWidget,
      );
      final lockedCount = tester
          .widgetList<AchievementTile>(find.byType(AchievementTile))
          .where((t) => !t.unlocked)
          .length;
      expect(lockedCount, Achievements.all.length - unlocked.length);
      semantics.dispose();
    });

    testWidgets('three per row, equal height', (tester) async {
      await pumpApp(
        tester,
        AchievementsGrid(isUnlocked: (_) => false),
        scrollable: true,
      );
      final tiles = find.byType(AchievementTile);
      final first = tester.getRect(tiles.at(0));
      final second = tester.getRect(tiles.at(1));
      final third = tester.getRect(tiles.at(2));
      final fourth = tester.getRect(tiles.at(3));
      expect(second.top, first.top);
      expect(third.top, first.top);
      expect(second.height, first.height);
      expect(fourth.top, greaterThan(first.bottom));
    });

    testWidgets('tapping a tile opens its sheet; the button closes it',
        (tester) async {
      await pumpApp(
        tester,
        AchievementsGrid(
          isUnlocked: (key) => key == Achievements.streak3,
        ),
        scrollable: true,
      );
      await tester.tap(find.text('On fire'));
      await settle(tester, total: const Duration(milliseconds: 800));
      expect(find.text('UNLOCKED'), findsOneWidget);
      expect(find.text('You earned this: Reach a 3-day streak'), findsOneWidget);

      await tester.tap(find.text('NICE!'));
      await settle(tester, total: const Duration(milliseconds: 800));
      expect(find.text('UNLOCKED'), findsNothing);

      await tester.tap(find.text('Explorer'));
      await settle(tester, total: const Duration(milliseconds: 800));
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('How to earn it: Review 50 builders'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);
    });
  });

  group('ProfileChecklistTile', () {
    testWidgets('lists missing checks; CTA opens edit', (tester) async {
      final semantics = tester.ensureSemantics();
      var edits = 0;
      var refreshes = 0;
      await pumpApp(
        tester,
        ProfileChecklistTile(
          done: 6,
          total: 8,
          missing: _checks([ProfileChecks.bio, ProfileChecks.location]),
          onEdit: () => edits++,
          onRefreshGitHub: () => refreshes++,
          showXpReward: true,
        ),
        scrollable: true,
      );

      expect(find.text('Complete your profile'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Complete your profile')),
        isSemantics(isHeader: true),
      );
      expect(find.text('6/8'), findsOneWidget);
      expect(find.text('Write a bio'), findsOneWidget);
      expect(find.text('Add your location'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^To do:[\s\S]*Write a bio')),
          findsOneWidget);
      expect(find.text('Finish it for +50 XP'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Profile strength'))),
        isSemantics(value: '6 of 8 done'),
      );

      await tester.tap(find.text('FINISH MY PROFILE'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(edits, 1);
      expect(refreshes, 0);
      semantics.dispose();
    });

    testWidgets('only the photo missing: offers a GitHub refresh',
        (tester) async {
      var refreshes = 0;
      await pumpApp(
        tester,
        ProfileChecklistTile(
          done: 7,
          total: 8,
          missing: _checks([ProfileChecks.avatar]),
          onEdit: () {},
          onRefreshGitHub: () => refreshes++,
        ),
        scrollable: true,
      );
      expect(find.text('FINISH MY PROFILE'), findsNothing);
      expect(find.text('Finish it for +50 XP'), findsNothing);
      await tester.tap(find.text('REFRESH FROM GITHUB'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(refreshes, 1);
    });

    testWidgets('refreshing: the refresh button shows a spinner',
        (tester) async {
      await pumpApp(
        tester,
        ProfileChecklistTile(
          done: 7,
          total: 8,
          missing: _checks([ProfileChecks.avatar]),
          onEdit: () {},
          onRefreshGitHub: () {},
          refreshingGitHub: true,
        ),
        scrollable: true,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('REFRESH FROM GITHUB'), findsNothing);
    });
  });
}
