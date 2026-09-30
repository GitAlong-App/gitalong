import 'package:equatable/equatable.dart';

/// In-app notification for "You matched with X!"
class NewMatchNotification extends Equatable {
  /// `notifications.id` — used to mark the row read once it has been shown.
  final String id;
  final String matchId;
  final String? fromUserId;
  final String fromUserName;

  const NewMatchNotification({
    required this.id,
    required this.matchId,
    this.fromUserId,
    required this.fromUserName,
  });

  @override
  List<Object?> get props => [id, matchId, fromUserId, fromUserName];
}
