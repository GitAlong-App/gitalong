import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/illustrations.dart';
import 'package:gitalong/presentation/screens/profile/widgets/stat_tile.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('StatTile', () {
    testWidgets('number, uppercase label, footer; one semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const SizedBox(
          width: 170,
          child: StatTile(
            illustration: Illustrations.fire,
            value: 12,
            label: 'Day streak',
            semanticLabel: '12 day streak',
            footer: Text('Best: 20'),
          ),
        ),
      );
      await settle(tester, total: const Duration(seconds: 1));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('DAY STREAK'), findsOneWidget);
      expect(find.text('Best: 20'), findsOneWidget);
      expect(find.bySemanticsLabel('12 day streak'), findsOneWidget);
      expect(find.bySemanticsLabel('Best: 20'), findsNothing);
      semantics.dispose();
    });

    testWidgets('large values use compact counts', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 170,
          child: StatTile(
            illustration: Illustrations.star,
            value: 12345,
            label: 'Stars',
            semanticLabel: '12345 stars',
          ),
        ),
      );
      expect(find.text('12.3k'), findsOneWidget);
      expect(find.byType(AnimatedCount), findsNothing);
    });

    testWidgets('grayscale illustration', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 170,
          child: StatTile(
            illustration: Illustrations.fire,
            value: 0,
            label: 'Streak',
            semanticLabel: 'No streak',
            grayscale: true,
          ),
        ),
      );
      expect(
        tester.widget<Illustration>(find.byType(Illustration)).grayscale,
        isTrue,
      );
    });

    test('compactCount and plural', () {
      expect(compactCount(999), '999');
      expect(compactCount(12345), '12.3k');
      expect(compactCount(2000), '2k');
      expect(compactCount(2500000), '2.5M');
      expect(plural(1, 'day'), '1 day');
      expect(plural(3, 'day'), '3 days');
      expect(plural(2, 'match', 'matches'), '2 matches');
    });
  });
}
