import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/theme/app_colors.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('GaChip', () {
    testWidgets('static chip: label uppercase, selected semantics, no tap',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(child: GaChip(label: 'Rust', selected: true)),
      );

      expect(find.text('RUST'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Rust')),
        isSemantics(isSelected: true, isButton: false, hasTapAction: false),
      );
      semantics.dispose();
    });

    testWidgets('uppercase: false keeps the label as written', (tester) async {
      await pumpApp(
        tester,
        const Center(child: GaChip(label: 'TypeScript', uppercase: false)),
      );
      expect(find.text('TypeScript'), findsOneWidget);
    });

    testWidgets('tapping toggles selection through onTap', (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = false;
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: GaChip(
              label: 'Dart',
              selected: selected,
              onTap: () => setState(() => selected = !selected),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Dart')),
        isSemantics(isButton: true, isSelected: false, hasTapAction: true),
      );

      await tester.tap(find.text('DART'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(selected, isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dart')),
        isSemantics(isSelected: true),
      );

      await tester.tap(find.text('DART'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(selected, isFalse);
      semantics.dispose();
    });

    testWidgets('remove-only chip: tapping anywhere removes, read as "Remove"',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var removed = 0;
      await pumpApp(
        tester,
        Center(child: GaChip(label: 'Go', onRemove: () => removed++)),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Remove Go'), findsOneWidget);
      await tester.tap(find.text('GO'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(removed, 1);
      semantics.dispose();
    });

    testWidgets('tap + remove: the × removes, the body taps', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      var removed = 0;
      await pumpApp(
        tester,
        Center(
          child: GaChip(
            label: 'Kotlin',
            onTap: () => taps++,
            onRemove: () => removed++,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(removed, 1);
      expect(taps, 0);

      await tester.tap(find.text('KOTLIN'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
      expect(removed, 1);

      // Screen readers get a custom "Remove" action instead of the ×.
      final data = tester
          .getSemantics(find.bySemanticsLabel('Kotlin'))
          .getSemanticsData();
      expect(data.customSemanticsActionIds, isNotEmpty);
      semantics.dispose();
    });

    testWidgets('tappable chips reserve a 48 px touch target', (tester) async {
      await pumpApp(
        tester,
        Center(child: GaChip(label: 'Swift', onTap: () {})),
      );
      expect(
        tester.getSize(find.byType(GaChip)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('lays out in an unbounded horizontal list', (tester) async {
      await pumpApp(
        tester,
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final l in ['One', 'Two', 'Three'])
                GaChip(label: l, onTap: () {}, icon: Icons.code),
            ],
          ),
        ),
      );
      expectNoExceptions(tester);
      expect(find.byType(GaChip), findsNWidgets(3));
    });
  });

  group('StreakChip', () {
    testWidgets('active today: label and count', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(child: StreakChip(days: 5, activeToday: true)),
      );
      expect(find.text('5'), findsOneWidget);
      expect(find.bySemanticsLabel('5 days streak'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('singular day and "not active yet today"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(child: StreakChip(days: 1, activeToday: false)),
      );
      expect(
        find.bySemanticsLabel('1 day streak, not active yet today'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('tappable: button semantics and onTap', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        Center(
          child: StreakChip(days: 3, activeToday: true, onTap: () => taps++),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('3 days streak')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byType(StreakChip));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
      expect(tester.getSize(find.byType(StreakChip)).height,
          greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    testWidgets('the number ticks up to the new value', (tester) async {
      Widget chip(int days) =>
          Center(child: StreakChip(days: days, activeToday: true));
      await pumpApp(tester, chip(2));
      expect(find.text('2'), findsOneWidget);

      await pumpApp(tester, chip(9));
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-animation: neither the old nor (yet) the final value necessarily.
      await settle(tester, total: const Duration(seconds: 1));
      expect(find.text('9'), findsOneWidget);
    });
  });

  group('XpChip', () {
    testWidgets('shows "N XP" and reads it', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, const Center(child: XpChip(xp: 120)));
      expect(find.text('120 XP'), findsOneWidget);
      expect(find.bySemanticsLabel('120 XP'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tap', (tester) async {
      var taps = 0;
      await pumpApp(tester, Center(child: XpChip(xp: 5, onTap: () => taps++)));
      await tester.tap(find.byType(XpChip));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
    });
  });

  group('LevelBadge', () {
    testWidgets('shows the level and reads "Level N"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, const Center(child: LevelBadge(level: 7)));
      expect(find.text('7'), findsOneWidget);
      expect(find.bySemanticsLabel('Level 7'), findsOneWidget);
      expect(tester.getSize(find.byType(LevelBadge)), const Size(32, 32));
      semantics.dispose();
    });

    testWidgets('large levels scale down inside small badges', (tester) async {
      await pumpApp(
        tester,
        const Center(child: LevelBadge(level: 12345, size: 20)),
      );
      expectNoExceptions(tester);
      expect(tester.getSize(find.byType(LevelBadge)), const Size(20, 20));
    });
  });

  group('GaBadge', () {
    testWidgets('shows the count and "N new"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(child: GaBadge(count: 3, child: Icon(Icons.chat))),
      );
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('3 new'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('hidden at zero unless showZero', (tester) async {
      await pumpApp(
        tester,
        const Column(
          children: [
            GaBadge(count: 0, child: Icon(Icons.chat)),
            GaBadge(count: 0, showZero: true, tone: AppTone.green),
          ],
        ),
      );
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.chat), findsOneWidget);
    });

    testWidgets('caps at max with "+"', (tester) async {
      await pumpApp(tester, const Center(child: GaBadge(count: 150)));
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('AnimatedCount', () {
    testWidgets('counts from "from" to value; reads only the final value',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(
          child: AnimatedCount(from: 0, value: 50, prefix: '+', suffix: ' XP'),
        ),
      );
      expect(find.text('+0 XP'), findsOneWidget);
      expect(find.bySemanticsLabel('+50 XP'), findsOneWidget);
      await settle(tester, total: const Duration(seconds: 1));
      expect(find.text('+50 XP'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('is instant under reduced motion', (tester) async {
      await pumpApp(
        tester,
        const Center(child: AnimatedCount(from: 0, value: 50)),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text('50'), findsOneWidget);
    });
  });
}
