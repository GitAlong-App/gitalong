import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import '../services/backend_api_client.dart';
import '../../core/utils/logger.dart';

@LazySingleton(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  final SupabaseClient _supabase;
  final BackendApiClient _backend;

  /// Cap on the swipe exclusion list sent in the fallback query, so the
  /// request URL stays well under proxy limits.
  static const int _maxExcludedIds = 300;

  UserRepositoryImpl(this._supabase, this._backend);

  String _requireUserId() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');
    return currentUser.id;
  }

  // ── Profile reads ────────────────────────────────────────────────────────
  // Other people are always read from `public_profiles` (no email, hides
  // blocked users). The `users` table is readable for the own row only.

  @override
  Future<UserEntity> getUserById(String userId) async {
    try {
      final doc = await _supabase
          .from('public_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (doc == null) throw Exception('User not found');
      return UserModel.fromJson(doc).toEntity();
    } catch (e, st) {
      AppLogger.e('Error getting user by id', e, st);
      rethrow;
    }
  }

  @override
  Future<UserEntity> getUserByUsername(String username) async {
    try {
      final doc = await _supabase
          .from('public_profiles')
          .select()
          .eq('username', username)
          .limit(1)
          .maybeSingle();

      if (doc == null) throw Exception('User not found');
      return UserModel.fromJson(doc).toEntity();
    } catch (e, st) {
      AppLogger.e('Error getting user by username', e, st);
      rethrow;
    }
  }

  @override
  Future<UserEntity> getCurrentUserProfile() async {
    try {
      final result = await _supabase.rpc('ensure_user_profile');
      if (result is! Map) throw Exception('Could not load your profile');
      return UserModel.fromJson(
        result.map((key, value) => MapEntry(key.toString(), value)),
      ).toEntity();
    } catch (e, st) {
      AppLogger.e('Error getting current user profile', e, st);
      rethrow;
    }
  }

  // ── Profile writes ───────────────────────────────────────────────────────

  @override
  Future<UserEntity> updateUserProfile(UserEntity user) async {
    try {
      final myId = _requireUserId();

      // Only the editable columns are sent; stats are backend-owned.
      final doc = await _supabase
          .from('users')
          .update(UserModel.fromEntity(user).toUpdateJson())
          .eq('id', myId)
          .select()
          .single();

      return UserModel.fromJson(doc).toEntity();
    } catch (e, st) {
      AppLogger.e('Error updating user profile', e, st);
      rethrow;
    }
  }

  // ── Recommendations: backend ranking, Supabase fallback ──────────────────

  @override
  Future<List<UserEntity>> getRecommendedUsers({
    int limit = 20,
    String? cursor,
  }) async {
    final myId = _requireUserId();
    try {
      AppLogger.i('Fetching recommendations from backend');
      return await _backend.getRecommendations(limit: limit);
    } catch (e) {
      AppLogger.w('Backend recommendations failed ($e), falling back to Supabase');
      return await _fallbackRecommendations(myId, limit);
    }
  }

  // ── GitHub stats refresh via backend ─────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getUserGitHubStats(String username) async {
    try {
      AppLogger.i('Refreshing GitHub stats via backend');
      return await _backend.refreshGitHubStats();
    } catch (e, st) {
      AppLogger.e('Backend refresh-github failed', e, st);
      rethrow;
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────

  @override
  Future<List<UserEntity>> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final docs = await _supabase
          .from('public_profiles')
          .select()
          .gte('username', query)
          .lt('username', '${query}z')
          .limit(limit);

      return docs.map((doc) => UserModel.fromJson(doc).toEntity()).toList();
    } catch (e, st) {
      AppLogger.e('Error searching users', e, st);
      rethrow;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Most recently active developers the user has not swiped on yet.
  /// No ranking or match reasons — used only when the backend is down.
  Future<List<UserEntity>> _fallbackRecommendations(
    String myId,
    int limit,
  ) async {
    final swiped = await _supabase
        .from('swipes')
        .select('swiped_user_id')
        .eq('swiper_id', myId)
        .order('swiped_at', ascending: false)
        .limit(_maxExcludedIds);

    final excludeIds = <String>{
      myId,
      ...swiped
          .map((row) => row['swiped_user_id']?.toString())
          .whereType<String>(),
    };

    final data = await _supabase
        .from('public_profiles')
        .select()
        .not('id', 'in', excludeIds.toList())
        .neq('languages', '{}')
        .order('last_active_at', ascending: false)
        .limit(limit);

    return data
        .map((row) => UserModel.fromJson(row).toEntity())
        .where((user) => user.id.isNotEmpty && user.languages.isNotEmpty)
        .toList();
  }
}
