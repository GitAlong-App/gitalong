import '../entities/match_entity.dart';

/// Match repository interface
abstract class MatchRepository {
  /// Get all matches for current user
  Future<List<MatchEntity>> getMatches({int limit = 50, String? cursor});

  /// Get match by ID
  Future<MatchEntity> getMatchById(String matchId);

  /// Unmatch user (deletes the match and its messages)
  Future<void> unmatch(String matchId);

  /// Check if users are matched
  Future<bool> isMatched(String userId);

  /// Block a user: hides both people from each other and ends any match.
  Future<void> blockUser(String userId);

  /// Report a user. [reason] must be one of `CollabConstants.reportReasons`.
  Future<void> reportUser({
    required String userId,
    String? matchId,
    required String reason,
    String? details,
  });

  /// How many people liked the current user and are waiting on their swipe.
  Future<int> getLikesReceivedCount();
}
