import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/progress_entity.dart';

void main() {
  group('ProgressEntity.levelProgress', () {
    test('is the share of the current level already earned', () {
      const p = ProgressEntity(
        xp: 612,
        level: 4,
        levelFloorXp: 450,
        nextLevelXp: 800,
      );
      // (612 - 450) / (800 - 450) = 162 / 350
      expect(p.levelProgress, closeTo(162 / 350, 1e-9));
      expect(p.xpIntoLevel, 162);
      expect(p.xpToNextLevel, 188);
    });

    test('is 0 at the start of a level and never negative', () {
      const start = ProgressEntity(xp: 450, level: 4, levelFloorXp: 450, nextLevelXp: 800);
      expect(start.levelProgress, 0);

      const behind = ProgressEntity(xp: 400, level: 4, levelFloorXp: 450, nextLevelXp: 800);
      expect(behind.levelProgress, 0);
      expect(behind.xpIntoLevel, 0);
    });

    test('is capped at 1 when XP runs past the next level', () {
      const p = ProgressEntity(xp: 900, level: 4, levelFloorXp: 450, nextLevelXp: 800);
      expect(p.levelProgress, 1);
      expect(p.xpToNextLevel, 0);
    });

    test('handles an empty level span without dividing by zero', () {
      const reached = ProgressEntity(xp: 100, levelFloorXp: 100, nextLevelXp: 100);
      expect(reached.levelProgress, 1);

      const notReached = ProgressEntity(xp: 50, levelFloorXp: 100, nextLevelXp: 100);
      expect(notReached.levelProgress, 0);
    });

    test('defaults describe a brand-new user at level 1', () {
      const p = ProgressEntity();
      expect(p.level, 1);
      expect(p.levelProgress, 0);
      expect(p.xpToNextLevel, 50);
      expect(p.weekActivity, hasLength(7));
    });
  });

  group('ProgressEntity streak and goal', () {
    test('a streak is at risk when the user is not active yet today', () {
      expect(
        const ProgressEntity(streakDays: 4, activeToday: false).isStreakAtRisk,
        isTrue,
      );
      expect(
        const ProgressEntity(streakDays: 4, activeToday: true).isStreakAtRisk,
        isFalse,
      );
      expect(
        const ProgressEntity(streakDays: 0, activeToday: false).isStreakAtRisk,
        isFalse,
      );
    });

    test('goal progress is today\'s swipes over the goal, capped at 1', () {
      const partial = ProgressEntity(todaySwipes: 6, dailyGoal: 10);
      expect(partial.goalProgress, closeTo(0.6, 1e-9));
      expect(partial.goalReached, isFalse);
      expect(partial.goalRemaining, 4);

      const done = ProgressEntity(todaySwipes: 14, dailyGoal: 10);
      expect(done.goalProgress, 1);
      expect(done.goalReached, isTrue);
      expect(done.goalRemaining, 0);

      const none = ProgressEntity(todaySwipes: 0, dailyGoal: 10);
      expect(none.goalProgress, 0);
    });

    test('a zero goal counts as complete', () {
      const p = ProgressEntity(todaySwipes: 0, dailyGoal: 0);
      expect(p.goalProgress, 1);
      expect(p.goalReached, isFalse);
    });

    test('hasAchievement checks the unlocked keys', () {
      const p = ProgressEntity(achievements: ['first_swipe', 'streak_3']);
      expect(p.hasAchievement('streak_3'), isTrue);
      expect(p.hasAchievement('streak_7'), isFalse);
    });

    test('entities with the same values are equal', () {
      expect(
        const ProgressEntity(xp: 10, achievements: ['first_swipe']),
        const ProgressEntity(xp: 10, achievements: ['first_swipe']),
      );
    });
  });
}
