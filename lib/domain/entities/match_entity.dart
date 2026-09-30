import 'package:equatable/equatable.dart';
import 'user_entity.dart';

/// Match entity
class MatchEntity extends Equatable {
  final String id;

  /// The other member of the match.
  final UserEntity user;
  final DateTime matchedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;

  /// `false` when the signed-in user has an unread message in this match
  /// (see [isUnreadFor]).
  final bool isRead;

  const MatchEntity({
    required this.id,
    required this.user,
    required this.matchedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.isRead = false,
  });

  /// The contract's unread rule: there is a last message, the match's
  /// `is_read` flag is false, and the last message was sent by the other
  /// person (your own messages are never unread for you).
  static bool isUnreadFor({
    required String? lastMessage,
    required bool isRead,
    required String? lastMessageSenderId,
    required String myId,
  }) {
    return lastMessage != null && !isRead && lastMessageSenderId != myId;
  }

  @override
  List<Object?> get props => [
    id,
    user,
    matchedAt,
    lastMessage,
    lastMessageAt,
    lastMessageSenderId,
    isRead,
  ];

  /// Copy with method
  MatchEntity copyWith({
    String? id,
    UserEntity? user,
    DateTime? matchedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    bool? isRead,
  }) {
    return MatchEntity(
      id: id ?? this.id,
      user: user ?? this.user,
      matchedAt: matchedAt ?? this.matchedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isRead: isRead ?? this.isRead,
    );
  }
}
