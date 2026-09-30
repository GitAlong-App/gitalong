import '../entities/notification_entity.dart';

/// Streams in-app notifications for the current user (e.g. new_match).
abstract class NotificationRepository {
  /// Stream of unread new-match notifications. Each one is emitted once and
  /// then marked read, so it is not shown again on the next app launch.
  Stream<NewMatchNotification> listenToNewMatchNotifications(String userId);
}
