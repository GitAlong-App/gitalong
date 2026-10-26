import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/match_entity.dart';
import 'package:gitalong/domain/usecases/match/get_matches_usecase.dart';
import 'package:gitalong/presentation/bloc/matches/matches_bloc.dart';
import 'package:gitalong/presentation/bloc/matches/matches_event.dart';
import 'package:gitalong/presentation/bloc/matches/matches_state.dart';

import 'fakes.dart';

void main() {
  late FakeMatchRepository repo;

  MatchesBloc build() => MatchesBloc(GetMatchesUseCase(repo));

  final m1 = buildMatch('m1', lastMessage: 'hey', lastMessageSenderId: 'other');
  final m2 = buildMatch('m2');

  setUp(() {
    repo = FakeMatchRepository();
  });

  test('starts in MatchesInitial', () {
    final bloc = build();
    expect(bloc.state, MatchesInitial());
    bloc.close();
  });

  group('LoadMatchesEvent', () {
    blocTest<MatchesBloc, MatchesState>(
      'emits loading then the loaded matches (requests up to 100)',
      setUp: () => repo.onGetMatches = (_) async => [m1, m2],
      build: build,
      act: (bloc) => bloc.add(LoadMatchesEvent()),
      expect: () => [
        MatchesLoading(),
        MatchesLoaded(matches: [m1, m2]),
      ],
      verify: (_) => expect(repo.matchLimits, [100]),
    );

    blocTest<MatchesBloc, MatchesState>(
      'an empty list is a loaded state, not an error',
      build: build,
      act: (bloc) => bloc.add(LoadMatchesEvent()),
      expect: () => [
        MatchesLoading(),
        const MatchesLoaded(matches: []),
      ],
    );

    blocTest<MatchesBloc, MatchesState>(
      'emits an error carrying the failure message when the repository throws',
      setUp: () =>
          repo.onGetMatches = (_) async => throw Exception('network down'),
      build: build,
      act: (bloc) => bloc.add(LoadMatchesEvent()),
      expect: () => [
        MatchesLoading(),
        const MatchesError('Exception: network down'),
      ],
    );

    blocTest<MatchesBloc, MatchesState>(
      'a reload after an error recovers',
      build: build,
      act: (bloc) async {
        repo.onGetMatches = (_) async => throw Exception('boom');
        bloc.add(LoadMatchesEvent());
        await settle();
        repo.onGetMatches = (_) async => [m2];
        bloc.add(LoadMatchesEvent());
      },
      expect: () => [
        MatchesLoading(),
        const MatchesError('Exception: boom'),
        MatchesLoading(),
        MatchesLoaded(matches: [m2]),
      ],
    );
  });

  group('RefreshMatchesEvent', () {
    blocTest<MatchesBloc, MatchesState>(
      'refreshes silently (no loading state)',
      setUp: () => repo.onGetMatches = (_) async => [m1, m2],
      build: build,
      seed: () => MatchesLoaded(matches: [m1]),
      act: (bloc) => bloc.add(RefreshMatchesEvent()),
      expect: () => [
        MatchesLoaded(matches: [m1, m2]),
      ],
      verify: (_) => expect(repo.matchLimits, [100]),
    );

    blocTest<MatchesBloc, MatchesState>(
      'picks up read-state changes (unread badge clears after reading)',
      setUp: () => repo.onGetMatches = (_) async => [m1.copyWith(isRead: true)],
      build: build,
      seed: () => MatchesLoaded(matches: [m1]),
      act: (bloc) => bloc.add(RefreshMatchesEvent()),
      expect: () => [
        MatchesLoaded(matches: [m1.copyWith(isRead: true)]),
      ],
      verify: (bloc) {
        final match = (bloc.state as MatchesLoaded).matches.single;
        expect(
          MatchEntity.isUnreadFor(
            lastMessage: match.lastMessage,
            isRead: match.isRead,
            lastMessageSenderId: match.lastMessageSenderId,
            myId: 'me',
          ),
          isFalse,
        );
      },
    );

    blocTest<MatchesBloc, MatchesState>(
      'identical data does not re-emit',
      setUp: () => repo.onGetMatches = (_) async => [m1],
      build: build,
      seed: () => MatchesLoaded(matches: [m1]),
      act: (bloc) => bloc.add(RefreshMatchesEvent()),
      expect: () => <MatchesState>[],
    );

    blocTest<MatchesBloc, MatchesState>(
      'a failed refresh keeps the list already on screen',
      setUp: () => repo.onGetMatches = (_) async => throw Exception('offline'),
      build: build,
      seed: () => MatchesLoaded(matches: [m1]),
      act: (bloc) => bloc.add(RefreshMatchesEvent()),
      expect: () => <MatchesState>[],
      verify: (bloc) => expect(bloc.state, MatchesLoaded(matches: [m1])),
    );

    blocTest<MatchesBloc, MatchesState>(
      'a failed refresh with nothing loaded yet surfaces the error',
      setUp: () => repo.onGetMatches = (_) async => throw Exception('offline'),
      build: build,
      act: (bloc) => bloc.add(RefreshMatchesEvent()),
      expect: () => [const MatchesError('Exception: offline')],
    );
  });
}
