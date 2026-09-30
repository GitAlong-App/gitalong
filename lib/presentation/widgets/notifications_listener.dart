import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

/// Listens to new-match notifications and shows a SnackBar with "Open" to go
/// to chat. Wrap the authenticated shell (e.g. HomeScreen body) with this.
class NotificationsListener extends StatefulWidget {
  final String userId;
  final Widget child;

  /// Called for every new match (e.g. to refresh the matches list).
  final ValueChanged<NewMatchNotification>? onNewMatch;

  const NotificationsListener({
    super.key,
    required this.userId,
    required this.child,
    this.onNewMatch,
  });

  @override
  State<NotificationsListener> createState() => _NotificationsListenerState();
}

class _NotificationsListenerState extends State<NotificationsListener> {
  StreamSubscription<NewMatchNotification>? _sub;

  @override
  void initState() {
    super.initState();
    final repo = getIt<NotificationRepository>();
    _sub = repo
        .listenToNewMatchNotifications(widget.userId)
        .listen(_onNewMatchNotification, onError: (Object _) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onNewMatchNotification(NewMatchNotification n) {
    if (!mounted) return;
    widget.onNewMatch?.call(n);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You matched with ${n.fromUserName}!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            if (!mounted) return;
            context.push(
              '/chats/${n.matchId}',
              extra: {
                'otherUserName': n.fromUserName,
                'otherUserAvatar': null,
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
