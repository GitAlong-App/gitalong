import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/backend_api_client.dart';
import '../../core/utils/logger.dart';

/// Authentication repository implementation
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;
  final BackendApiClient _backendApiClient;

  /// GitHub stats older than this are refreshed in the background.
  static const Duration _githubSyncMaxAge = Duration(hours: 24);

  /// Minimum gap between background refresh attempts, so a GitHub outage
  /// (backend answers 503 and leaves `github_synced_at` unset) doesn't turn
  /// every profile load into another request.
  static const Duration _githubRetryCooldown = Duration(minutes: 10);
  DateTime? _lastGitHubRefreshAttempt;

  AuthRepositoryImpl(
    this._supabase,
    this._googleSignIn,
    this._backendApiClient,
  );

  @override
  Future<UserEntity> signInWithGitHub() async {
    try {
      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'app.gitalong://login-callback/',
      );

      if (!success) {
        throw Exception('Failed to launch GitHub login');
      }

      // Dummy entity since we rely on AuthBloc listening to onAuthStateChange stream!
      return UserEntity(id: '', username: '', email: '', createdAt: DateTime.now());
    } catch (e, stackTrace) {
      AppLogger.e('Error signing in with GitHub', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null || accessToken == null) {
        throw Exception('Missing Google Auth Tokens');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw Exception('Failed to sign in with Google');
      }

      return await _loadOwnProfile();
    } catch (e, stackTrace) {
      AppLogger.e('Error signing in with Google', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserEntity> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Identity token missing');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      if (response.user == null) {
        throw Exception('Failed to sign in with Apple');
      }

      return await _loadOwnProfile();
    } catch (e, stackTrace) {
      AppLogger.e('Error signing in with Apple', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _supabase.auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e, stackTrace) {
      AppLogger.e('Error signing out', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      if (_supabase.auth.currentUser == null) {
        return null;
      }
      return await _loadOwnProfile();
    } catch (e, stackTrace) {
      AppLogger.e('Error getting current user', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return _supabase.auth.currentUser != null;
  }

  @override
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }

    // 1. Backend: full server-side cleanup (auth user, matches, messages...).
    final backendDeleted = await _backendApiClient.deleteAccount();

    // 2. Fallback: the database can delete the account on its own. If this
    //    throws too, the error propagates and the UI shows it — we never
    //    pretend a partial delete worked.
    if (!backendDeleted) {
      AppLogger.w('Backend delete failed, falling back to delete_my_account RPC');
      try {
        await _supabase.rpc('delete_my_account');
      } catch (e, stackTrace) {
        AppLogger.e('delete_my_account RPC failed', e, stackTrace);
        throw Exception('Account deletion failed. Please try again.');
      }
    }

    // 3. The account is gone; clearing the local session must not turn a
    //    successful deletion into an error.
    try {
      await signOut();
    } catch (e, stackTrace) {
      AppLogger.w('Sign-out after account deletion failed (ignored)', e, stackTrace);
    }
  }

  /// Loads (and if necessary creates) the caller's `users` row via the
  /// `ensure_user_profile` RPC, which also bumps `last_active_at`.
  Future<UserEntity> _loadOwnProfile() async {
    final result = await _supabase.rpc('ensure_user_profile');

    Map<String, dynamic>? row;
    if (result is Map) {
      row = result.map((key, value) => MapEntry(key.toString(), value));
    } else if (result is List && result.isNotEmpty && result.first is Map) {
      final first = result.first as Map;
      row = first.map((key, value) => MapEntry(key.toString(), value));
    }

    if (row == null) {
      throw Exception('Could not load your profile');
    }

    final user = UserModel.fromJson(row).toEntity();
    _refreshGitHubIfStale(user);
    return user;
  }

  /// GitHub-derived stats are written by the backend only. If they are
  /// missing or older than [_githubSyncMaxAge], ask the backend to refresh
  /// them without blocking the caller.
  void _refreshGitHubIfStale(UserEntity user) {
    final syncedAt = user.githubSyncedAt;
    final now = DateTime.now();
    final isStale =
        syncedAt == null || now.difference(syncedAt) > _githubSyncMaxAge;
    if (!isStale) return;

    final lastAttempt = _lastGitHubRefreshAttempt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _githubRetryCooldown) {
      return;
    }
    _lastGitHubRefreshAttempt = now;
    unawaited(_refreshGitHubInBackground());
  }

  Future<void> _refreshGitHubInBackground() async {
    try {
      await _backendApiClient.refreshGitHubStats();
      AppLogger.i('GitHub stats refreshed in the background');
    } catch (e, stackTrace) {
      AppLogger.w('Background GitHub refresh failed (non-fatal)', e, stackTrace);
    }
  }
}
