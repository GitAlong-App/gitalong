import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A change of the signed-in session that the app reacts to.
enum AuthSessionChange {
  /// A session started (e.g. the OAuth deep-link callback landed).
  signedIn,

  /// The session ended (signed out elsewhere, revoked/expired refresh token,
  /// deleted user).
  signedOut,
}

/// The live auth session: who is signed in right now, and when that changes.
///
/// Backed by Supabase in the app ([SupabaseAuthSession]); an interface so the
/// app can be booted without Supabase (integration tests register a fake).
abstract class AuthSession {
  /// The signed-in user's id, or null without a session.
  String? get currentUserId;

  /// Session starts and ends, in order. Errors are forwarded.
  Stream<AuthSessionChange> get changes;
}

@LazySingleton(as: AuthSession)
class SupabaseAuthSession implements AuthSession {
  SupabaseAuthSession(this._client);

  /// The initialized Supabase singleton's session.
  factory SupabaseAuthSession.instance() =>
      SupabaseAuthSession(Supabase.instance.client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<AuthSessionChange> get changes =>
      _client.auth.onAuthStateChange.expand((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn) {
          return const [AuthSessionChange.signedIn];
        }
        // `userDeleted` is deprecated in gotrue; compare by name so this
        // compiles whether or not the enum value still exists.
        if (event == AuthChangeEvent.signedOut || event.name == 'userDeleted') {
          return const [AuthSessionChange.signedOut];
        }
        return const <AuthSessionChange>[];
      });
}
