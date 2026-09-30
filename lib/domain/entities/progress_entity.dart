import 'package:equatable/equatable.dart';

import '../../core/constants/achievements.dart';

/// The signed-in user's gamification state, as returned by the
/// `get_my_progress` RPC (docs/DESIGN_SYSTEM.md §6).
class ProgressEntity extends Equatable {
  /// Consecutive activity days ending today, or ending yesterday when the
  /// user hasn't been active yet today (see [isStreakAtRisk]).
  final int streakDays;

  /// Longest streak ever.
  final int bestStreak;

  /// Whether the user swiped or sent a message today (their local day).
  final bool activeToday;

  /// Activity for the last 7 local days, oldest first; the last entry is
  /// today. Always 7 entries.
  final List<bool> weekActivity;

  /// Swipes made today.
  final int todaySwipes;

  /// Swipes needed today to hit the daily goal.
  final int dailyGoal;

  /// Days on which the daily goal was hit.
  final int goalDays;

  final int totalSwipes;
  final int matches;

  /// Matches in which this user sent the first message.
  final int conversationsStarted;

  /// Matches where both people wrote and there are at least 6 messages.
  final int qualifiedConversations;

  final int messagesSent;

  /// All 8 profile checks pass (server side).
  final bool profileComplete;

  final int xp;

  /// Current level, starting at 1.
  final int level;

  /// XP at which [level] started.
  final int levelFloorXp;

  /// XP needed to reach the next level.
  final int nextLevelXp;

  /// Keys of unlocked achievements (see `Achievements`).
  final List<String> achievements;

  const ProgressEntity({
    this.streakDays = 0,
    this.bestStreak = 0,
    this.activeToday = false,
    this.weekActivity = ProgressEntity.emptyWeek,
    this.todaySwipes = 0,
    this.dailyGoal = Achievements.dailyGoal,
    this.goalDays = 0,
    this.totalSwipes = 0,
    this.matches = 0,
    this.conversationsStarted = 0,
    this.qualifiedConversations = 0,
    this.messagesSent = 0,
    this.profileComplete = false,
    this.xp = 0,
    this.level = 1,
    this.levelFloorXp = 0,
    this.nextLevelXp = 50,
    this.achievements = const [],
  });

  /// Seven inactive days.
  static const List<bool> emptyWeek = [
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  ];

  /// Progress through the current level, 0..1.
  double get levelProgress {
    final span = nextLevelXp - levelFloorXp;
    if (span <= 0) return xp >= nextLevelXp ? 1 : 0;
    return ((xp - levelFloorXp) / span).clamp(0.0, 1.0).toDouble();
  }

  /// XP earned since the current level started (never negative).
  int get xpIntoLevel => xp - levelFloorXp < 0 ? 0 : xp - levelFloorXp;

  /// XP still needed for the next level (never negative).
  int get xpToNextLevel => nextLevelXp - xp < 0 ? 0 : nextLevelXp - xp;

  /// The streak is alive but ends today unless the user swipes or messages
  /// (show a grey flame).
  bool get isStreakAtRisk => streakDays > 0 && !activeToday;

  /// Progress towards today's goal, 0..1.
  double get goalProgress {
    if (dailyGoal <= 0) return 1;
    return (todaySwipes / dailyGoal).clamp(0.0, 1.0).toDouble();
  }

  /// Today's goal is done.
  bool get goalReached => dailyGoal > 0 && todaySwipes >= dailyGoal;

  /// Swipes left to hit today's goal (never negative).
  int get goalRemaining =>
      dailyGoal - todaySwipes < 0 ? 0 : dailyGoal - todaySwipes;

  /// Whether the achievement [key] is unlocked.
  bool hasAchievement(String key) => achievements.contains(key);

  @override
  List<Object?> get props => [
        streakDays,
        bestStreak,
        activeToday,
        weekActivity,
        todaySwipes,
        dailyGoal,
        goalDays,
        totalSwipes,
        matches,
        conversationsStarted,
        qualifiedConversations,
        messagesSent,
        profileComplete,
        xp,
        level,
        levelFloorXp,
        nextLevelXp,
        achievements,
      ];
}

/// What the user has already been shown on this device: the highest level
/// and the achievements that were celebrated. Used to report level-ups and
/// new achievements exactly once.
class ProgressMilestones extends Equatable {
  final int level;
  final List<String> achievements;

  const ProgressMilestones({required this.level, required this.achievements});

  @override
  List<Object?> get props => [level, achievements];
}
