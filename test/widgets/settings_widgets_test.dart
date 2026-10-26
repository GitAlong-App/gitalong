import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/presentation/screens/settings/widgets/settings_group.dart';

import 'helpers.dart';

void main() {
  group('SettingsGroup', () {
    testWidgets('separates rows with dividers', (tester) async {
      await pumpApp(
        tester,
        const SettingsGroup(
          children: [
            SettingsRow(title: 'One'),
            SettingsRow(title: 'Two'),
            SettingsRow(title: 'Three'),
          ],
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Three'), findsOneWidget);
    });
  });

  group('SettingsRow', () {
    testWidgets('tappable row: button semantics, chevron, onTap',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        SettingsGroup(
          children: [
            SettingsRow(
              title: 'Privacy policy',
              subtitle: 'How we handle your data',
              onTap: () => taps++,
            ),
          ],
        ),
      );
      expect(find.text('How we handle your data'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Privacy policy'))),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(find.byType(Icon), findsOneWidget);

      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('static row: no chevron, not a button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const SettingsGroup(
          children: [SettingsRow(title: 'Version', trailing: Text('1.0.0'))],
        ),
      );
      expect(find.text('1.0.0'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Version'))),
        isSemantics(isButton: false, hasTapAction: false),
      );
      semantics.dispose();
    });
  });

  group('SettingsSwitchRow', () {
    testWidgets('tapping the row toggles; reads as a toggle, not a button',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var value = false;
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Dark mode',
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ],
          ),
        ),
      );

      final node =
          tester.getSemantics(find.bySemanticsLabel(RegExp('Dark mode')));
      expect(node, isSemantics(isButton: false, hasToggledState: true));

      await tester.tap(find.text('Dark mode'));
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(value, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await settle(tester, total: const Duration(milliseconds: 400));
      expect(value, isFalse);
      semantics.dispose();
    });

    testWidgets('null onChanged disables the switch', (tester) async {
      await pumpApp(
        tester,
        const SettingsGroup(
          children: [
            SettingsSwitchRow(title: 'Sounds', value: true, onChanged: null),
          ],
        ),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      await tester.tap(find.text('Sounds'));
      await tester.pump();
      expectNoExceptions(tester);
    });
  });
}
