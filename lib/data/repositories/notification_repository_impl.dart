import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

@LazySingleton(as: NotificationRepository)
class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepositoryImpl(this._supabase);

  @override
  Stream<NewMatchNotification> listenToNewMatchNotifications(String userId) {
    // Guards against re-emitting a row before its read_at update lands (the
    // realtime stream re-sends the whole list on every change).
    final handledIds = <String>{};
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: true)
        .asyncExpand((rows) async* {
          for (final row in rows) {
            final notification = _parseUnreadNewMatch(row);
            if (notification == null) continue;
            if (!handledIds.add(notification.id)) continue;
            yield notification;
            unawaited(_markRead(notification.id));
          }
        });
  }

  /// Only unread `new_match` rows with a match id are surfaced.
  static NewMatchNotification? _parseUnreadNewMatch(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return null;
    if (row['type'] != 'new_match') return null;
    if (row['read_at'] != null) return null;

    final payload = row['payload'];
    if (payload is! Map) return null;
    final matchId = payload['match_id']?.toString();
    if (matchId == null || matchId.isEmpty) return null;

    final fromUserName = payload['from_user_name']?.toString();
    return NewMatchNotification(
      id: id,
      matchId: matchId,
      fromUserId: payload['from_user_id']?.toString(),
      fromUserName: (fromUserName == null || fromUserName.isEmpty)
          ? 'Someone'
          : fromUserName,
    );
  }

  Future<void> _markRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId);
    } catch (e, stackTrace) {
      AppLogger.w('Failed to mark notification $notificationId read', e, stackTrace);
    }
  }
}
