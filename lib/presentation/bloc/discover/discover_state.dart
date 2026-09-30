import 'package:equatable/equatable.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/match_entity.dart';

abstract class DiscoverState extends Equatable {
  const DiscoverState();

  @override
  List<Object?> get props => [];
}

class DiscoverInitial extends DiscoverState {}

class DiscoverLoading extends DiscoverState {}

/// The card stack. [DiscoverMatch] and [DiscoverSwipeFailed] extend this so
/// the stack stays on screen while the UI reacts to them.
class DiscoverLoaded extends DiscoverState {
  final List<UserEntity> users;

  /// People who already liked the current user ("likes you" teaser).
  final int likesReceivedCount;

  /// More cards are being fetched in the background.
  final bool isLoadingMore;

  const DiscoverLoaded({
    required this.users,
    this.likesReceivedCount = 0,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [users, likesReceivedCount, isLoadingMore];
}

class DiscoverEmpty extends DiscoverState {}

class DiscoverError extends DiscoverState {
  final String message;

  const DiscoverError(this.message);

  @override
  List<Object?> get props => [message];
}

/// A swipe completed a match.
class DiscoverMatch extends DiscoverLoaded {
  final MatchEntity match;

  const DiscoverMatch({
    required this.match,
    required super.users,
    super.likesReceivedCount,
    super.isLoadingMore,
  });

  @override
  List<Object?> get props => [match, users, likesReceivedCount, isLoadingMore];
}

/// A swipe was saved and didn't make a match. Emitted once the write has
/// landed (the card itself was dropped optimistically before), so listeners
/// can refresh progress: the daily goal and XP now include this swipe.
class DiscoverSwipeSaved extends DiscoverLoaded {
  const DiscoverSwipeSaved({
    required super.users,
    super.likesReceivedCount,
    super.isLoadingMore,
  });
}

/// A swipe could not be saved; the card was put back on top of the stack.
class DiscoverSwipeFailed extends DiscoverLoaded {
  final String message;

  const DiscoverSwipeFailed({
    required this.message,
    required super.users,
    super.likesReceivedCount,
    super.isLoadingMore,
  });

  @override
  List<Object?> get props => [message, users, likesReceivedCount, isLoadingMore];
}
