import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/theme/app_colors.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

void main() {
  group('PressableButton', () {
    testWidgets('shows the label uppercase and calls onPressed on tap',
        (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Center(
          child: PressableButton(label: 'Get started', onPressed: () => taps++),
        ),
      );

      expect(find.text('GET STARTED'), findsOneWidget);
      await tester.tap(find.byType(PressableButton));
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(taps, 1);
      expectNoExceptions(tester);
    });

    testWidgets('is an enabled button for screen readers, read as written',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        Center(child: PressableButton(label: 'Get started', onPressed: () {})),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Get started')),
        isSemantics(
          label: 'Get started',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('semanticLabel overrides the label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        Center(
          child: PressableButton(
            label: 'Go',
            semanticLabel: 'Start swiping',
            onPressed: () {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Start swiping'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(child: PressableButton(label: 'Save', onPressed: null)),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      // Tapping does nothing (and doesn't throw).
      await tester.tap(find.byType(PressableButton), warnIfMissed: false);
      await tester.pump();
      expectNoExceptions(tester);
      semantics.dispose();
    });

    testWidgets('loading shows a spinner, hides the label and ignores taps',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        Center(
          child: PressableButton(
            label: 'Save',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('SAVE'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(
          label: 'Save',
          value: 'Loading',
          isButton: true,
          hasEnabledState: true,
        ),
      );

      await tester.tap(find.byType(PressableButton), warnIfMissed: false);
      // The spinner never settles: use bounded pumps.
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 0);
      semantics.dispose();
    });

    testWidgets('fills a bounded width and keeps the natural width in a Row',
        (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            PressableButton(label: 'Wide', onPressed: () {}),
            Row(
              children: [
                PressableButton(label: 'Narrow', onPressed: () {}),
              ],
            ),
          ],
        ),
      );
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(
        tester.getSize(find.widgetWithText(PressableButton, 'WIDE')).width,
        screenWidth,
      );
      expect(
        tester.getSize(find.widgetWithText(PressableButton, 'NARROW')).width,
        lessThan(screenWidth),
      );
      expectNoExceptions(tester);
    });

    testWidgets('renders every variant and size in light and dark',
        (tester) async {
      for (final dark in [false, true]) {
        await pumpApp(
          tester,
          Column(
            children: [
              for (final variant in PressableVariant.values)
                PressableButton(
                  label: variant.name,
                  variant: variant,
                  size: PressableSize
                      .values[variant.index % PressableSize.values.length],
                  icon: Icons.check,
                  trailingIcon: Icons.arrow_forward,
                  onPressed: () {},
                ),
            ],
          ),
          dark: dark,
          scrollable: true,
        );
        expectNoExceptions(tester, reason: 'dark: $dark');
        expect(find.byType(PressableButton),
            findsNWidgets(PressableVariant.values.length));
      }
    });

    testWidgets('meets the 48 px minimum touch target in every size',
        (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            for (final size in PressableSize.values)
              PressableButton(
                label: size.name,
                size: size,
                onPressed: () {},
              ),
          ],
        ),
      );
      for (final size in PressableSize.values) {
        final height = tester
            .getSize(find.widgetWithText(PressableButton, size.name.toUpperCase()))
            .height;
        expect(height, greaterThanOrEqualTo(48), reason: size.name);
      }
    });
  });

  group('CircleActionButton', () {
    testWidgets('taps, labels and disables', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleActionButton(
              icon: Icons.favorite,
              semanticLabel: 'Like',
              onPressed: () => taps++,
            ),
            const CircleActionButton(
              icon: Icons.close,
              semanticLabel: 'Nope',
              tone: AppTone.danger,
              filled: false,
              onPressed: null,
            ),
          ],
        ),
      );

      await tester.tap(find.bySemanticsLabel('Like'));
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(taps, 1);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Nope')),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      semantics.dispose();
    });
  });
}
