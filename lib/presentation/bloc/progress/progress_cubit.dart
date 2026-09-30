import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/achievements.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/entities/progress_entity.dart';
import '../../../domain/repositories/progress_repository.dart';
import 'progress_state.dart';

/// Streaks, XP, levels and achievements for the signed-in user.
///
/// One instance for the whole app (lazy singleton): the HomeScreen provides
/// it with `BlocProvider.value` and shows the achievement toasts and level-up
/// celebrations; any screen can ask for fresh numbers:
///
/// ```dart
/// context.read<ProgressCubit>().refresh(); // inside the Home tabs
/// getIt<ProgressCubit>().refresh();        // pushed routes (e.g. chat)
/// ```
///
/// Call [refresh] after anything that can change progress: a swipe, a sent
/// message, a profile save. Calls are coalesced, so calling it often is fine.
@lazySingleton
class ProgressCubit extends Cubit<ProgressState> {
  ProgressCubit(this._repository) : super(const ProgressInitial());

  final ProgressRepository _repository;

  /// Completes when the current refresh cycle (including queued re-runs)
  /// is done.
  Completer<void>? _pending;

  /// A refresh was requested while one was in flight.
  bool _rerun = false;

  /// Bumped by [reset] so results fetched for a previous session are dropped.
  int _generation = 0;

  /// Milestones already shown to this user (in memory; persisted through the
  /// repository).
  ProgressMilestones? _seen;
  bool _seenLoaded = false;

  /// The latest progress, or null while not loaded / unavailable.
  ProgressEntity? get progress {
    final current = state;
    return current is ProgressLoaded ? current.progress : null;
  }

  /// Reloads progress from the server. Never throws.
  ///
  /// While a load is in flight, further calls are merged into one follow-up
  /// load, and all of them complete together.
  Future<void> refresh() {
    if (isClosed) return Future<void>.value();
    final pending = _pending;
    if (pending != null) {
      _rerun = true;
      return pending.future;
    }
    final completer = Completer<void>();
    _pending = completer;
    unawaited(_drain(completer));
    return completer.future;
  }

  /// Forgets the current user's progress (e.g. when a new session starts)
  /// and goes back to [ProgressInitial]. Results of loads already in flight
  /// are discarded.
  void reset() {
    _generation++;
    _seen = null;
    _seenLoaded = false;
    if (!isClosed) emit(const ProgressInitial());
  }

  Future<void> _drain(Completer<void> completer) async {
    try {
      do {
        _rerun = false;
        await _load();
      } while (_rerun && !isClosed);
    } catch (e, stackTrace) {
      AppLogger.w('Refreshing progress failed', e, stackTrace);
      if (!isClosed && state is! ProgressLoaded) {
        emit(const ProgressUnavailable());
      }
    } finally {
      _pending = null;
      completer.complete();
    }
  }

  Future<void> _load() async {
    final generation = _generation;
    bool stale() => isClosed || generation != _generation;

    final progress = await _repository.getMyProgress();
    if (stale()) return;

    if (progress == null) {
      // Keep showing the last good numbers after a transient failure.
      if (state is! ProgressLoaded) emit(const ProgressUnavailable());
      return;
    }

    if (!_seenLoaded) {
      ProgressMilestones? stored;
      try {
        stored = await _repository.readSeenMilestones();
      } catch (e, stackTrace) {
        AppLogger.w('Reading seen milestones failed', e, stackTrace);
      }
      if (stale()) return;
      _seen = stored;
      _seenLoaded = true;
    }

    final seen = _seen;
    final fresh = newAchievementsSince(seen, progress);
    final leveledUp = leveledUpSince(seen, progress);

    final merged = mergeMilestones(seen, progress);
    if (merged != seen) {
      _seen = merged;
      try {
        await _repository.saveSeenMilestones(merged);
      } catch (e, stackTrace) {
        AppLogger.w('Saving seen milestones failed', e, stackTrace);
      }
      if (stale()) return;
    }

    emit(ProgressLoaded(
      progress: progress,
      newAchievements: fresh,
      leveledUp: leveledUp,
    ));
  }

  /// Known achievements in [progress] that aren't in [seen], in display
  /// order. Nothing is "new" on the first run ([seen] is null): existing
  /// achievements become the baseline instead of a burst of toasts.
  static List<String> newAchievementsSince(
    ProgressMilestones? seen,
    ProgressEntity progress,
  ) {
    if (seen == null) return const [];
    final known = seen.achievements.toSet();
    final fresh = progress.achievements
        .where((key) => !known.contains(key) && Achievements.byKey(key) != null)
        .toList()
      ..sort(
        (a, b) => Achievements.orderOf(a).compareTo(Achievements.orderOf(b)),
      );
    return List<String>.unmodifiable(fresh);
  }

  /// Whether [progress] is above the highest level in [seen] (never on the
  /// first run).
  static bool leveledUpSince(ProgressMilestones? seen, ProgressEntity progress) {
    return seen != null && progress.level > seen.level;
  }

  /// [seen] plus everything in [progress]: the highest level and the union
  /// of achievements, so losing and regaining one never celebrates twice.
  static ProgressMilestones mergeMilestones(
    ProgressMilestones? seen,
    ProgressEntity progress,
  ) {
    final achievements = <String>{
      ...?seen?.achievements,
      ...progress.achievements,
    }.toList();
    return ProgressMilestones(
      level: math.max(seen?.level ?? progress.level, progress.level),
      achievements: List<String>.unmodifiable(achievements),
    );
  }
}
