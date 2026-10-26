import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/theme/app_colors.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/candidate_avatar.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/discover_card.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/swipe_action_bar.dart';
import 'package:gitalong/presentation/screens/swipe/widgets/swipe_stamp.dart';
import 'package:gitalong/presentation/widgets/ui/ui.dart';
import 'package:gitalong/core/theme/phosphor_icons.dart';

import 'helpers.dart';

Widget _card(
  UserEntity user, {
  double height = 520,
  List<String> viewerIntents = const [],
}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      height: height,
      child: DiscoverCard(user: user, viewerIntents: viewerIntents),
    ),
  );
}

void main() {
  group('DiscoverCard', () {
    testWidgets('shows hero, pitch, intents, reasons, languages and stats',
        (tester) async {
      await pumpApp(tester, _card(sampleUser()));
      await settle(tester, total: const Duration(milliseconds: 800));

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('@ada-dev'), findsOneWidget);
      expect(find.text('London, UK'), findsOneWidget);
      expect(find.text('87% MATCH'), findsOneWidget);
      expect(
        find.text('A tiny compiler for punch cards, written in Rust.'),
        findsOneWidget,
      );
      expect(find.text('CO-FOUNDER'), findsOneWidget);
      expect(find.text('OPEN-SOURCE COLLABORATORS'), findsOneWidget);
      expect(find.text('You both write Rust'), findsOneWidget);
      // Language chips keep their case.
      expect(find.text('Rust'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      // Stats (compact counts).
      expect(find.text('42'), findsOneWidget);
      expect(find.text('1.2k'), findsOneWidget);
      expect(find.text('321'), findsOneWidget);
      // Initials avatar (no avatar URL).
      expect(find.text('AL'), findsOneWidget);
      expectNoExceptions(tester);
    });

    testWidgets('match ring fills to the rounded score', (tester) async {
      await pumpApp(tester, _card(sampleUser(matchScore: 64.6)));
      final ring = tester.widget<ProgressRing>(find.byType(ProgressRing));
      expect(ring.value, closeTo(0.65, 1e-9));
      expect(ring.semanticValue, '65%');
      expect(find.text('65% MATCH'), findsOneWidget);
    });

    testWidgets('intents that pair with the viewer are highlighted',
        (tester) async {
      await pumpApp(
        tester,
        _card(
          sampleUser(lookingFor: const ['mentor', 'hackathon']),
          viewerIntents: const ['mentee'],
        ),
      );
      final mentor = tester.widget<GaChip>(
        find.widgetWithText(GaChip, 'I WANT TO MENTOR'),
      );
      final hackathon = tester.widget<GaChip>(
        find.widgetWithText(GaChip, 'HACKATHON TEAMMATES'),
      );
      expect(mentor.selected, isTrue);
      expect(hackathon.selected, isFalse);
    });

    testWidgets('without a score: plain avatar frame, no match pill; '
        'falls back to username, company and bio', (tester) async {
      await pumpApp(
        tester,
        _card(
          sampleUser(
            name: '  ',
            matchScore: null,
            location: null,
            pitch: null,
          ),
        ),
      );
      expect(find.textContaining('% MATCH'), findsNothing);
      expect(find.byType(ProgressRing), findsNothing);
      expect(find.text('ada-dev'), findsOneWidget);
      expect(find.text('Analytical Co'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.briefcase), findsOneWidget);
      expect(find.text('Building tools for analytical engines.'),
          findsOneWidget);
    });

    testWidgets('short card drops the stats row', (tester) async {
      await pumpApp(tester, _card(sampleUser(), height: 230));
      expect(find.text('REPOS'), findsNothing);
      expectNoExceptions(tester);

      await pumpApp(tester, _card(sampleUser(), height: 520));
      expect(find.text('REPOS'), findsOneWidget);
    });

    test('describe() summarises the card for screen readers', () {
      final text = DiscoverCard.describe(sampleUser());
      expect(text, contains('Ada Lovelace'));
      expect(text, contains('@ada-dev'));
      expect(text, contains('87% match'));
      expect(text, contains('Building: A tiny compiler'));
      expect(text, contains('Looking for: Co-founder, Open-source collaborators'));
      expect(text, contains('Why you matched: You both write Rust'));
      expect(text, contains('Languages: Rust, Dart, Go'));
      expect(text, contains('42 repositories, 1234 stars, 321 followers'));
    });

    test('compactCount', () {
      expect(compactCount(950), '950');
      expect(compactCount(1000), '1k');
      expect(compactCount(1234), '1.2k');
      expect(compactCount(12345), '12k');
      expect(compactCount(3400000), '3.4M');
    });

    test('CandidateAvatar.initialsOf', () {
      expect(CandidateAvatar.initialsOf('Ada Lovelace'), 'AL');
      expect(CandidateAvatar.initialsOf('octo-dev'), 'OD');
      expect(CandidateAvatar.initialsOf('solo'), 'S');
      expect(CandidateAvatar.initialsOf('   '), '?');
    });
  });

  group('SwipeActionBar', () {
    testWidgets('each button fires its callback', (tester) async {
      final semantics = tester.ensureSemantics();
      final drag = ValueNotifier(Offset.zero);
      addTearDown(drag.dispose);
      final calls = <String>[];
      await pumpApp(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: SwipeActionBar(
            drag: drag,
            threshold: 120,
            onNope: () => calls.add('nope'),
            onSuperLike: () => calls.add('super'),
            onLike: () => calls.add('like'),
          ),
        ),
      );

      for (final label in ['Nope', 'Super like', 'Like']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(isButton: true, isEnabled: true),
        );
        await tester.tap(find.bySemanticsLabel(label));
        await settle(tester, total: const Duration(milliseconds: 300));
      }
      expect(calls, ['nope', 'super', 'like']);
      semantics.dispose();
    });

    testWidgets('null callbacks disable the buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      final drag = ValueNotifier(Offset.zero);
      addTearDown(drag.dispose);
      await pumpApp(
        tester,
        SwipeActionBar(drag: drag, threshold: 120),
      );
      for (final label in ['Nope', 'Super like', 'Like']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(isEnabled: false, hasTapAction: false),
        );
      }
      semantics.dispose();
    });

    testWidgets('the button in the drag direction swells', (tester) async {
      final drag = ValueNotifier(Offset.zero);
      addTearDown(drag.dispose);
      await pumpApp(
        tester,
        SwipeActionBar(drag: drag, threshold: 100, onLike: () {}),
      );

      double scaleOf(String label) {
        final transform = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byWidgetPredicate(
                  (w) => w is CircleActionButton && w.semanticLabel == label,
                ),
                matching: find.byType(Transform),
              )
              .first,
        );
        return transform.transform.getMaxScaleOnAxis();
      }

      expect(scaleOf('Like'), closeTo(1, 1e-6));
      drag.value = const Offset(100, 0);
      await tester.pump();
      expect(scaleOf('Like'), closeTo(1.15, 1e-6));
      expect(scaleOf('Nope'), closeTo(1, 1e-6));

      drag.value = const Offset(-50, 0);
      await tester.pump();
      expect(scaleOf('Nope'), closeTo(1.075, 1e-6));
      expect(scaleOf('Like'), closeTo(1, 1e-6));

      drag.value = const Offset(0, -200);
      await tester.pump();
      expect(scaleOf('Super like'), closeTo(1.15, 1e-6));
    });
  });

  group('SwipeStamp', () {
    testWidgets('shows the label uppercase with its icon', (tester) async {
      await pumpApp(
        tester,
        const Center(
          child: SwipeStamp(
            label: 'Like',
            icon: PhosphorIconsFill.heart,
            tone: AppTone.green,
          ),
        ),
      );
      expect(find.text('LIKE'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.heart), findsOneWidget);
      expectNoExceptions(tester);
    });

    testWidgets('overlay paints nothing at rest and the right stamp on drag',
        (tester) async {
      Widget overlay({double like = 0, double nope = 0, double superLike = 0}) =>
          SizedBox(
            width: 340,
            height: 500,
            child: SwipeStampsOverlay(
              like: like,
              nope: nope,
              superLike: superLike,
            ),
          );

      await pumpApp(tester, Center(child: overlay()));
      expect(find.byType(SwipeStamp), findsNothing);

      await pumpApp(tester, Center(child: overlay(like: 0.5)));
      expect(find.text('LIKE'), findsOneWidget);
      expect(find.text('NOPE'), findsNothing);
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('LIKE'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, 0.5);

      await pumpApp(tester, Center(child: overlay(nope: 2, superLike: 1)));
      expect(find.text('NOPE'), findsOneWidget);
      expect(find.text('SUPER'), findsOneWidget);
      expectNoExceptions(tester);
    });

    testWidgets('overlay ignores touches', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            const Positioned.fill(
              child: SwipeStampsOverlay(like: 1, nope: 0, superLike: 0),
            ),
          ],
        ),
      );
      await tester.tap(find.text('LIKE'), warnIfMissed: false);
      expect(taps, 1);
    });
  });
}
