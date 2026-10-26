import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/achievements.dart';
import 'package:gitalong/core/constants/illustrations.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('title is a header; message and action shown', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        EmptyState(
          illustration: Illustrations.thinkingFace,
          title: 'No one yet',
          message: 'Want to widen your filters?',
          actionLabel: 'Refresh',
          onAction: () => taps++,
        ),
      );
      await settle(tester, total: const Duration(milliseconds: 800));

      expect(
        tester.getSemantics(find.text('No one yet')),
        isSemantics(isHeader: true),
      );
      expect(find.text('Want to widen your filters?'), findsOneWidget);
      await tester.tap(find.text('REFRESH'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('no button without both actionLabel and onAction',
        (tester) async {
      await pumpApp(
        tester,
        const EmptyState(
          illustration: Illustrations.ghost,
          title: 'Quiet here',
          actionLabel: 'Refresh',
        ),
      );
      await settle(tester, total: const Duration(milliseconds: 800));
      expect(find.byType(PressableButton), findsNothing);
      expect(find.text('Quiet here'), findsOneWidget);
    });

    testWidgets('reduced motion: everything visible on the first frame',
        (tester) async {
      await pumpApp(
        tester,
        const EmptyState(illustration: Illustrations.ghost, title: 'Quiet'),
        reduceMotion: true,
      );
      expect(find.text('Quiet'), findsOneWidget);
      expectNoExceptions(tester);
    });
  });

  group('OptionCard', () {
    testWidgets('multiple: a checkbox; tapping toggles; badge when selected',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = false;
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => OptionCard(
            title: 'Co-founder',
            subtitle: 'Build a company together',
            illustration: Illustrations.rocket,
            selected: selected,
            onTap: () => setState(() => selected = !selected),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Co-founder')),
        isSemantics(
          hasCheckedState: true,
          isChecked: false,
          hint: 'Build a company together',
          hasTapAction: true,
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await tester.tap(find.text('Co-founder'));
      await settle(tester, total: const Duration(milliseconds: 600));
      expect(selected, isTrue);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Co-founder')),
        isSemantics(isChecked: true),
      );
      semantics.dispose();
    });

    testWidgets('single: a radio in a mutually exclusive group',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        OptionCard(
          title: 'Mentor',
          selected: true,
          selectionMode: OptionSelectionMode.single,
          onTap: () {},
        ),
      );
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mentor')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true),
      );
      semantics.dispose();
    });

    testWidgets('none: an action button, never shows the check badge',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        OptionCard(
          title: 'What are you building?',
          selected: true,
          selectionMode: OptionSelectionMode.none,
          onTap: () => taps++,
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('What are you building?')),
        isSemantics(isButton: true, hasCheckedState: false),
      );
      await tester.tap(find.byType(OptionCard));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('disabled when onTap is null', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, const OptionCard(title: 'Hackathon', onTap: null));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Hackathon')),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      semantics.dispose();
    });
  });

  group('GaSegmentedTabs', () {
    testWidgets('selected tab semantics and onChanged', (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <int>[];
      var index = 0;
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => GaSegmentedTabs(
            labels: const ['New', 'All'],
            selectedIndex: index,
            onChanged: (i) {
              changes.add(i);
              setState(() => index = i);
            },
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('New')),
        isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('All')),
        isSemantics(isSelected: false),
      );

      await tester.tap(find.text('ALL'));
      await settle(tester, total: const Duration(milliseconds: 500));
      expect(changes, [1]);
      expect(
        tester.getSemantics(find.bySemanticsLabel('All')),
        isSemantics(isSelected: true),
      );

      // Tapping the active tab doesn't fire onChanged again.
      await tester.tap(find.text('ALL'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(changes, [1]);
      semantics.dispose();
    });

    testWidgets('empty labels render nothing; out-of-range index is clamped',
        (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            GaSegmentedTabs(labels: const [], selectedIndex: 0, onChanged: (_) {}),
            GaSegmentedTabs(
              labels: const ['A', 'B', 'C'],
              selectedIndex: 9,
              onChanged: (_) {},
            ),
          ],
        ),
      );
      expectNoExceptions(tester);
      expect(find.text('C'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('title is a header; action button reads as written',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        SectionHeader(
          title: 'Achievements',
          subtitle: '3 of 10 unlocked',
          actionLabel: 'See all',
          onAction: () => taps++,
        ),
      );

      expect(tester.getSemantics(find.text('Achievements')),
          isSemantics(isHeader: true));
      expect(find.text('3 of 10 unlocked'), findsOneWidget);
      expect(find.text('SEE ALL'), findsOneWidget);
      expect(find.bySemanticsLabel('See all'), findsOneWidget);
      await tester.tap(find.text('SEE ALL'));
      await tester.pump();
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('trailing replaces the action; no action without onAction',
        (tester) async {
      await pumpApp(
        tester,
        const Column(
          children: [
            SectionHeader(
              title: 'One',
              actionLabel: 'See all',
              trailing: Icon(Icons.star),
            ),
            SectionHeader(title: 'Two', actionLabel: 'See all'),
          ],
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('SEE ALL'), findsNothing);
    });
  });

  group('MascotBubble', () {
    testWidgets('types the message on; screen readers get it all',
        (tester) async {
      const message = "Hi! I'm Octo. Let's find your people.";
      await pumpApp(tester, const MascotBubble(message: message));

      // The whole message is laid out from the first frame (the unrevealed
      // part is transparent), so the bubble never resizes.
      final richText = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == message,
      );
      expect(richText, findsOneWidget);
      final sizeBefore = tester.getSize(richText);

      await settle(tester, total: const Duration(seconds: 1));
      expect(tester.getSize(richText), sizeBefore);
      expect(find.text(message, findRichText: true), findsOneWidget);
      expectNoExceptions(tester);
    });

    testWidgets('restarts typing when the message changes', (tester) async {
      await pumpApp(tester, const MascotBubble(message: 'First'));
      await settle(tester, total: const Duration(seconds: 1));
      await pumpApp(tester, const MascotBubble(message: 'Second message'));
      await settle(tester, total: const Duration(seconds: 1));
      expect(find.text('Second message', findRichText: true), findsOneWidget);
    });

    testWidgets('reduced motion and typeOn: false show everything at once',
        (tester) async {
      await pumpApp(
        tester,
        const Column(
          children: [
            MascotBubble(message: 'No typing', typeOn: false),
            MascotBubble(message: 'Reduced'),
          ],
        ),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text('No typing', findRichText: true), findsOneWidget);
      expect(find.text('Reduced', findRichText: true), findsOneWidget);
    });
  });

  group('Illustration', () {
    testWidgets('decorative by default; semanticLabel makes it an image',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Column(
          children: [
            Illustration(Illustrations.rocket, size: 40),
            Illustration(Illustrations.trophy, semanticLabel: 'Trophy'),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Trophy')),
        isSemantics(isImage: true),
      );
      expect(tester.getSize(find.byType(Illustration).first),
          const Size(40, 40));
      semantics.dispose();
    });

    testWidgets('a missing asset shows the placeholder instead of throwing',
        (tester) async {
      await pumpApp(
        tester,
        const Center(child: Illustration('does_not_exist', size: 64)),
      );
      // Asset loading is real I/O (manifest lookup, then the load): give it
      // a few real-time rounds, pumping in between to deliver the results.
      for (var i = 0;
          i < 20 && find.byIcon(Icons.auto_awesome_rounded).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.getSize(find.byType(Illustration)), const Size(64, 64));
      expectNoExceptions(tester);
    });

    testWidgets('grayscale and opacity wrap the image', (tester) async {
      await pumpApp(
        tester,
        const Illustration(Illustrations.fire, grayscale: true, opacity: 0.5),
      );
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
    });
  });

  group('GaTile', () {
    testWidgets('static tile with semanticLabel reads as one item',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const GaTile(semanticLabel: 'Pitch card', child: Text('Inner')),
      );
      expect(find.bySemanticsLabel('Pitch card'), findsOneWidget);
      expect(find.bySemanticsLabel('Inner'), findsNothing);
      semantics.dispose();
    });

    testWidgets('tap and long press', (tester) async {
      var taps = 0;
      var longPresses = 0;
      await pumpApp(
        tester,
        GaTile(
          onTap: () => taps++,
          onLongPress: () => longPresses++,
          child: const Text('Tile'),
        ),
      );
      await tester.tap(find.text('Tile'));
      await settle(tester, total: const Duration(milliseconds: 300));
      await tester.longPress(find.text('Tile'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
      expect(longPresses, 1);
    });
  });

  group('AchievementTile', () {
    const achievement = AchievementDefinition(
      key: 'streak_3',
      illustration: Illustrations.fire,
      title: 'On fire',
      description: 'Reach a 3-day streak',
    );

    testWidgets('locked: lock badge and "Locked" in the label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(
          child: SizedBox(
            width: 160,
            child: AchievementTile(achievement: achievement, unlocked: false),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Achievement: On fire. Reach a 3-day streak. Locked',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Illustration && w.name == Illustrations.locked,
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('unlocked and new: no lock, "Unlocked, new"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(
          child: SizedBox(
            width: 160,
            child: AchievementTile(
              achievement: achievement,
              unlocked: true,
              isNew: true,
            ),
          ),
        ),
      );
      await settle(tester, total: const Duration(seconds: 2));
      expect(
        find.bySemanticsLabel(
          'Achievement: On fire. Reach a 3-day streak. Unlocked, new',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Illustration && w.name == Illustrations.locked,
        ),
        findsNothing,
      );
      semantics.dispose();
    });
  });

  group('GaSkeleton', () {
    testWidgets('repeating shimmer does not hang bounded pumps',
        (tester) async {
      await pumpApp(tester, const GaSkeleton(height: 40));
      await settle(tester, total: const Duration(seconds: 3));
      expectNoExceptions(tester);
    });
  });
}
