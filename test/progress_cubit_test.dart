import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/progress_entity.dart';
import 'package:gitalong/domain/repositories/progress_repository.dart';
import 'package:gitalong/presentation/bloc/progress/progress_cubit.dart';
import 'package:gitalong/presentation/bloc/progress/progress_state.dart';

/// In-memory repository: [results] are returned in order (the last one
/// repeats); null = RPC unavailable.
class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository(this.results);

  final List<ProgressEntity?> results;
  ProgressMilestones? seen;
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<ProgressEntity?> getMyProgress() async {
    final wait = gate;
    if (wait != null) await wait.future;
    final index = calls < results.length ? calls : results.length - 1;
    calls++;
    return results[index];
  }

  @override
  Future<ProgressMilestones?> readSeenMilestones() async => seen;

  @override
  Future<void> saveSeenMilestones(ProgressMilestones milestones) async {
    seen = milestones;
  }
}

ProgressEntity _progress({int level = 1, List<String> achievements = const []}) {
  return ProgressEntity(
    xp: 50 * (level - 1) * (level - 1),
    level: level,
    levelFloorXp: 50 * (level - 1) * (level - 1),
    nextLevelXp: 50 * level * level,
    achievements: achievements,
  );
}

void main() {
  group('ProgressCubit', () {
    test('first load records a baseline without celebrating', () async {
      final repo = _FakeProgressRepository([
        _progress(level: 3, achievements: ['first_swipe', 'streak_3']),
      ]);
      final cubit = ProgressCubit(repo);

      await cubit.refresh();

      expect(cubit.state, isA<ProgressLoaded>());
      final state = cubit.state as ProgressLoaded;
      expect(state.newAchievements, isEmpty);
      expect(state.leveledUp, isFalse);
      expect(state.hasNews, isFalse);
      expect(repo.seen, const ProgressMilestones(
        level: 3,
        achievements: ['first_swipe', 'streak_3'],
      ));
      expect(cubit.progress?.level, 3);
      await cubit.close();
    });

    test('reports new achievements and a level-up exactly once', () async {
      final repo = _FakeProgressRepository([
        _progress(level: 1, achievements: ['first_swipe']),
        _progress(level: 2, achievements: ['streak_3', 'first_swipe', 'first_match']),
        _progress(level: 2, achievements: ['streak_3', 'first_swipe', 'first_match']),
      ]);
      final cubit = ProgressCubit(repo);

      await cubit.refresh();
      await cubit.refresh();
      final news = cubit.state as ProgressLoaded;
      expect(news.leveledUp, isTrue);
      // Display order, not server order.
      expect(news.newAchievements, ['first_match', 'streak_3']);

      await cubit.refresh();
      final after = cubit.state as ProgressLoaded;
      expect(after.leveledUp, isFalse);
      expect(after.newAchievements, isEmpty);
      await cubit.close();
    });

    test('remembers what was shown across instances (persisted)', () async {
      final repo = _FakeProgressRepository([
        _progress(level: 2, achievements: ['first_swipe']),
      ])
        ..seen = const ProgressMilestones(level: 1, achievements: []);
      final cubit = ProgressCubit(repo);

      await cubit.refresh();
      final state = cubit.state as ProgressLoaded;
      expect(state.leveledUp, isTrue);
      expect(state.newAchievements, ['first_swipe']);
      await cubit.close();

      final again = ProgressCubit(repo);
      await again.refresh();
      expect((again.state as ProgressLoaded).hasNews, isFalse);
      await again.close();
    });

    test('ignores unknown achievement keys', () async {
      final repo = _FakeProgressRepository([
        _progress(achievements: ['from_the_future']),
      ])
        ..seen = const ProgressMilestones(level: 1, achievements: []);
      final cubit = ProgressCubit(repo);

      await cubit.refresh();
      expect((cubit.state as ProgressLoaded).newAchievements, isEmpty);
      await cubit.close();
    });

    test('losing and regaining an achievement does not celebrate twice', () async {
      final repo = _FakeProgressRepository([
        _progress(achievements: ['matches_10']),
        _progress(achievements: []),
        _progress(achievements: ['matches_10']),
      ])
        ..seen = const ProgressMilestones(level: 1, achievements: []);
      final cubit = ProgressCubit(repo);

      await cubit.refresh();
      expect((cubit.state as ProgressLoaded).newAchievements, ['matches_10']);
      await cubit.refresh();
      await cubit.refresh();
      expect((cubit.state as ProgressLoaded).newAchievements, isEmpty);
      await cubit.close();
    });

    test('is unavailable when the RPC fails before anything loaded', () async {
      final cubit = ProgressCubit(_FakeProgressRepository([null]));
      await cubit.refresh();
      expect(cubit.state, isA<ProgressUnavailable>());
      expect(cubit.progress, isNull);
      await cubit.close();
    });

    test('keeps the last good numbers after a later failure', () async {
      final repo = _FakeProgressRepository([_progress(level: 2), null]);
      final cubit = ProgressCubit(repo);

      await cubit.refresh();
      await cubit.refresh();
      expect(cubit.state, isA<ProgressLoaded>());
      expect(cubit.progress?.level, 2);
      await cubit.close();
    });

    test('coalesces refreshes made while one is in flight', () async {
      final repo = _FakeProgressRepository([_progress()])..gate = Completer<void>();
      final cubit = ProgressCubit(repo);

      final first = cubit.refresh();
      final second = cubit.refresh();
      final third = cubit.refresh();
      repo.gate!.complete();
      await Future.wait([first, second, third]);

      // One load plus a single follow-up for the calls made meanwhile.
      expect(repo.calls, 2);
      await cubit.close();
    });

    test('reset drops results that were in flight', () async {
      final gate = Completer<void>();
      final repo = _FakeProgressRepository([_progress(level: 5)])..gate = gate;
      final cubit = ProgressCubit(repo);

      final pending = cubit.refresh();
      cubit.reset();
      expect(cubit.state, isA<ProgressInitial>());
      repo.gate = null;
      gate.complete();
      await pending;

      expect(cubit.state, isA<ProgressInitial>());
      await cubit.refresh();
      expect(cubit.progress?.level, 5);
      await cubit.close();
    });
  });
}
