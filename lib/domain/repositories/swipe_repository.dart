import '../entities/swipe_entity.dart';
import '../entities/match_entity.dart';

/// Swipe repository interface
abstract class SwipeRepository {
  /// Record a swipe action. For likes / super likes, returns the match when
  /// the swipe completed one (matches are created by a database trigger).
  Future<MatchEntity?> swipeUser({
    required String swipedUserId,
    required SwipeAction action,
  });

  /// Look up an existing match with [swipedUserId] (read-only).
  Future<MatchEntity?> checkForMatch(String swipedUserId);

  /// Get swipe history
  Future<List<SwipeEntity>> getSwipeHistory({int limit = 50, String? cursor});

  /// Undo last swipe (if within time limit)
  Future<void> undoLastSwipe();

  /// Get already swiped user IDs (to exclude from recommendations)
  Future<List<String>> getSwipedUserIds();
}
