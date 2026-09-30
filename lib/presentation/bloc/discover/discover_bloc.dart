import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/usecases/user/get_recommended_users_usecase.dart';
import '../../../domain/usecases/swipe/swipe_user_usecase.dart';
import 'discover_event.dart';
import 'discover_state.dart';

@injectable
class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  final GetRecommendedUsersUseCase _getRecommendedUsersUseCase;
  final SwipeUserUseCase _swipeUserUseCase;
  final MatchRepository _matchRepository;

  /// Page size requested from the recommender.
  static const int _pageSize = 20;

  /// Fetch more cards once this many (or fewer) remain.
  static const int _prefetchThreshold = 3;

  List<UserEntity> _currentUsers = [];

  /// Everyone swiped in this session, so a prefetch that races the swipe
  /// write can't bring a card back.
  final Set<String> _swipedIds = {};

  bool _isPrefetching = false;

  /// The recommender has nothing new right now; stop prefetching until the
  /// user refreshes manually.
  bool _exhausted = false;

  int _likesReceivedCount = 0;

  DiscoverBloc(
    this._getRecommendedUsersUseCase,
    this._swipeUserUseCase,
    this._matchRepository,
  ) : super(DiscoverInitial()) {
    on<LoadRecommendationsEvent>(_onLoadRecommendations);
    on<PrefetchRecommendationsEvent>(_onPrefetchRecommendations);
    on<SwipeUserEvent>(_onSwipeUser);
  }

  Future<void> _onLoadRecommendations(
    LoadRecommendationsEvent event,
    Emitter<DiscoverState> emit,
  ) async {
    emit(DiscoverLoading());
    _exhausted = false;
    try {
      final likesFuture = _fetchLikesReceivedCount();
      final users = await _getRecommendedUsersUseCase(limit: _pageSize);
      _likesReceivedCount = await likesFuture;

      _currentUsers = _dedupe(users, exclude: _swipedIds);
      // A short page means the recommender has no more candidates.
      _exhausted = users.length < _pageSize;
      _emitStack(emit);
      _maybePrefetch();
    } catch (e) {
      emit(DiscoverError(e.toString()));
    }
  }

  Future<void> _onPrefetchRecommendations(
    PrefetchRecommendationsEvent event,
    Emitter<DiscoverState> emit,
  ) async {
    // _isPrefetching was set by _maybePrefetch.
    try {
      final likesFuture = _fetchLikesReceivedCount();
      final fetched = await _getRecommendedUsersUseCase(limit: _pageSize);
      _likesReceivedCount = await likesFuture;

      final known = <String>{..._swipedIds, ..._currentUsers.map((u) => u.id)};
      final fresh = _dedupe(fetched, exclude: known);
      if (fresh.isEmpty) _exhausted = true;
      _currentUsers.addAll(fresh);
    } catch (e, stackTrace) {
      AppLogger.w('Prefetching recommendations failed', e, stackTrace);
    } finally {
      _isPrefetching = false;
    }

    // Only touch the UI when the stack is showing; never flash a loader.
    final current = state;
    if (current is DiscoverLoaded || current is DiscoverEmpty) {
      _emitStack(emit);
    }
  }

  Future<void> _onSwipeUser(
    SwipeUserEvent event,
    Emitter<DiscoverState> emit,
  ) async {
    final index = _currentUsers.indexWhere((u) => u.id == event.swipedUserId);
    if (index == -1) return;

    // Optimistic: drop the card right away for a snappy UI.
    final swiped = _currentUsers.removeAt(index);
    _swipedIds.add(swiped.id);
    _maybePrefetch();
    _emitStack(emit);

    try {
      final match = await _swipeUserUseCase(
        swipedUserId: event.swipedUserId,
        action: event.action,
      );

      if (match != null) {
        // The database trigger already notified the other person.
        emit(DiscoverMatch(
          match: match,
          users: List.of(_currentUsers),
          likesReceivedCount: _likesReceivedCount,
          isLoadingMore: _isPrefetching,
        ));
        _emitStack(emit);
      } else {
        // The write landed: lets the screen refresh progress (daily goal).
        emit(DiscoverSwipeSaved(
          users: List.of(_currentUsers),
          likesReceivedCount: _likesReceivedCount,
          isLoadingMore: _isPrefetching,
        ));
        _emitStack(emit);
      }
    } catch (e, stackTrace) {
      AppLogger.w('Failed to record swipe', e, stackTrace);
      // Put the card back right behind the current top card so the user can
      // retry — never wipe the stack because of a failed write. Not on top:
      // the failure arrives seconds later and would swap the card under the
      // user's finger (or mid exit-animation).
      _swipedIds.remove(swiped.id);
      if (!_currentUsers.any((u) => u.id == swiped.id)) {
        _currentUsers.insert(_currentUsers.isEmpty ? 0 : 1, swiped);
      }
      emit(DiscoverSwipeFailed(
        message: "Couldn't save that swipe. Check your connection and try again.",
        users: List.of(_currentUsers),
        likesReceivedCount: _likesReceivedCount,
        isLoadingMore: _isPrefetching,
      ));
      _emitStack(emit);
    }
  }

  void _maybePrefetch() {
    if (_isPrefetching || _exhausted) return;
    if (_currentUsers.length > _prefetchThreshold) return;
    _isPrefetching = true;
    add(PrefetchRecommendationsEvent());
  }

  void _emitStack(Emitter<DiscoverState> emit) {
    if (_currentUsers.isEmpty && !_isPrefetching) {
      emit(DiscoverEmpty());
      return;
    }
    emit(DiscoverLoaded(
      users: List.of(_currentUsers),
      likesReceivedCount: _likesReceivedCount,
      isLoadingMore: _isPrefetching,
    ));
  }

  Future<int> _fetchLikesReceivedCount() async {
    try {
      return await _matchRepository.getLikesReceivedCount();
    } catch (_) {
      return _likesReceivedCount;
    }
  }

  static List<UserEntity> _dedupe(
    List<UserEntity> users, {
    required Set<String> exclude,
  }) {
    final seen = <String>{...exclude};
    return users.where((u) => u.id.isNotEmpty && seen.add(u.id)).toList();
  }
}
