import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/swipe_entity.dart';
import '../../domain/entities/match_entity.dart';
import '../../domain/repositories/swipe_repository.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../../core/utils/logger.dart';

/// Swipe repository implementation.
///
/// Single write path: an upsert into `swipes`. A database trigger creates
/// the match on a reciprocated like and notifies the other user; the client
/// only ever reads `matches`.
@LazySingleton(as: SwipeRepository)
class SwipeRepositoryImpl implements SwipeRepository {
  final SupabaseClient _supabase;

  SwipeRepositoryImpl(this._supabase);

  String _requireUserId() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');
    return currentUser.id;
  }

  @override
  Future<MatchEntity?> swipeUser({
    required String swipedUserId,
    required SwipeAction action,
  }) async {
    final myId = _requireUserId();

    try {
      await _supabase.from('swipes').upsert(
        {
          'swiper_id': myId,
          'swiped_user_id': swipedUserId,
          'action': action.name,
        },
        onConflict: 'swiper_id,swiped_user_id',
      );
    } catch (e, stackTrace) {
      AppLogger.e('Error swiping user', e, stackTrace);
      rethrow;
    }

    if (action == SwipeAction.dislike) return null;

    // The swipe is stored; a failed lookup must not look like a failed
    // swipe. The match still shows up in the Matches tab.
    try {
      return await checkForMatch(swipedUserId);
    } catch (e, stackTrace) {
      AppLogger.w('Match lookup after swipe failed', e, stackTrace);
      return null;
    }
  }

  @override
  Future<MatchEntity?> checkForMatch(String swipedUserId) async {
    final myId = _requireUserId();

    final matchRow = await _supabase
        .from('matches')
        .select()
        .eq('pair_key', MatchModel.pairKey(myId, swipedUserId))
        .maybeSingle();

    if (matchRow == null) return null;

    final profileRow = await _supabase
        .from('public_profiles')
        .select()
        .eq('id', swipedUserId)
        .maybeSingle();

    // Hidden (e.g. blocked in the meantime) — treat as no match.
    if (profileRow == null) return null;

    return MatchModel.fromRow(
      matchRow,
      otherUser: UserModel.fromJson(profileRow).toEntity(),
      myId: myId,
    );
  }

  @override
  Future<List<SwipeEntity>> getSwipeHistory({
    int limit = 50,
    String? cursor,
  }) async {
    try {
      final myId = _requireUserId();

      final response = await _supabase
          .from('swipes')
          .select()
          .eq('swiper_id', myId)
          .order('swiped_at', ascending: false)
          .limit(limit);

      return response.map((data) {
        final rawAction = data['action']?.toString();
        final swipedAt = data['swiped_at'];
        return SwipeEntity(
          id: data['id']?.toString() ?? '',
          swiperId: data['swiper_id']?.toString() ?? myId,
          swipedUserId: data['swiped_user_id']?.toString() ?? '',
          action: SwipeAction.values.firstWhere(
            (e) => e.name == rawAction,
            orElse: () => SwipeAction.dislike,
          ),
          swipedAt: (swipedAt is String ? DateTime.tryParse(swipedAt) : null) ??
              DateTime.now(),
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.e('Error getting swipe history', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> undoLastSwipe() async {
    try {
      final myId = _requireUserId();

      final lastSwipe = await _supabase
          .from('swipes')
          .select('id')
          .eq('swiper_id', myId)
          .order('swiped_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastSwipe != null) {
        await _supabase.from('swipes').delete().eq('id', lastSwipe['id']);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error undoing last swipe', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<String>> getSwipedUserIds() async {
    try {
      final myId = _requireUserId();

      final swipes = await _supabase
          .from('swipes')
          .select('swiped_user_id')
          .eq('swiper_id', myId);

      return swipes
          .map((doc) => doc['swiped_user_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e('Error getting swiped user IDs', e, stackTrace);
      rethrow;
    }
  }
}
