import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/achievements.dart';
import 'package:gitalong/core/constants/illustrations.dart';
import 'package:gitalong/core/theme/app_colors.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

/// Enter (450 ms) + hold (3 s) + exit (250 ms), with margin.
const Duration _toastLifetime = Duration(milliseconds: 4000);

/// A button that runs [onPressed] with a context under the app's overlay.
Widget _launcher(void Function(BuildContext context) onPressed) {
  return Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => onPressed(context),
        child: const Text('launch'),
      ),
    ),
  );
}

void main() {
  group('GaToast', () {
    testWidgets('eyebrow uppercase, title and message; one semantics label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const GaToast(
          eyebrow: 'Heads up',
          title: 'Daily goal reached!',
          message: '10 builders reviewed today',
          illustration: Illustrations.trophy,
          tone: AppTone.gold,
        ),
      );
      expect(find.text('HEADS UP'), findsOneWidget);
      expect(find.text('Daily goal reached!'), findsOneWidget);
      expect(find.text('10 builders reviewed today'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Heads up. Daily goal reached!. 10 builders reviewed today',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('AchievementToast uses the gold "Achievement unlocked" eyebrow',
        (tester) async {
      await pumpApp(
        tester,
        AchievementToast(achievement: Achievements.byKey('first_match')!),
      );
      expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
      expect(find.text("It's a match!"), findsOneWidget);
      expect(find.text('Get your first match'), findsOneWidget);
    });
  });

  group('showGaToast', () {
    testWidgets('slides in, holds, then removes itself and completes',
        (tester) async {
      var completed = false;
      await pumpApp(
        tester,
        _launcher((context) {
          showGaToast(context, title: 'Saved', message: 'All good')
              .then((_) => completed = true);
        }),
      );

      await tester.tap(find.text('launch'));
      await tester.pump();
      await settle(tester, total: const Duration(milliseconds: 500));
      expect(find.text('Saved'), findsOneWidget);
      expect(completed, isFalse);

      await settle(tester, total: _toastLifetime);
      expect(find.text('Saved'), findsNothing);
      expect(completed, isTrue);
      expectNoExceptions(tester);
    });

    testWidgets('tap dismisses early', (tester) async {
      var completed = false;
      await pumpApp(
        tester,
        _launcher((context) {
          showGaToast(context, title: 'Tap me').then((_) => completed = true);
        }),
      );
      await tester.tap(find.text('launch'));
      await settle(tester, total: const Duration(milliseconds: 600));

      await tester.tap(find.text('Tap me'));
      await settle(tester, total: const Duration(milliseconds: 500));
      expect(find.text('Tap me'), findsNothing);
      expect(completed, isTrue);
    });

    testWidgets('toasts are queued and shown one at a time', (tester) async {
      await pumpApp(
        tester,
        _launcher((context) {
          showGaToast(context, title: 'First');
          showGaToast(context, title: 'Second');
        }),
      );
      await tester.tap(find.text('launch'));
      await settle(tester, total: const Duration(milliseconds: 600));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);

      await settle(tester, total: _toastLifetime);
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);

      await settle(tester, total: _toastLifetime);
      expect(find.text('Second'), findsNothing);
      expectNoExceptions(tester);
    });
  });

  group('showAchievementToast', () {
    testWidgets('shows a known achievement', (tester) async {
      await pumpApp(
        tester,
        _launcher((context) {
          showAchievementToast(context, Achievements.streak3);
        }),
      );
      await tester.tap(find.text('launch'));
      await settle(tester, total: const Duration(milliseconds: 600));
      expect(find.text('On fire'), findsOneWidget);
      await settle(tester, total: _toastLifetime);
      expect(find.text('On fire'), findsNothing);
    });

    testWidgets('ignores unknown keys and completes immediately',
        (tester) async {
      var completed = false;
      await pumpApp(
        tester,
        _launcher((context) {
          showAchievementToast(context, 'not_a_real_key')
              .then((_) => completed = true);
        }),
      );
      await tester.tap(find.text('launch'));
      await tester.pump();
      expect(completed, isTrue);
      expect(find.byType(AchievementToast), findsNothing);
    });
  });
}
