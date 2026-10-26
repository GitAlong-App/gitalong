// AuthBloc reaches `Supabase.instance` directly (it follows the session via
// `onAuthStateChange` and checks `auth.currentUser`), so these tests boot a
// real Supabase client wired to in-memory storage and an offline HTTP mock.
// Sessions are injected with `setInitialSession`; nothing touches the network.
import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:gitalong/domain/usecases/auth/delete_account_usecase.dart';
import 'package:gitalong/domain/usecases/auth/get_current_user_usecase.dart';
import 'package:gitalong/domain/usecases/auth/sign_in_with_apple_usecase.dart';
import 'package:gitalong/domain/usecases/auth/sign_in_with_github_usecase.dart';
import 'package:gitalong/domain/usecases/auth/sign_in_with_google_usecase.dart';
import 'package:gitalong/domain/usecases/auth/sign_out_usecase.dart';
import 'package:gitalong/presentation/bloc/auth/auth_bloc.dart';
import 'package:gitalong/presentation/bloc/auth/auth_event.dart';
import 'package:gitalong/presentation/bloc/auth/auth_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'fakes.dart';

const _loadError =
    "Couldn't load your profile. Check your connection and try again.";
const _deleteError =
    "We couldn't delete your account. Check your connection and try again.";

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;
}

GoTrueClient get _auth => Supabase.instance.client.auth;

/// Gives the Supabase client a live session (so `currentUser != null`).
Future<void> _signInSession() async {
  await _auth.setInitialSession(jsonEncode({
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'test-refresh-token',
    'user': {
      'id': 'me',
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2025-01-01T00:00:00Z',
    },
  }));
}

/// Drops the session, then leaves `initialSession` as the replayed auth event
/// so a newly created bloc doesn't see a stale `signedOut`.
Future<void> _clearSession() async {
  if (_auth.currentSession != null) await _auth.signOut();
  // ignore: invalid_use_of_internal_member
  _auth.notifyAllSubscribers(AuthChangeEvent.initialSession);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository repo;
  final me = buildUser('me');

  setUpAll(() async {
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
      // Every request is answered locally (only sign-out's best-effort
      // logout call is expected).
      httpClient: MockClient((_) async => http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          )),
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  setUp(() async {
    repo = FakeAuthRepository();
    await _clearSession();
    await settle();
  });

  AuthBloc build() => AuthBloc(
        GetCurrentUserUseCase(repo),
        SignInWithGitHubUseCase(repo),
        SignInWithGoogleUseCase(repo),
        SignInWithAppleUseCase(repo),
        SignOutUseCase(repo),
        DeleteAccountUseCase(repo),
      );

  test('starts in AuthInitial', () async {
    final bloc = build();
    expect(bloc.state, AuthInitial());
    await bloc.close();
  });

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'profile + live session -> authenticated',
      setUp: () async {
        await _signInSession();
        repo.onGetCurrentUser = () async => me;
      },
      build: build,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [AuthAuthenticated(me)],
    );

    blocTest<AuthBloc, AuthState>(
      'a profile without a Supabase session -> unauthenticated',
      setUp: () => repo.onGetCurrentUser = () async => me,
      build: build,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'no profile -> unauthenticated',
      setUp: () async {
        await _signInSession();
        repo.onGetCurrentUser = () async => null;
      },
      build: build,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'a failing check while signed out shows the error then unauthenticated',
      setUp: () => repo.onGetCurrentUser = () async => throw Exception('500'),
      build: build,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [const AuthError(_loadError), AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'a failing re-check does not throw a signed-in user out',
      setUp: () async {
        await _signInSession();
        repo.onGetCurrentUser = () async => throw Exception('flaky network');
      },
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => <AuthState>[],
      verify: (bloc) => expect(bloc.state, AuthAuthenticated(me)),
    );

    blocTest<AuthBloc, AuthState>(
      'a failing re-check after the session is gone signs the user out',
      setUp: () => repo.onGetCurrentUser = () async => throw Exception('401'),
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [const AuthError(_loadError), AuthUnauthenticated()],
    );

    test('a sign-out that lands while the profile loads wins', () async {
      await _signInSession();
      final profile = Completer<UserEntity?>();
      repo.onGetCurrentUser = () => profile.future;
      final bloc = build();
      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(AuthCheckRequested());
      await settle();
      await _auth.signOut(); // session ends elsewhere
      await settle();
      profile.complete(me);
      await settle();

      expect(states, [AuthUnauthenticated()]);
      expect(states.whereType<AuthAuthenticated>(), isEmpty);
      await sub.cancel();
      await bloc.close();
    });
  });

  group('Supabase auth stream', () {
    test('signedIn (OAuth deep-link callback) triggers a profile check',
        () async {
      await _signInSession();
      repo.onGetCurrentUser = () async => me;
      final bloc = build();
      await settle();
      expect(repo.getCurrentUserCalls, 0, reason: 'initialSession is ignored');

      // ignore: invalid_use_of_internal_member
      _auth.notifyAllSubscribers(AuthChangeEvent.signedIn);
      await settle();

      expect(repo.getCurrentUserCalls, 1);
      expect(bloc.state, AuthAuthenticated(me));
      await bloc.close();
    });

    test('signedOut (revoked/expired session) resets to unauthenticated',
        () async {
      await _signInSession();
      final bloc = build();
      bloc.emit(AuthAuthenticated(me));

      await _auth.signOut();
      await settle();

      expect(bloc.state, AuthUnauthenticated());
      await bloc.close();
    });

    test('after close() stream events are ignored (subscription cancelled)',
        () async {
      await _signInSession();
      final bloc = build();
      await bloc.close();

      // Would throw "Cannot add new events after calling close" if the
      // listener were still attached.
      // ignore: invalid_use_of_internal_member
      _auth.notifyAllSubscribers(AuthChangeEvent.signedIn);
      await _auth.signOut();
      await settle();

      expect(repo.getCurrentUserCalls, 0);
    });
  });

  blocTest<AuthBloc, AuthState>(
    'AuthSessionEndedEvent -> unauthenticated',
    build: build,
    seed: () => AuthAuthenticated(me),
    act: (bloc) => bloc.add(AuthSessionEndedEvent()),
    expect: () => [AuthUnauthenticated()],
  );

  group('SignInWithGitHubEvent', () {
    blocTest<AuthBloc, AuthState>(
      'launches the OAuth flow without emitting (the auth stream signs in)',
      build: build,
      act: (bloc) => bloc.add(SignInWithGitHubEvent()),
      expect: () => <AuthState>[],
      verify: (_) => expect(repo.signInWithGitHubCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'a launch failure shows the error then unauthenticated',
      setUp: () => repo.onSignInWithGitHub =
          () async => throw Exception('Could not launch browser'),
      build: build,
      act: (bloc) => bloc.add(SignInWithGitHubEvent()),
      expect: () => [
        const AuthError('Exception: Could not launch browser'),
        AuthUnauthenticated(),
      ],
    );
  });

  group('SignInWithGoogleEvent', () {
    blocTest<AuthBloc, AuthState>(
      'loading -> authenticated',
      setUp: () => repo.onSignInWithGoogle = () async => me,
      build: build,
      act: (bloc) => bloc.add(SignInWithGoogleEvent()),
      expect: () => [AuthLoading(), AuthAuthenticated(me)],
    );

    blocTest<AuthBloc, AuthState>(
      'failure -> loading, error, unauthenticated',
      setUp: () => repo.onSignInWithGoogle =
          () async => throw Exception('cancelled'),
      build: build,
      act: (bloc) => bloc.add(SignInWithGoogleEvent()),
      expect: () => [
        AuthLoading(),
        const AuthError('Exception: cancelled'),
        AuthUnauthenticated(),
      ],
    );
  });

  group('SignInWithAppleEvent', () {
    blocTest<AuthBloc, AuthState>(
      'loading -> authenticated',
      setUp: () => repo.onSignInWithApple = () async => me,
      build: build,
      act: (bloc) => bloc.add(SignInWithAppleEvent()),
      expect: () => [AuthLoading(), AuthAuthenticated(me)],
    );

    blocTest<AuthBloc, AuthState>(
      'failure -> loading, error, unauthenticated',
      setUp: () =>
          repo.onSignInWithApple = () async => throw Exception('not available'),
      build: build,
      act: (bloc) => bloc.add(SignInWithAppleEvent()),
      expect: () => [
        AuthLoading(),
        const AuthError('Exception: not available'),
        AuthUnauthenticated(),
      ],
    );
  });

  group('SignOutEvent', () {
    blocTest<AuthBloc, AuthState>(
      'loading -> unauthenticated',
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(SignOutEvent()),
      expect: () => [AuthLoading(), AuthUnauthenticated()],
      verify: (_) => expect(repo.signOutCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'still ends unauthenticated when the sign-out call fails',
      setUp: () => repo.onSignOut = () async => throw Exception('offline'),
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(SignOutEvent()),
      expect: () => [AuthLoading(), AuthUnauthenticated()],
    );
  });

  group('DeleteAccountEvent', () {
    blocTest<AuthBloc, AuthState>(
      'loading -> unauthenticated',
      setUp: _signInSession,
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(DeleteAccountEvent()),
      expect: () => [AuthLoading(), AuthUnauthenticated()],
      verify: (_) => expect(repo.deleteAccountCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'a failure keeps a signed-in user signed in',
      setUp: () async {
        await _signInSession();
        repo.onDeleteAccount = () async => throw Exception('503');
      },
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(DeleteAccountEvent()),
      expect: () => [
        AuthLoading(),
        const AuthError(_deleteError),
        AuthAuthenticated(me),
      ],
      verify: (_) => expect(repo.getCurrentUserCalls, 0),
    );

    blocTest<AuthBloc, AuthState>(
      'a failure without a session re-checks: profile still there',
      setUp: () {
        repo.onDeleteAccount = () async => throw Exception('503');
        repo.onGetCurrentUser = () async => me;
      },
      build: build,
      seed: () => AuthAuthenticated(me),
      act: (bloc) => bloc.add(DeleteAccountEvent()),
      expect: () => [
        AuthLoading(),
        const AuthError(_deleteError),
        AuthAuthenticated(me),
      ],
      verify: (_) => expect(repo.getCurrentUserCalls, 1),
    );

    blocTest<AuthBloc, AuthState>(
      'a failure re-check finding no profile -> unauthenticated',
      setUp: () {
        repo.onDeleteAccount = () async => throw Exception('503');
        repo.onGetCurrentUser = () async => null;
      },
      build: build,
      act: (bloc) => bloc.add(DeleteAccountEvent()),
      expect: () => [
        AuthLoading(),
        const AuthError(_deleteError),
        AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'a failing re-check -> unauthenticated',
      setUp: () {
        repo.onDeleteAccount = () async => throw Exception('503');
        repo.onGetCurrentUser = () async => throw Exception('offline');
      },
      build: build,
      act: (bloc) => bloc.add(DeleteAccountEvent()),
      expect: () => [
        AuthLoading(),
        const AuthError(_deleteError),
        AuthUnauthenticated(),
      ],
    );
  });
}
