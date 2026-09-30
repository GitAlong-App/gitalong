import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/usecases/match/get_matches_usecase.dart';
import 'matches_event.dart';
import 'matches_state.dart';

/// One instance lives at the HomeScreen level and is shared by the Matches
/// and Chats tabs.
@injectable
class MatchesBloc extends Bloc<MatchesEvent, MatchesState> {
  final GetMatchesUseCase _getMatchesUseCase;

  MatchesBloc(this._getMatchesUseCase) : super(MatchesInitial()) {
    on<LoadMatchesEvent>(_onLoad);
    on<RefreshMatchesEvent>(_onRefresh);
  }

  Future<void> _onLoad(
    LoadMatchesEvent event,
    Emitter<MatchesState> emit,
  ) async {
    emit(MatchesLoading());
    try {
      final matches = await _getMatchesUseCase(limit: 100);
      emit(MatchesLoaded(matches: matches));
    } catch (e) {
      emit(MatchesError(e.toString()));
    }
  }

  /// Silent refresh: no loading state, and a failure keeps the list that is
  /// already on screen.
  Future<void> _onRefresh(
    RefreshMatchesEvent event,
    Emitter<MatchesState> emit,
  ) async {
    try {
      final matches = await _getMatchesUseCase(limit: 100);
      emit(MatchesLoaded(matches: matches));
    } catch (e, stackTrace) {
      AppLogger.w('Refreshing matches failed', e, stackTrace);
      if (state is! MatchesLoaded) {
        emit(MatchesError(e.toString()));
      }
    }
  }
}
