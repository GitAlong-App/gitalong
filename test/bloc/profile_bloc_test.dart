import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/usecases/auth/get_current_user_usecase.dart';
import 'package:gitalong/domain/usecases/match/get_matches_usecase.dart';
import 'package:gitalong/domain/usecases/user/update_user_profile_usecase.dart';
import 'package:gitalong/presentation/bloc/profile/profile_bloc.dart';
import 'package:gitalong/presentation/bloc/profile/profile_event.dart';
import 'package:gitalong/presentation/bloc/profile/profile_state.dart';

import 'fakes.dart';

void main() {
  late FakeAuthRepository authRepo;
  late FakeMatchRepository matchRepo;
  late FakeUserRepository userRepo;
  late FakeBackendApiClient backend;

  final me = buildUser('me', bio: 'Builds things');
  final edited = me.copyWith(bio: 'Builds better things');
  final matches = [
    buildMatch('m1', lastMessage: 'hi', lastMessageSenderId: 'other'),
    buildMatch('m2', lastMessage: 'yo', lastMessageSenderId: 'me'),
    buildMatch('m3'),
  ];

  ProfileBloc build() => ProfileBloc(
        GetCurrentUserUseCase(authRepo),
        GetMatchesUseCase(matchRepo),
        UpdateUserProfileUseCase(userRepo),
        backend,
      );

  setUp(() {
    authRepo = FakeAuthRepository()..onGetCurrentUser = () async => me;
    matchRepo = FakeMatchRepository()..onGetMatches = (_) async => matches;
    userRepo = FakeUserRepository();
    backend = FakeBackendApiClient();
  });

  group('LoadProfileEvent', () {
    blocTest<ProfileBloc, ProfileState>(
      'loads the user with match and chat counts '
      '(chats = matches with a last message)',
      build: build,
      act: (bloc) => bloc.add(LoadProfileEvent()),
      expect: () => [
        ProfileLoading(),
        ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      ],
      verify: (_) => expect(matchRepo.matchLimits, [100]),
    );

    blocTest<ProfileBloc, ProfileState>(
      'zero matches gives zero counts',
      setUp: () => matchRepo.onGetMatches = (_) async => const [],
      build: build,
      act: (bloc) => bloc.add(LoadProfileEvent()),
      expect: () => [
        ProfileLoading(),
        ProfileLoaded(user: me, matchCount: 0, chatCount: 0),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'no signed-in user asks to log in again and skips the matches query',
      setUp: () => authRepo.onGetCurrentUser = () async => null,
      build: build,
      act: (bloc) => bloc.add(LoadProfileEvent()),
      expect: () => [
        ProfileLoading(),
        const ProfileError('User not found. Please log in again.'),
      ],
      verify: (_) => expect(matchRepo.matchLimits, isEmpty),
    );

    blocTest<ProfileBloc, ProfileState>(
      'a failing user lookup emits an error',
      setUp: () =>
          authRepo.onGetCurrentUser = () async => throw Exception('db down'),
      build: build,
      act: (bloc) => bloc.add(LoadProfileEvent()),
      expect: () => [
        ProfileLoading(),
        const ProfileError('Exception: db down'),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'a failing matches query emits an error',
      setUp: () =>
          matchRepo.onGetMatches = (_) async => throw Exception('timeout'),
      build: build,
      act: (bloc) => bloc.add(LoadProfileEvent()),
      expect: () => [
        ProfileLoading(),
        const ProfileError('Exception: timeout'),
      ],
    );
  });

  group('RefreshStatsEvent', () {
    blocTest<ProfileBloc, ProfileState>(
      're-runs the full load with fresh counts',
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 1, chatCount: 0),
      act: (bloc) => bloc.add(RefreshStatsEvent()),
      expect: () => [
        ProfileLoading(),
        ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      ],
    );
  });

  group('UpdateProfileEvent', () {
    blocTest<ProfileBloc, ProfileState>(
      'saves the profile and keeps the existing counts',
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      act: (bloc) => bloc.add(UpdateProfileEvent(edited)),
      expect: () => [
        ProfileUpdating(),
        ProfileLoaded(user: edited, matchCount: 3, chatCount: 2),
      ],
      verify: (_) => expect(userRepo.updatedProfiles, [edited]),
    );

    blocTest<ProfileBloc, ProfileState>(
      'shows what the server returned, not what was sent',
      setUp: () => userRepo.onUpdateUserProfile =
          (user) async => user.copyWith(username: 'server_normalized'),
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      act: (bloc) => bloc.add(UpdateProfileEvent(edited)),
      expect: () => [
        ProfileUpdating(),
        ProfileLoaded(
          user: edited.copyWith(username: 'server_normalized'),
          matchCount: 3,
          chatCount: 2,
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'without a loaded profile (setup flow) counts default to zero',
      build: build,
      act: (bloc) => bloc.add(UpdateProfileEvent(edited)),
      expect: () => [
        ProfileUpdating(),
        ProfileLoaded(user: edited, matchCount: 0, chatCount: 0),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'a failed save emits an error with the failure message',
      setUp: () => userRepo.onUpdateUserProfile =
          (_) async => throw Exception('bio too long'),
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      act: (bloc) => bloc.add(UpdateProfileEvent(edited)),
      expect: () => [
        ProfileUpdating(),
        const ProfileError('Exception: bio too long'),
      ],
    );
  });

  group('RefreshGitHubEvent', () {
    final refreshed = me.copyWith(publicRepos: 42, totalStars: 1000);

    blocTest<ProfileBloc, ProfileState>(
      'refreshes via the backend, reloads the user and keeps counts',
      setUp: () => authRepo.onGetCurrentUser = () async => refreshed,
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      act: (bloc) => bloc.add(RefreshGitHubEvent()),
      expect: () => [
        ProfileUpdating(),
        ProfileLoaded(user: refreshed, matchCount: 3, chatCount: 2),
      ],
      verify: (_) {
        expect(backend.refreshGitHubStatsCalls, 1);
        expect(authRepo.getCurrentUserCalls, 1);
        // Counts are carried over, not re-queried.
        expect(matchRepo.matchLimits, isEmpty);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      'a backend failure shows a friendly error and restores the profile',
      setUp: () => backend.onRefreshGitHubStats =
          () async => throw Exception('Backend returned 503'),
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      act: (bloc) => bloc.add(RefreshGitHubEvent()),
      expect: () => [
        ProfileUpdating(),
        const ProfileError(
          "Couldn't refresh from GitHub right now. Please try again later.",
        ),
        ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      ],
      verify: (_) => expect(authRepo.getCurrentUserCalls, 0),
    );

    blocTest<ProfileBloc, ProfileState>(
      'a backend failure with no loaded profile only emits the error',
      setUp: () => backend.onRefreshGitHubStats =
          () async => throw Exception('no session'),
      build: build,
      act: (bloc) => bloc.add(RefreshGitHubEvent()),
      expect: () => [
        ProfileUpdating(),
        const ProfileError(
          "Couldn't refresh from GitHub right now. Please try again later.",
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'the user vanishing after the refresh is reported',
      setUp: () => authRepo.onGetCurrentUser = () async => null,
      build: build,
      seed: () => ProfileLoaded(user: me, matchCount: 3, chatCount: 2),
      act: (bloc) => bloc.add(RefreshGitHubEvent()),
      expect: () => [
        ProfileUpdating(),
        const ProfileError('User not found after refresh.'),
      ],
    );
  });
}
