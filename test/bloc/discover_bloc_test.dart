import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/match_entity.dart';
import 'package:gitalong/domain/entities/swipe_entity.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:gitalong/domain/usecases/swipe/swipe_user_usecase.dart';
import 'package:gitalong/domain/usecases/user/get_recommended_users_usecase.dart';
import 'package:gitalong/presentation/bloc/discover/discover_bloc.dart';
import 'package:gitalong/presentation/bloc/discover/discover_event.dart';
import 'package:gitalong/presentation/bloc/discover/discover_state.dart';

import 'fakes.dart';

const _swipeFailedMessage =
    "Couldn't save that swipe. Check your connection and try again.";

void main() {
  late FakeUserRepository userRepo;
  late FakeSwipeRepository swipeRepo;
  late FakeMatchRepository matchRepo;

  final a = buildUser('a');
  final b = buildUser('b');
  final c = buildUser('c');
  final d = buildUser('d');

  /// A full page (20 entries, the bloc's page size) whose unique, non-empty
  /// users are [unique]: the recommender is not exhausted, but the stack ends
  /// up small enough to trigger a prefetch.
  List<UserEntity> fullPageOf(List<UserEntity> unique) => [
        ...unique,
        buildUser(''), // no id: dropped
        for (var i = unique.length + 1; i < 20; i++) unique.first,
      ];

  /// Responds to recommender calls in order; the last response repeats.
  void recommend(List<FutureOr<List<UserEntity>> Function()> responses) {
    var call = 0;
    userRepo.onGetRecommendedUsers = (_) async {
      final index = call < responses.length ? call : responses.length - 1;
      call++;
      return await responses[index]();
    };
  }

  DiscoverBloc build() => DiscoverBloc(
        GetRecommendedUsersUseCase(userRepo),
        SwipeUserUseCase(swipeRepo),
        matchRepo,
      );

  /// Runs [body] against a fresh bloc and returns every state it emitted.
  Future<List<DiscoverState>> record(
    Future<void> Function(DiscoverBloc bloc) body,
  ) async {
    final bloc = build();
    final states = <DiscoverState>[];
    final sub = bloc.stream.listen(states.add);
    await body(bloc);
    await settle();
    await sub.cancel();
    await bloc.close();
    return states;
  }

  setUp(() {
    userRepo = FakeUserRepository();
    swipeRepo = FakeSwipeRepository();
    matchRepo = FakeMatchRepository();
  });

  group('LoadRecommendationsEvent', () {
    blocTest<DiscoverBloc, DiscoverState>(
      'shows a loader, then the stack with the likes-you count',
      setUp: () {
        recommend([() => [a, b, c]]);
        matchRepo.onGetLikesReceivedCount = () async => 4;
      },
      build: build,
      act: (bloc) => bloc.add(LoadRecommendationsEvent()),
      expect: () => [
        DiscoverLoading(),
        DiscoverLoaded(users: [a, b, c], likesReceivedCount: 4),
      ],
      verify: (_) {
        // A short page means the recommender is exhausted: no prefetch even
        // though only 3 cards are left.
        expect(userRepo.recommendedLimits, [20]);
      },
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'no candidates shows the empty state',
      build: build,
      act: (bloc) => bloc.add(LoadRecommendationsEvent()),
      expect: () => [DiscoverLoading(), DiscoverEmpty()],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'a recommender failure shows an error with the message',
      setUp: () => recommend([() => throw Exception('backend cold')]),
      build: build,
      act: (bloc) => bloc.add(LoadRecommendationsEvent()),
      expect: () => [
        DiscoverLoading(),
        const DiscoverError('Exception: backend cold'),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'a failing likes count does not block the stack (falls back to 0)',
      setUp: () {
        recommend([() => [a]]);
        matchRepo.onGetLikesReceivedCount =
            () async => throw Exception('rpc missing');
      },
      build: build,
      act: (bloc) => bloc.add(LoadRecommendationsEvent()),
      expect: () => [
        DiscoverLoading(),
        DiscoverLoaded(users: [a]),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'drops duplicate users and users without an id',
      setUp: () => recommend([
        () => [a, buildUser(''), b, a, c, b],
      ]),
      build: build,
      act: (bloc) => bloc.add(LoadRecommendationsEvent()),
      expect: () => [
        DiscoverLoading(),
        DiscoverLoaded(users: [a, b, c]),
      ],
    );

    test('a full page that dedupes to a small stack prefetches more', () async {
      recommend([
        () => fullPageOf([a, b]),
        () => [b, c, d], // b is already on the stack
      ]);

      final states = await record((bloc) async {
        bloc.add(LoadRecommendationsEvent());
      });

      expect(states, [
        DiscoverLoading(),
        DiscoverLoaded(users: [a, b]),
        DiscoverLoaded(users: [a, b, c, d]),
      ]);
      expect(userRepo.recommendedLimits, [20, 20]);
    });

    test('the likes count is refreshed by each prefetch', () async {
      recommend([
        () => fullPageOf([a]),
        () => [b],
      ]);
      var likes = 1;
      matchRepo.onGetLikesReceivedCount = () async => likes++;

      final states = await record((bloc) async {
        bloc.add(LoadRecommendationsEvent());
      });

      expect(states.last, DiscoverLoaded(users: [a, b], likesReceivedCount: 2));
      expect(matchRepo.likesReceivedCalls, 2);
    });
  });

  group('prefetching', () {
    test('an empty prefetch marks the recommender exhausted', () async {
      recommend([
        () => fullPageOf([a, b]),
        () => const [],
      ]);

      final states = await record((bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.dislike,
        ));
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'b',
          action: SwipeAction.dislike,
        ));
      });

      // Swiping down to 0 cards never asked the recommender again.
      expect(userRepo.recommendedLimits, [20, 20]);
      expect(states.last, DiscoverEmpty());
      expect(states, contains(DiscoverLoaded(users: [b])));
    });

    test('a manual refresh clears the exhausted flag', () async {
      recommend([
        () => fullPageOf([a]),
        () => const [],
        () => [c],
      ]);

      final bloc = build();
      bloc.add(LoadRecommendationsEvent());
      await settle();
      expect(userRepo.recommendedLimits, hasLength(2));

      bloc.add(LoadRecommendationsEvent());
      await settle();
      expect(userRepo.recommendedLimits, hasLength(3));
      expect(bloc.state, DiscoverLoaded(users: [c]));
      await bloc.close();
    });

    test('a failed prefetch is silent and is retried on the next swipe',
        () async {
      recommend([
        () => fullPageOf([a, b]),
        () => throw Exception('flaky'),
        () => [c],
      ]);

      final states = await record((bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        expect(bloc.state, DiscoverLoaded(users: [a, b]));

        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.like,
        ));
        await settle();
        expect(bloc.state, DiscoverLoaded(users: [b, c]));
      });

      expect(states.whereType<DiscoverError>(), isEmpty);
      expect(userRepo.recommendedLimits, hasLength(3));
    });

    test(
        'swiping the last card while a prefetch is running shows a loading '
        'stack instead of the empty state, and a card swiped meanwhile '
        'never comes back', () async {
      final prefetch = Completer<List<UserEntity>>();
      recommend([
        () => fullPageOf([a]),
        () => prefetch.future,
      ]);

      final states = await record((bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.like,
        ));
        await settle();
        // The prefetch raced the swipe write and still returns `a`.
        prefetch.complete([a, b, c]);
      });

      expect(states, [
        DiscoverLoading(),
        DiscoverLoaded(users: [a]),
        const DiscoverLoaded(users: [], isLoadingMore: true),
        const DiscoverSwipeSaved(users: [], isLoadingMore: true),
        const DiscoverLoaded(users: [], isLoadingMore: true),
        DiscoverLoaded(users: [b, c]),
      ]);
      expect(states.whereType<DiscoverEmpty>(), isEmpty);
    });

    test('a prefetch result is ignored by the UI while a full load is showing '
        'its loader', () async {
      final prefetch = Completer<List<UserEntity>>();
      final reload = Completer<List<UserEntity>>();
      recommend([
        () => fullPageOf([a]),
        () => prefetch.future,
        () => reload.future,
      ]);

      final bloc = build();
      bloc.add(LoadRecommendationsEvent());
      await settle();
      bloc.add(LoadRecommendationsEvent()); // manual refresh
      await settle();
      expect(bloc.state, DiscoverLoading());

      prefetch.complete([b]);
      await settle();
      // Never flash the stack over the loader.
      expect(bloc.state, DiscoverLoading());

      reload.complete([c, d]);
      await settle();
      expect(bloc.state, isA<DiscoverLoaded>());
      await bloc.close();
    });
  });

  group('SwipeUserEvent', () {
    blocTest<DiscoverBloc, DiscoverState>(
      'drops the card optimistically, then confirms the save',
      setUp: () => recommend([() => [a, b, c]]),
      build: build,
      act: (bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.dislike,
        ));
      },
      skip: 2, // loading + initial stack
      expect: () => [
        DiscoverLoaded(users: [b, c]),
        DiscoverSwipeSaved(users: [b, c]),
        DiscoverLoaded(users: [b, c]),
      ],
      verify: (_) => expect(swipeRepo.swipes, [('a', SwipeAction.dislike)]),
    );

    test('the optimistic drop is visible before the write lands', () async {
      recommend([() => [a, b]]);
      final write = Completer<MatchEntity?>();
      swipeRepo.onSwipeUser = (_, __) => write.future;

      final bloc = build();
      bloc.add(LoadRecommendationsEvent());
      await settle();
      bloc.add(const SwipeUserEvent(
        swipedUserId: 'a',
        action: SwipeAction.like,
      ));
      await settle();
      expect(bloc.state, DiscoverLoaded(users: [b]));

      write.complete(null);
      await settle();
      expect(bloc.state, DiscoverLoaded(users: [b]));
      await bloc.close();
    });

    blocTest<DiscoverBloc, DiscoverState>(
      'a mutual like emits DiscoverMatch with the match and the stack',
      setUp: () {
        recommend([() => [a, b]]);
        swipeRepo.onSwipeUser =
            (id, _) async => buildMatch('match_$id', user: a);
      },
      build: build,
      act: (bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.superLike,
        ));
      },
      skip: 2,
      expect: () => [
        DiscoverLoaded(users: [b]),
        DiscoverMatch(match: buildMatch('match_a', user: a), users: [b]),
        DiscoverLoaded(users: [b]),
      ],
      verify: (_) => expect(swipeRepo.swipes, [('a', SwipeAction.superLike)]),
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'a failed write puts the card back behind the top card and reports it',
      setUp: () {
        recommend([() => [a, b, c]]);
        swipeRepo.onSwipeUser = (_, __) async => throw Exception('offline');
      },
      build: build,
      act: (bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.like,
        ));
      },
      skip: 2,
      expect: () => [
        DiscoverLoaded(users: [b, c]),
        DiscoverSwipeFailed(message: _swipeFailedMessage, users: [b, a, c]),
        DiscoverLoaded(users: [b, a, c]),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'a failed write on the last card restores it on top',
      setUp: () {
        recommend([() => [a]]);
        swipeRepo.onSwipeUser = (_, __) async => throw Exception('offline');
      },
      build: build,
      act: (bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.like,
        ));
      },
      skip: 2,
      expect: () => [
        DiscoverEmpty(),
        DiscoverSwipeFailed(message: _swipeFailedMessage, users: [a]),
        DiscoverLoaded(users: [a]),
      ],
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'swiping an unknown card is a no-op',
      setUp: () => recommend([() => [a]]),
      build: build,
      act: (bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'nobody',
          action: SwipeAction.like,
        ));
      },
      skip: 2,
      expect: () => <DiscoverState>[],
      verify: (_) => expect(swipeRepo.swipes, isEmpty),
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'a double-tap on the same card records only one swipe',
      setUp: () => recommend([() => [a, b]]),
      build: build,
      act: (bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc
          ..add(const SwipeUserEvent(
            swipedUserId: 'a',
            action: SwipeAction.like,
          ))
          ..add(const SwipeUserEvent(
            swipedUserId: 'a',
            action: SwipeAction.like,
          ));
      },
      verify: (bloc) {
        expect(swipeRepo.swipes, [('a', SwipeAction.like)]);
        expect(bloc.state, DiscoverLoaded(users: [b]));
      },
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'swiping before anything loaded is a no-op',
      build: build,
      act: (bloc) => bloc.add(const SwipeUserEvent(
        swipedUserId: 'a',
        action: SwipeAction.like,
      )),
      expect: () => <DiscoverState>[],
    );

    test('a swiped card does not come back on refresh', () async {
      recommend([
        () => [a, b],
        () => [a, b, c],
      ]);

      final bloc = build();
      bloc.add(LoadRecommendationsEvent());
      await settle();
      bloc.add(const SwipeUserEvent(
        swipedUserId: 'a',
        action: SwipeAction.dislike,
      ));
      await settle();
      bloc.add(LoadRecommendationsEvent());
      await settle();

      expect(bloc.state, DiscoverLoaded(users: [b, c]));
      await bloc.close();
    });

    test('a card whose swipe failed can come back on refresh', () async {
      recommend([
        () => [a, b],
        () => [a, b],
      ]);
      swipeRepo.onSwipeUser = (_, __) async => throw Exception('offline');

      final bloc = build();
      bloc.add(LoadRecommendationsEvent());
      await settle();
      bloc.add(const SwipeUserEvent(
        swipedUserId: 'a',
        action: SwipeAction.like,
      ));
      await settle();
      bloc.add(LoadRecommendationsEvent());
      await settle();

      expect(bloc.state, DiscoverLoaded(users: [a, b]));
      await bloc.close();
    });

    test('carries the likes-you count through swipe states', () async {
      recommend([() => [a, b]]);
      matchRepo.onGetLikesReceivedCount = () async => 9;
      swipeRepo.onSwipeUser = (id, _) async => buildMatch('x', user: a);

      final states = await record((bloc) async {
        bloc.add(LoadRecommendationsEvent());
        await settle();
        bloc.add(const SwipeUserEvent(
          swipedUserId: 'a',
          action: SwipeAction.like,
        ));
      });

      final match = states.whereType<DiscoverMatch>().single;
      expect(match.likesReceivedCount, 9);
      expect(states.last, DiscoverLoaded(users: [b], likesReceivedCount: 9));
    });
  });
}
