import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/collab_constants.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/entities/match_entity.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../../core/utils/logger.dart';

/// Match repository implementation.
///
/// Matches are read-only for clients (created by a trigger, deleted to
/// unmatch). Other people's profiles are read from `public_profiles`.
@LazySingleton(as: MatchRepository)
class MatchRepositoryImpl implements MatchRepository {
  final SupabaseClient _supabase;

  MatchRepositoryImpl(this._supabase);

  String _requireUserId() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');
    return currentUser.id;
  }

  @override
  Future<List<MatchEntity>> getMatches({
    int limit = 50,
    String? cursor,
  }) async {
    try {
      final myId = _requireUserId();

      final rows = await _supabase
          .from('matches')
          .select()
          .contains('users', [myId])
          .order('matched_at', ascending: false)
          .limit(limit);

      final otherIds = <String>{};
      for (final row in rows) {
        final otherId = MatchModel.otherUserId(row, myId);
        if (otherId != null) otherIds.add(otherId);
      }
      if (otherIds.isEmpty) return [];

      // One query for every profile instead of one per match.
      final profiles = await _fetchProfiles(otherIds.toList());

      final matches = <MatchEntity>[];
      for (final row in rows) {
        final otherId = MatchModel.otherUserId(row, myId);
        final profile = otherId == null ? null : profiles[otherId];
        // Missing profile = hidden by a block (or deleted); skip the match.
        if (profile == null) continue;
        matches.add(MatchModel.fromRow(row, otherUser: profile, myId: myId));
      }

      AppLogger.d('Found ${matches.length} matches for user $myId');
      return matches;
    } catch (e, stackTrace) {
      AppLogger.e('Error getting matches', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<MatchEntity> getMatchById(String matchId) async {
    try {
      final myId = _requireUserId();

      final row = await _supabase
          .from('matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();

      if (row == null) throw Exception('Match not found');

      final otherId = MatchModel.otherUserId(row, myId);
      if (otherId == null) throw Exception('Match not found');

      final profileRow = await _supabase
          .from('public_profiles')
          .select()
          .eq('id', otherId)
          .maybeSingle();

      if (profileRow == null) throw Exception('User not found');

      return MatchModel.fromRow(
        row,
        otherUser: UserModel.fromJson(profileRow).toEntity(),
        myId: myId,
      );
    } catch (e, stackTrace) {
      AppLogger.e('Error getting match by ID', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> unmatch(String matchId) async {
    try {
      await _supabase.from('matches').delete().eq('id', matchId);
    } catch (e, stackTrace) {
      AppLogger.e('Error unmatching', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> isMatched(String userId) async {
    try {
      final myId = _requireUserId();

      final response = await _supabase
          .from('matches')
          .select('id')
          .eq('pair_key', MatchModel.pairKey(myId, userId))
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      AppLogger.e('Error checking if matched', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    try {
      await _supabase.rpc('block_user', params: {'p_user_id': userId});
    } catch (e, stackTrace) {
      AppLogger.e('Error blocking user', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> reportUser({
    required String userId,
    String? matchId,
    required String reason,
    String? details,
  }) async {
    if (!CollabConstants.isValidReportReason(reason)) {
      throw ArgumentError.value(reason, 'reason', 'Unknown report reason');
    }

    try {
      final myId = _requireUserId();

      var cleanDetails = details?.trim();
      if (cleanDetails != null && cleanDetails.isEmpty) cleanDetails = null;
      if (cleanDetails != null &&
          cleanDetails.length > CollabConstants.reportDetailsMaxLength) {
        cleanDetails =
            cleanDetails.substring(0, CollabConstants.reportDetailsMaxLength);
      }

      await _supabase.from('reports').insert({
        'reporter_id': myId,
        'reported_id': userId,
        'match_id': matchId,
        'reason': reason,
        'details': cleanDetails,
      });
    } catch (e, stackTrace) {
      AppLogger.e('Error reporting user', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> getLikesReceivedCount() async {
    try {
      final result = await _supabase.rpc('get_likes_received_count');
      if (result is num) return result.toInt();
      if (result is String) return int.tryParse(result) ?? 0;
      return 0;
    } catch (e, stackTrace) {
      AppLogger.w('Error getting likes received count', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, UserEntity>> _fetchProfiles(List<String> ids) async {
    final rows = await _supabase
        .from('public_profiles')
        .select()
        .inFilter('id', ids);

    final byId = <String, UserEntity>{};
    for (final row in rows) {
      final user = UserModel.fromJson(row).toEntity();
      if (user.id.isNotEmpty) byId[user.id] = user;
    }
    return byId;
  }
}
