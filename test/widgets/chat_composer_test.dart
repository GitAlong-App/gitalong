import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/presentation/screens/chat/widgets/chat_composer.dart';

import 'helpers.dart';

void main() {
  group('ChatComposer', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pumpComposer(
      WidgetTester tester, {
      bool enabled = true,
      bool canSend = true,
      VoidCallback? onSend,
    }) {
      return pumpApp(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: controller,
            enabled: enabled,
            canSend: canSend,
            hintText: 'Message Ada',
            onSend: onSend ?? () {},
          ),
        ),
      );
    }

    SemanticsNode sendButton(WidgetTester tester) =>
        tester.getSemantics(find.bySemanticsLabel('Send message'));

    testWidgets('send is disabled while the field is empty or whitespace',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComposer(tester);
      expect(find.text('Message Ada'), findsOneWidget);
      expect(sendButton(tester), isSemantics(isEnabled: false));

      await tester.enterText(find.byType(TextField), '   \n ');
      await tester.pump();
      expect(sendButton(tester), isSemantics(isEnabled: false));
      semantics.dispose();
    });

    testWidgets('typing enables send; tapping it calls onSend',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var sends = 0;
      await pumpComposer(tester, onSend: () => sends++);

      await tester.enterText(find.byType(TextField), 'Hello!');
      await tester.pump();
      expect(sendButton(tester), isSemantics(isEnabled: true, hasTapAction: true));

      await tester.tap(find.bySemanticsLabel('Send message'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(sends, 1);
      semantics.dispose();
    });

    testWidgets('canSend: false keeps send disabled even with text',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var sends = 0;
      await pumpComposer(tester, canSend: false, onSend: () => sends++);
      await tester.enterText(find.byType(TextField), 'Hello!');
      await tester.pump();
      expect(sendButton(tester), isSemantics(isEnabled: false));
      await tester.tap(find.bySemanticsLabel('Send message'),
          warnIfMissed: false);
      await tester.pump();
      expect(sends, 0);
      semantics.dispose();
    });

    testWidgets('disabled: the text field does not accept input',
        (tester) async {
      await pumpComposer(tester, enabled: false);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('shows the counter near the limit and caps at 4000',
        (tester) async {
      await pumpComposer(tester);
      controller.text = 'a' * 3599;
      await tester.pump();
      expect(find.textContaining('/ 4000'), findsNothing);

      controller.text = 'a' * 3700;
      await tester.pump();
      expect(find.text('3700 / 4000'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'b' * 4100);
      await tester.pump();
      expect(controller.text.length, ChatComposer.maxLength);
      expect(find.text('4000 / 4000'), findsOneWidget);
      expectNoExceptions(tester);
    });

    testWidgets('submitting from the keyboard sends only when allowed',
        (tester) async {
      var sends = 0;
      await pumpComposer(tester, onSend: () => sends++);
      await tester.enterText(find.byType(TextField), '  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(sends, 0);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(sends, 1);
    });
  });
}
