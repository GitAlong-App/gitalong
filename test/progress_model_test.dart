import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/achievements.dart';
import 'package:gitalong/data/models/progress_model.dart';
import 'package:gitalong/domain/entities/progress_entity.dart';

Map<String, dynamic> _fullPayload() => <String, dynamic>{
      'streak_days': 4,
      'best_streak': 9,
      'active_today': true,
      'week_activity': [false, true, true, false, true, true, true],
      'today_swipes': 6,
      'daily_goal': 10,
      'goal_days': 3,
      'total_swipes': 214,
      'matches': 7,
      'conversations_started': 3,
      'qualified_conversations': 1,
      'messages_sent': 58,
      'profile_complete': false,
      'xp': 612,
      'level': 4,
      'level_floor_xp': 450,
      'next_level_xp': 800,
      'achievements': [
        'first_swipe',
        'explorer_50',
        'first_match',
        'icebreaker',
        'streak_3',
      ],
    };

void main() {
  group('ProgressModel.fromRpc', () {
    test('parses the full payload from the spec', () {
      final parsed = ProgressModel.fromRpc(_fullPayload());
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.streakDays, 4);
      expect(p.bestStreak, 9);
      expect(p.activeToday, isTrue);
      expect(p.weekActivity, [false, true, true, false, true, true, true]);
      expect(p.todaySwipes, 6);
      expect(p.dailyGoal, 10);
      expect(p.goalDays, 3);
      expect(p.totalSwipes, 214);
      expect(p.matches, 7);
      expect(p.conversationsStarted, 3);
      expect(p.qualifiedConversations, 1);
      expect(p.messagesSent, 58);
      expect(p.profileComplete, isFalse);
      expect(p.xp, 612);
      expect(p.level, 4);
      expect(p.levelFloorXp, 450);
      expect(p.nextLevelXp, 800);
      expect(p.achievements, [
        'first_swipe',
        'explorer_50',
        'first_match',
        'icebreaker',
        'streak_3',
      ]);
    });

    test('accepts a single-element list wrapping the object', () {
      final wrapped = ProgressModel.fromRpc([_fullPayload()]);
      expect(wrapped, ProgressModel.fromRpc(_fullPayload()));
    });

    test('accepts a JSON string', () {
      const json = '{"streak_days": 2, "xp": 60, "achievements": ["first_swipe"]}';
      final p = ProgressModel.fromRpc(json);
      expect(p?.streakDays, 2);
      expect(p?.xp, 60);
      expect(p?.achievements, ['first_swipe']);
    });

    test('accepts maps with non-String keys', () {
      final p = ProgressModel.fromRpc(<Object, Object>{'xp': 100, 'level': 2});
      expect(p?.xp, 100);
      expect(p?.level, 2);
    });

    test('returns null for unusable payloads', () {
      expect(ProgressModel.fromRpc(null), isNull);
      expect(ProgressModel.fromRpc(<dynamic>[]), isNull);
      expect(ProgressModel.fromRpc(42), isNull);
      expect(ProgressModel.fromRpc('not json'), isNull);
      expect(ProgressModel.fromRpc(['not a map']), isNull);
    });

    test('an empty object parses to safe defaults', () {
      final parsed = ProgressModel.fromRpc(<String, dynamic>{});
      expect(parsed, isNotNull);
      final p = parsed!;
      expect(p.streakDays, 0);
      expect(p.bestStreak, 0);
      expect(p.activeToday, isFalse);
      expect(p.weekActivity, ProgressEntity.emptyWeek);
      expect(p.todaySwipes, 0);
      expect(p.dailyGoal, Achievements.dailyGoal);
      expect(p.goalDays, 0);
      expect(p.totalSwipes, 0);
      expect(p.matches, 0);
      expect(p.conversationsStarted, 0);
      expect(p.qualifiedConversations, 0);
      expect(p.messagesSent, 0);
      expect(p.profileComplete, isFalse);
      expect(p.xp, 0);
      expect(p.level, 1);
      expect(p.levelFloorXp, 0);
      expect(p.nextLevelXp, 50);
      expect(p.achievements, isEmpty);
    });
  });

  group('ProgressModel.fromJson with partial or odd data', () {
    test('missing fields default to 0 / false / []', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'streak_days': 3,
        'active_today': true,
        'xp': 120,
      });
      expect(p.streakDays, 3);
      expect(p.activeToday, isTrue);
      expect(p.bestStreak, 0);
      expect(p.todaySwipes, 0);
      expect(p.matches, 0);
      expect(p.profileComplete, isFalse);
      expect(p.achievements, isEmpty);
      expect(p.weekActivity, hasLength(7));
    });

    test('derives level fields from XP when they are missing', () {
      final p = ProgressModel.fromJson(<String, dynamic>{'xp': 612});
      expect(p.level, 4);
      expect(p.levelFloorXp, 450);
      expect(p.nextLevelXp, 800);
    });

    test('derives bounds from the level when only the level is sent', () {
      final p = ProgressModel.fromJson(<String, dynamic>{'xp': 300, 'level': 3});
      expect(p.levelFloorXp, 200);
      expect(p.nextLevelXp, 450);
    });

    test('repairs inconsistent level bounds', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'xp': 60,
        'level': 2,
        'level_floor_xp': 200,
        'next_level_xp': 100,
      });
      expect(p.levelFloorXp, 50);
      expect(p.nextLevelXp, 200);
    });

    test('coerces numeric strings, doubles and bool-ish values', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'streak_days': '5',
        'today_swipes': 7.0,
        'xp': '612.9',
        'active_today': 't',
        'profile_complete': 1,
      });
      expect(p.streakDays, 5);
      expect(p.todaySwipes, 7);
      expect(p.xp, 612);
      expect(p.activeToday, isTrue);
      expect(p.profileComplete, isTrue);
    });

    test('negative and garbage numbers become 0', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'streak_days': -3,
        'matches': 'lots',
        'messages_sent': double.nan,
        'total_swipes': 'Infinity',
      });
      expect(p.streakDays, 0);
      expect(p.matches, 0);
      expect(p.messagesSent, 0);
      expect(p.totalSwipes, 0);
    });

    test('a non-positive daily goal falls back to the default', () {
      expect(
        ProgressModel.fromJson(<String, dynamic>{'daily_goal': 0}).dailyGoal,
        Achievements.dailyGoal,
      );
    });

    test('week activity is normalised to 7 days, oldest first', () {
      final short = ProgressModel.fromJson(<String, dynamic>{
        'week_activity': [true, true],
      });
      expect(short.weekActivity, [false, false, false, false, false, true, true]);

      final long = ProgressModel.fromJson(<String, dynamic>{
        'week_activity': [true, false, false, false, false, false, false, false, true],
      });
      expect(long.weekActivity, [false, false, false, false, false, false, true]);
    });

    test('active_today falls back to the last day of the week', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'week_activity': [false, false, false, false, false, false, true],
      });
      expect(p.activeToday, isTrue);
    });

    test('achievements are de-duplicated and cleaned', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'achievements': ['first_swipe', '', null, 'first_swipe', ' streak_3 '],
      });
      expect(p.achievements, ['first_swipe', 'streak_3']);
    });

    test('achievements also parse from a Postgres array literal', () {
      final p = ProgressModel.fromJson(<String, dynamic>{
        'achievements': '{first_swipe,streak_3}',
      });
      expect(p.achievements, ['first_swipe', 'streak_3']);
    });
  });

  group('level formula', () {
    test('matches the server: level = floor(sqrt(xp / 50)) + 1', () {
      const cases = <int, int>{
        0: 1,
        49: 1,
        50: 2,
        199: 2,
        200: 3,
        449: 3,
        450: 4,
        799: 4,
        800: 5,
      };
      cases.forEach((xp, level) {
        expect(ProgressModel.levelForXp(xp), level, reason: 'xp $xp');
      });
    });

    test('level bounds are 50·(level−1)² and 50·level²', () {
      for (var level = 1; level <= 20; level++) {
        final floor = ProgressModel.levelFloorXpFor(level);
        final next = ProgressModel.nextLevelXpFor(level);
        expect(floor, 50 * (level - 1) * (level - 1));
        expect(next, 50 * level * level);
        expect(ProgressModel.levelForXp(floor), level);
        expect(ProgressModel.levelForXp(next - 1), level);
        expect(ProgressModel.levelForXp(next), level + 1);
      }
    });
  });
}
