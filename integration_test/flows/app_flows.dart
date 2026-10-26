// End-to-end user flows through the real app (router, blocs, screens) on
// top of in-memory fakes. Shared by integration_test/app_flow_test.dart
// (device) and test/integration_flows_test.dart (headless `flutter test`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:gitalong/core/constants/app_constants.dart';
import 'package:gitalong/core/utils/icebreakers.dart';
import 'package:gitalong/presentation/screens/chat/widgets/chat_composer.dart';
import 'package:gitalong/presentation/screens/chat/widgets/conversation_tile.dart';
import 'package:gitalong/presentation/screens/chat/widgets/message_bubble.dart';
import 'package:gitalong/presentation/screens/splash_screen.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

/// The round 3D button with [label] (Like, Nope, Send message, ...).
Finder circleButton(String label) => find.byWidgetPredicate(
      (widget) => widget is CircleActionButton && widget.semanticLabel == label,
      description: 'CircleActionButton "$label"',
    );

/// A bottom navigation destination.
Finder navTab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

/// The conversation row for [name] in the Matches / Chats lists.
Finder conversationTile(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(ConversationTile),
    );

/// Whether setup's bottom "Continue" button is enabled.
bool continueEnabled(WidgetTester tester) => tester
    .widget<PressableButton>(find.byWidgetPredicate(
      (widget) => widget is PressableButton && widget.label == 'Continue',
    ))
    .onPressed != null;

/// The chat composer's text field.
Finder composerField() => find.descendant(
      of: find.byType(ChatComposer),
      matching: find.byType(TextField),
    );

void defineAppFlows() {
  setUpAll(setUpTestEnvironment);

  group('GitAlong app flows', () {
    testWidgets(
        'a. signed out: splash, onboarding (swipe + tap), login shows GitHub',
        (tester) async {
      final backend = FakeBackend.signedOutNewUser()
        ..sessionLookupDelay = const Duration(milliseconds: 600);
      await bootApp(tester, backend);

      // The session is still resolving: splash is up.
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);

      // No session and onboarding never seen -> onboarding.
      await pumpUntilFound(tester, find.text("Say what you're building"));
      await pumpUntilGone(tester, find.byType(SplashScreen));
      expect(find.text('CONTINUE'), findsOneWidget);

      // Swipe to the second card.
      await tester.fling(
        find.byType(PageView),
        const Offset(-300, 0),
        1000,
      );
      await settle(tester);
      expect(find.text('Get matched on real GitHub work'), findsOneWidget);

      // Tap through to the last card.
      await tapAndSettle(tester, find.text('CONTINUE'));
      expect(find.text('Know why you matched'), findsOneWidget);
      expect(find.text('GET STARTED'), findsOneWidget);

      await tapAndSettle(tester, find.text('GET STARTED'));

      await pumpUntilFound(tester, find.text('CONTINUE WITH GITHUB'));
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      // Persisted before leaving: the router won't show onboarding again.
      expect(
        Hive.box(AppConstants.settingsBox)
            .get(AppConstants.hasSeenOnboardingKey),
        isTrue,
      );

      await shutDownApp(tester, backend);
    });

    testWidgets(
        'b. new GitHub user: login, profile setup (intent, chips, pitch), '
        'lands on Discover', (tester) async {
      final backend = FakeBackend.signedOutNewUser();
      await bootApp(tester, backend, hasSeenOnboarding: true);

      await pumpUntilFound(tester, find.text('CONTINUE WITH GITHUB'));
      await tapAndSettle(tester, find.text('CONTINUE WITH GITHUB'));
      expect(backend.calls, contains('signInWithGitHub'));

      // Signed in without setup answers -> profile setup.
      await pumpUntilFound(tester, find.text('What brings you here?'));

      // Step 1: intent.
      await tapAndSettle(tester, find.text('Side-project partner'));
      await tapAndSettle(tester, find.text('CONTINUE'));

      // Step 2: languages, pre-filled by the background GitHub import.
      await pumpUntilFound(tester, find.text('Which languages do you code in?'));
      expect(backend.calls, contains('refreshGitHubStats'));
      await pumpUntilFound(tester, find.text('2 selected'));
      await tapAndSettle(tester, find.text('DART'));
      expect(find.text('3 selected'), findsOneWidget);
      await tapAndSettle(tester, find.text('CONTINUE'));

      // Step 3: interests (required).
      await pumpUntilFound(tester, find.text('What are you into?'));
      expect(continueEnabled(tester), isFalse);
      await tapAndSettle(tester, find.text('MOBILE DEV'));
      expect(continueEnabled(tester), isTrue);
      await tapAndSettle(tester, find.text('CONTINUE'));

      // Step 4: wanted skills (optional: "Skip for now" until one is picked).
      await pumpUntilFound(
        tester,
        find.text('What should your collaborator bring?'),
      );
      expect(find.text('SKIP FOR NOW'), findsOneWidget);
      await tapAndSettle(tester, find.text('RUST'));
      expect(find.text('SKIP FOR NOW'), findsNothing);
      await tapAndSettle(tester, find.text('CONTINUE'));

      // Step 5: pitch.
      await pumpUntilFound(tester, find.text('What are you building?'));
      const pitch = 'A collaborative markdown editor. Need a Rust dev.';
      await tester.enterText(find.byType(TextField), pitch);
      await settle(tester, const Duration(milliseconds: 300));
      await tapAndSettle(tester, find.text('FINISH'));

      // Saved -> celebration -> home.
      await pumpUntilFound(tester, find.text('START MATCHING'));
      final saved = backend.user(Seed.newUserId);
      expect(saved.lookingFor, ['side_project']);
      expect(saved.languages, containsAll(['TypeScript', 'Python', 'Dart']));
      expect(saved.interests, ['Mobile Dev']);
      expect(saved.seekingSkills, ['Rust']);
      expect(saved.pitch, pitch);

      await tapAndSettle(tester, find.text('START MATCHING'));

      await pumpUntilFound(tester, find.text('Linus Park'));
      expect(navTab('Discover'), findsOneWidget);
      expect(find.text('What brings you here?'), findsNothing);

      await shutDownApp(tester, backend);
    });

    testWidgets(
        'c. discover: reasons on the card, like -> next card, mutual like '
        "-> It's a match -> chat", (tester) async {
      final backend = FakeBackend.signedInWithProfile();
      // A returning user went through onboarding on this device.
      await bootApp(tester, backend, hasSeenOnboarding: true);

      // Signed in with a profile -> straight to Discover.
      await pumpUntilFound(tester, find.text('Linus Park'));
      expect(find.text('@lpark'), findsOneWidget);
      expect(find.text('WHY YOU MATCHED'), findsWidgets);
      expect(find.text(Seed.linusReason), findsOneWidget);
      expect(find.text(Seed.linusReason2), findsOneWidget);
      // Grace already liked the user: the teaser says so.
      expect(
        find.textContaining('1 builder already liked you', findRichText: true),
        findsOneWidget,
      );

      // Like -> the card flies off, Grace is next.
      await tapAndSettle(tester, circleButton('Like'));
      await pumpUntilGone(tester, find.text('Linus Park'));
      expect(backend.calls, contains('swipe:${Seed.linusId}:like'));
      expect(find.text('Grace Kim'), findsOneWidget);
      expect(find.text(Seed.graceReason), findsOneWidget);
      expect(find.text("It's a match!"), findsNothing);

      // Grace liked the user first -> match celebration.
      await tapAndSettle(tester, circleButton('Like'));
      await pumpUntilFound(tester, find.text("It's a match!"));
      expect(
        find.text(
          "You and Grace Kim liked each other. Say hi while it's fresh!",
        ),
        findsOneWidget,
      );
      expect(find.text('KEEP SWIPING'), findsOneWidget);

      // Say hi -> the new, empty chat with icebreakers.
      await tapAndSettle(tester, find.text('SAY HI'));
      await pumpUntilFound(tester, find.text('Say hi to Grace Kim!'));
      expect(find.text("It's a match!"), findsNothing);
      expect(find.text('@gkim'), findsOneWidget);
      expect(composerField(), findsOneWidget);

      await shutDownApp(tester, backend);
    });

    testWidgets(
        'd. chat: icebreaker fills the composer, sent and received messages '
        'appear', (tester) async {
      final backend = FakeBackend.signedInWithProfile();
      // A returning user went through onboarding on this device.
      await bootApp(tester, backend, hasSeenOnboarding: true);
      await pumpUntilFound(tester, find.text('Linus Park'));

      await tapAndSettle(tester, navTab('Chats'));
      await tapAndSettle(tester, conversationTile('Noor Haddad'));
      await pumpUntilFound(tester, find.text('Say hi to Noor Haddad!'));

      // Icebreakers are built from both profiles; tapping one fills the
      // composer.
      final icebreakers = generateIcebreakers(
        me: backend.user(Seed.meId),
        other: backend.user(Seed.noorId),
      );
      expect(icebreakers, isNotEmpty);
      await tapAndSettle(tester, find.text(icebreakers.first));
      expect(
        tester.widget<TextField>(composerField()).controller!.text,
        icebreakers.first,
      );

      // Write our own message instead and send it.
      const message = 'Hey Noor! Want to build the plugin system together?';
      await tester.enterText(composerField(), message);
      await settle(tester, const Duration(milliseconds: 300));
      await tapAndSettle(tester, circleButton('Send message'));

      await pumpUntilFound(
        tester,
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.text(message),
        ),
      );
      expect(find.text('Say hi to Noor Haddad!'), findsNothing);
      expect(
        tester.widget<TextField>(composerField()).controller!.text,
        isEmpty,
      );
      expect(
        backend.messagesOf(Seed.noorMatchId).map((m) => m.content),
        [message],
      );

      // A realtime reply shows up while the chat is open.
      backend.receiveMessage(Seed.noorMatchId, 'Yes! Let us sketch it out.');
      await pumpUntilFound(tester, find.text('Yes! Let us sketch it out.'));
      expect(find.byType(MessageBubble), findsNWidgets(2));

      await shutDownApp(tester, backend);
    });

    testWidgets(
        'e. lists show unread state; profile shows stats and progress; '
        'settings -> sign out returns to login', (tester) async {
      final backend = FakeBackend.signedInWithProfile();
      // A returning user went through onboarding on this device.
      await bootApp(tester, backend, hasSeenOnboarding: true);
      await pumpUntilFound(tester, find.text('Linus Park'));

      // Matches tab: the new match and the conversation.
      await tapAndSettle(tester, navTab('Matches'));
      expect(find.text('New matches'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);

      // Chats tab: Sam's message is unread (NEW pill, bold preview).
      await tapAndSettle(tester, navTab('Chats'));
      final samTile = conversationTile('Sam Rivera');
      expect(samTile, findsOneWidget);
      expect(
        find.descendant(of: samTile, matching: find.text(Seed.samLastMessage)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: samTile, matching: find.text('NEW')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: conversationTile('Noor Haddad'),
          matching: find.text('NEW'),
        ),
        findsNothing,
      );
      // The Chats tab badge counts it.
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(GaBadge),
        ),
        findsWidgets,
      );

      // Opening the chat marks it read; back in the list the pill is gone.
      await tapAndSettle(tester, samTile);
      await pumpUntilFound(
        tester,
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.text(Seed.samLastMessage),
        ),
      );
      expect(backend.isMatchRead(Seed.samMatchId), isTrue);
      await tester.pageBack();
      await settle(tester);
      await pumpUntilFound(tester, find.text('Chats'));
      await pumpUntilGone(
        tester,
        find.descendant(
          of: conversationTile('Sam Rivera'),
          matching: find.text('NEW'),
        ),
      );

      // Profile tab: header, stats and progress.
      await tapAndSettle(tester, navTab('Profile'));
      await pumpUntilFound(tester, find.text('Statistics'));
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('DAY STREAK'), findsOneWidget);
      expect(find.text('Best: 5 days'), findsOneWidget);
      expect(find.text('TOTAL XP'), findsOneWidget);
      expect(find.text('90 XP to level 3'), findsOneWidget);
      expect(find.text('GITHUB STARS'), findsOneWidget);

      // Settings -> Sign out -> confirm -> login.
      await tapAndSettle(tester, find.byTooltip('Settings'));
      await pumpUntilFound(tester, find.text('Dark mode'));
      expect(find.text('Version 1.1.0+2'), findsOneWidget);
      // Below the fold of a lazy list: scroll until it's built.
      await tester.scrollUntilVisible(
        find.text('SIGN OUT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapAndSettle(tester, find.text('SIGN OUT'));
      await pumpUntilFound(tester, find.text('Sign out?'));
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('SIGN OUT'),
        ),
      );

      await pumpUntilFound(tester, find.text('CONTINUE WITH GITHUB'));
      expect(backend.calls, contains('signOut'));
      expect(find.byType(NavigationBar), findsNothing);

      await shutDownApp(tester, backend);
    });
  });
}
