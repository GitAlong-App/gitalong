import 'illustrations.dart';

/// One achievement a user can unlock (docs/DESIGN_SYSTEM.md §6).
///
/// The server decides what is unlocked (`get_my_progress().achievements`);
/// the app only knows how to present each [key].
class AchievementDefinition {
  /// Stable key returned by the RPC, e.g. `first_swipe`.
  final String key;

  /// Illustration name (see `Illustrations`).
  final String illustration;

  /// Short title, e.g. "On fire".
  final String title;

  /// How to earn it, e.g. "Reach a 3-day streak".
  final String description;

  const AchievementDefinition({
    required this.key,
    required this.illustration,
    required this.title,
    required this.description,
  });

  @override
  String toString() => 'AchievementDefinition($key)';
}

/// The achievement catalogue and the daily goal, shared with the website and
/// the `get_my_progress` RPC.
class Achievements {
  Achievements._();

  /// Builders to review (swipes) per day.
  static const int dailyGoal = 10;

  static const String firstSwipe = 'first_swipe';
  static const String explorer50 = 'explorer_50';
  static const String firstMatch = 'first_match';
  static const String matches10 = 'matches_10';
  static const String icebreaker = 'icebreaker';
  static const String realTalk = 'real_talk';
  static const String streak3 = 'streak_3';
  static const String streak7 = 'streak_7';
  static const String goalCrusher = 'goal_crusher';
  static const String profileComplete = 'profile_complete';

  /// All achievements, in display order.
  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      key: firstSwipe,
      illustration: Illustrations.seedling,
      title: 'First steps',
      description: 'Review your first builder',
    ),
    AchievementDefinition(
      key: explorer50,
      illustration: Illustrations.compass,
      title: 'Explorer',
      description: 'Review 50 builders',
    ),
    AchievementDefinition(
      key: firstMatch,
      illustration: Illustrations.handshake,
      title: "It's a match!",
      description: 'Get your first match',
    ),
    AchievementDefinition(
      key: matches10,
      illustration: Illustrations.link,
      title: 'Connector',
      description: 'Get 10 matches',
    ),
    AchievementDefinition(
      key: icebreaker,
      illustration: Illustrations.speechBalloon,
      title: 'Icebreaker',
      description: 'Send the first message in a match',
    ),
    AchievementDefinition(
      key: realTalk,
      illustration: Illustrations.busts,
      title: 'Real talk',
      description: 'Have a real conversation: both of you write, 6+ messages',
    ),
    AchievementDefinition(
      key: streak3,
      illustration: Illustrations.fire,
      title: 'On fire',
      description: 'Reach a 3-day streak',
    ),
    AchievementDefinition(
      key: streak7,
      illustration: Illustrations.highVoltage,
      title: 'Unstoppable',
      description: 'Reach a 7-day streak',
    ),
    AchievementDefinition(
      key: goalCrusher,
      illustration: Illustrations.trophy,
      title: 'Goal crusher',
      description: 'Hit your daily goal on 5 days',
    ),
    AchievementDefinition(
      key: profileComplete,
      illustration: Illustrations.hundredPoints,
      title: 'All set',
      description: 'Complete your profile',
    ),
  ];

  /// The definition for [key], or null for keys this app version doesn't
  /// know yet.
  static AchievementDefinition? byKey(String key) {
    for (final achievement in all) {
      if (achievement.key == key) return achievement;
    }
    return null;
  }

  /// Position of [key] in [all] (unknown keys sort last).
  static int orderOf(String key) {
    for (var i = 0; i < all.length; i++) {
      if (all[i].key == key) return i;
    }
    return all.length;
  }
}
