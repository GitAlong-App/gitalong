import '../../domain/entities/match_entity.dart';
import '../../domain/entities/user_entity.dart';

/// Helpers for mapping `matches` rows to [MatchEntity].
class MatchModel {
  MatchModel._();

  /// The `matches.pair_key` for two users: both ids sorted ascending and
  /// joined with `:` (same as the generated column in Postgres).
  static String pairKey(String a, String b) {
    final x = a.toLowerCase();
    final y = b.toLowerCase();
    return x.compareTo(y) <= 0 ? '$x:$y' : '$y:$x';
  }

  /// The id of the member of [row] that is not [myId], or null.
  static String? otherUserId(Map<String, dynamic> row, String myId) {
    final users = row['users'];
    if (users is! List) return null;
    for (final user in users) {
      final id = user?.toString();
      if (id != null && id.isNotEmpty && id != myId) return id;
    }
    return null;
  }

  /// Builds a [MatchEntity] for [myId], computing unread with the contract
  /// rule ([MatchEntity.isUnreadFor]).
  static MatchEntity fromRow(
    Map<String, dynamic> row, {
    required UserEntity otherUser,
    required String myId,
  }) {
    final lastMessage = row['last_message']?.toString();
    final lastMessageSenderId = row['last_message_sender_id']?.toString();
    final rawIsRead = row['is_read'];
    final unread = MatchEntity.isUnreadFor(
      lastMessage: lastMessage,
      isRead: rawIsRead is bool ? rawIsRead : true,
      lastMessageSenderId: lastMessageSenderId,
      myId: myId,
    );

    return MatchEntity(
      id: row['id']?.toString() ?? '',
      user: otherUser,
      matchedAt: _date(row['matched_at']) ?? DateTime.now(),
      lastMessage: lastMessage,
      lastMessageAt: _date(row['last_message_at']),
      lastMessageSenderId: lastMessageSenderId,
      isRead: !unread,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
