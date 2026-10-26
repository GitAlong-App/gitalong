import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('GaProgressBar', () {
    testWidgets('reads its value as a percentage by default', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: GaProgressBar(value: 0.42, semanticLabel: 'Daily goal'),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Daily goal')),
        isSemantics(label: 'Daily goal', value: '42%'),
      );
      semantics.dispose();
    });

    testWidgets('clamps out-of-range and NaN values', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Column(
          children: [
            GaProgressBar(value: 1.7, semanticLabel: 'over'),
            GaProgressBar(value: -0.3, semanticLabel: 'under'),
            GaProgressBar(value: double.nan, semanticLabel: 'nan'),
          ],
        ),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('over')),
          isSemantics(value: '100%'));
      expect(tester.getSemantics(find.bySemanticsLabel('under')),
          isSemantics(value: '0%'));
      expect(tester.getSemantics(find.bySemanticsLabel('nan')),
          isSemantics(value: '0%'));
      expectNoExceptions(tester);
      semantics.dispose();
    });

    testWidgets('custom semantic value and height; fills the width',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const GaProgressBar(
          value: 0.3,
          height: 12,
          semanticLabel: 'Daily goal',
          semanticValue: '3 of 10',
        ),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Daily goal')),
          isSemantics(value: '3 of 10'));
      expect(tester.getSize(find.byType(GaProgressBar)),
          Size(kDesignSize.width, 12));
      semantics.dispose();
    });

    testWidgets('animateOnMount fills from 0 and settles', (tester) async {
      await pumpApp(
        tester,
        const GaProgressBar(value: 0.8, animateOnMount: true),
      );
      final animator = find.byType(TweenAnimationBuilder<double>);
      expect(
        tester.widget<TweenAnimationBuilder<double>>(animator).tween.begin,
        0,
      );
      await settle(tester, total: const Duration(milliseconds: 700));
      expectNoExceptions(tester);
    });
  });

  group('ProgressRing', () {
    testWidgets('reads its value and centres the child', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(
          child: ProgressRing(
            value: 0.75,
            size: 112,
            semanticLabel: 'Profile strength',
            child: Text('6/8'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Profile strength'))),
        isSemantics(value: '75%'),
      );
      expect(find.text('6/8'), findsOneWidget);
      expect(tester.getSize(find.byType(ProgressRing)), const Size(112, 112));
      expect(
        tester.getCenter(find.text('6/8')),
        tester.getCenter(find.byType(ProgressRing)),
      );
      semantics.dispose();
    });

    testWidgets('clamps and accepts a custom semantic value', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(
          child: ProgressRing(
            value: 3,
            semanticLabel: 'Match',
            semanticValue: '87%',
          ),
        ),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Match')),
          isSemantics(value: '87%'));
      expectNoExceptions(tester);
      semantics.dispose();
    });
  });
}
