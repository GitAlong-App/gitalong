import 'package:equatable/equatable.dart';
import '../../../domain/entities/swipe_entity.dart';

abstract class DiscoverEvent extends Equatable {
  const DiscoverEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load / manual refresh (shows a full-screen loader).
class LoadRecommendationsEvent extends DiscoverEvent {}

/// Background top-up of the card stack when it runs low (no loader).
class PrefetchRecommendationsEvent extends DiscoverEvent {}

class SwipeUserEvent extends DiscoverEvent {
  final String swipedUserId;
  final SwipeAction action;

  const SwipeUserEvent({
    required this.swipedUserId,
    required this.action,
  });

  @override
  List<Object?> get props => [swipedUserId, action];
}
