import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/theme/app_colors.dart';
import 'package:gitalong/presentation/screens/chat/widgets/chat_avatar.dart';
import 'package:gitalong/presentation/screens/chat/widgets/conversation_tile.dart';
import 'package:gitalong/presentation/screens/chat/widgets/icebreaker_panel.dart';
import 'package:gitalong/presentation/screens/chat/widgets/message_bubble.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import 'helpers.dart';

/// The face colour of the bubble (the inner DecoratedBox under the text).
Color? _bubbleFill(WidgetTester tester, String text) {
  final boxes = find.ancestor(
    of: find.text(text),
    matching: find.byType(DecoratedBox),
  );
  final decoration =
      tester.widget<DecoratedBox>(boxes.first).decoration as BoxDecoration;
  return decoration.color;
}

void main() {
  group('MessageBubble', () {
    testWidgets('mine: right-aligned green bubble, read as "You"',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        MessageBubble(
          message: sampleMessage(content: 'Hello there'),
          isMine: true,
          senderName: 'Ada',
          isGroupTop: true,
          showTime: true,
        ),
      );

      expect(find.text('Hello there'), findsOneWidget);
      expect(_bubbleFill(tester, 'Hello there'), AppColors.green);
      expect(
        tester.getCenter(find.text('Hello there')).dx,
        greaterThan(kDesignSize.width / 2),
      );
      expect(find.bySemanticsLabel(RegExp(r'^You, [\s\S]*Hello there')),
          findsOneWidget);
      // The sent time is shown (and excluded from semantics: it's in the
      // label already).
      expect(find.text('9:30 AM'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets("theirs: left-aligned card bubble, read with the sender's name",
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        MessageBubble(
          message: sampleMessage(content: 'Hi!', senderId: 'u1'),
          isMine: false,
          senderName: 'Ada',
          isGroupTop: false,
          showTime: false,
        ),
      );

      expect(_bubbleFill(tester, 'Hi!'), isNot(AppColors.green));
      expect(
        tester.getCenter(find.text('Hi!')).dx,
        lessThan(kDesignSize.width / 2),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Ada, [\s\S]*Hi!')), findsOneWidget);
      expect(find.text('9:30 AM'), findsNothing);
      semantics.dispose();
    });

    testWidgets('long press calls back and exposes a "Copy message" hint',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var longPresses = 0;
      await pumpApp(
        tester,
        MessageBubble(
          message: sampleMessage(content: 'Copy me'),
          isMine: true,
          senderName: 'Ada',
          isGroupTop: true,
          showTime: false,
          onLongPress: () => longPresses++,
        ),
      );
      await tester.longPress(find.text('Copy me'));
      expect(longPresses, 1);
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Copy me')));
      expect(node, isSemantics(hasLongPressAction: true));
      semantics.dispose();
    });

    testWidgets('code-looking messages use the inset code panel',
        (tester) async {
      const code = 'fn main() {\n  println!("hi");\n}';
      await pumpApp(
        tester,
        MessageBubble(
          message: sampleMessage(content: code),
          isMine: false,
          senderName: 'Ada',
          isGroupTop: true,
          showTime: false,
        ),
      );
      expect(find.text(code), findsOneWidget);
      expect(
        find.ancestor(of: find.text(code), matching: find.byType(Container)),
        findsWidgets,
      );
      expectNoExceptions(tester);
    });

    testWidgets('caps the bubble at 80 % of the screen width', (tester) async {
      await pumpApp(
        tester,
        MessageBubble(
          message: sampleMessage(content: 'word ' * 80),
          isMine: true,
          senderName: 'Ada',
          isGroupTop: true,
          showTime: true,
        ),
      );
      final width = tester.getSize(find.byType(MergeSemantics).first).width;
      expect(width, lessThanOrEqualTo(kDesignSize.width * 0.8 + 0.01));
      expectNoExceptions(tester);
    });

    testWidgets('DaySeparator is a header with the label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, const DaySeparator(label: 'Yesterday'));
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Yesterday')),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
    });
  });

  group('ConversationTile', () {
    testWidgets('unread: NEW pill, green border, "Unread message" label',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(
        tester,
        ConversationTile(
          match: sampleMatch(isRead: false, lastMessageSenderId: 'u1'),
          myUserId: 'me',
          onTap: () => taps++,
        ),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.byType(UnreadPill), findsOneWidget);
      expect(
        find.text('Want to pair on the parser this weekend?'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Ada Lovelace\. Unread message\. ')),
        findsOneWidget,
      );
      expect(
        tester.widget<GaTile>(find.byType(GaTile)).borderColor,
        AppColors.green,
      );

      await tester.tap(find.byType(ConversationTile));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('read: no pill; own last message prefixed with "You:"',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        ConversationTile(
          match: sampleMatch(isRead: true, lastMessageSenderId: 'me'),
          myUserId: 'me',
          onTap: () {},
        ),
      );
      expect(find.byType(UnreadPill), findsNothing);
      expect(find.text('You: Want to pair on the parser this weekend?'),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Unread')), findsNothing);
      expect(tester.widget<GaTile>(find.byType(GaTile)).borderColor, isNull);
      semantics.dispose();
    });

    testWidgets('no messages yet: "New match! Say hi" and never unread',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        ConversationTile(
          match: sampleMatch(lastMessage: null, isRead: false),
          onTap: () {},
        ),
      );
      expect(find.text('New match! Say hi'), findsOneWidget);
      expect(find.byType(UnreadPill), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('New match, no messages yet')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    test('isMatchUnread and compareByRecency', () {
      expect(isMatchUnread(sampleMatch(isRead: false)), isTrue);
      expect(isMatchUnread(sampleMatch(isRead: true)), isFalse);
      expect(isMatchUnread(sampleMatch(lastMessage: null)), isFalse);

      final older = sampleMatch(lastMessageAt: DateTime(2024, 1, 1));
      final newer = sampleMatch(lastMessageAt: DateTime(2025, 6, 1));
      final list = [older, newer]..sort(compareByRecency);
      expect(list.first, same(newer));
    });
  });

  group('IcebreakerPanel', () {
    const openers = [
      'What are you building right now?',
      'Rust or Go for a CLI?',
    ];

    testWidgets('shows the name, the openers and fills on tap',
        (tester) async {
      final picked = <String>[];
      await pumpApp(
        tester,
        IcebreakerPanel(
          name: 'Ada',
          icebreakers: openers,
          loading: false,
          onPick: picked.add,
        ),
      );
      await settle(tester, total: const Duration(seconds: 2));

      expect(find.text('Say hi to Ada!'), findsOneWidget);
      expect(find.byType(OptionCard), findsNWidgets(2));
      await tester.tap(find.text('Rust or Go for a CLI?'));
      await settle(tester, total: const Duration(milliseconds: 300));
      expect(picked, ['Rust or Go for a CLI?']);
    });

    testWidgets('loading: skeletons announced as "Loading icebreakers"',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        IcebreakerPanel(
          name: 'Ada',
          icebreakers: openers,
          loading: true,
          onPick: (_) {},
        ),
      );
      // Skeleton shimmer repeats forever: bounded pumps only.
      await settle(tester, total: const Duration(seconds: 1));
      expect(find.byType(OptionCard), findsNothing);
      expect(find.byType(GaSkeleton), findsNWidgets(3));
      expect(find.bySemanticsLabel('Loading icebreakers'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('null onPick disables the cards', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const IcebreakerPanel(
          name: 'Ada',
          icebreakers: openers,
          loading: false,
          onPick: null,
        ),
        reduceMotion: true,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(openers.first)),
        isSemantics(isEnabled: false, hasTapAction: false),
      );
      semantics.dispose();
    });
  });

  group('ChatAvatar', () {
    testWidgets('initials fallback without a URL; hidden from semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Center(child: ChatAvatar(name: 'Ada Lovelace', size: 52)),
      );
      expect(find.text('AL'), findsOneWidget);
      expect(find.bySemanticsLabel('AL'), findsNothing);
      expect(tester.getSize(find.byType(ChatAvatar)), const Size(52, 52));
      semantics.dispose();
    });
  });
}
