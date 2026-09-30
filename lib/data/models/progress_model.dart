import 'dart:convert';
import 'dart:math' as math;

import '../../core/constants/achievements.dart';
import '../../domain/entities/progress_entity.dart';

/// Defensive parser for the `get_my_progress` RPC payload
/// (docs/DESIGN_SYSTEM.md §6).
///
/// Never throws: unknown shapes return null, and missing or malformed
/// fields fall back to safe defaults — counters 0, flags false, lists empty
/// (the week is padded to 7 days). Level fields are derived from XP with the
/// server's formula when absent, so the UI never shows "level 0".
class ProgressModel {
  ProgressModel._();

  /// Parses the raw RPC result: a JSON object, a single-element list
  /// wrapping one, or a JSON string of either. Returns null when there is
  /// nothing usable.
  static ProgressEntity? fromRpc(Object? raw) {
    Object? value = raw;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    if (value is List) {
      if (value.isEmpty) return null;
      value = value.first;
    }
    if (value is! Map) return null;
    return fromJson(
      value.map((key, v) => MapEntry(key.toString(), v)),
    );
  }

  /// Builds a [ProgressEntity] from a decoded JSON object.
  static ProgressEntity fromJson(Map<String, dynamic> json) {
    final xp = _count(json['xp']);

    var level = _count(json['level']);
    if (level < 1) level = levelForXp(xp);

    var floor = json['level_floor_xp'] == null
        ? levelFloorXpFor(level)
        : _count(json['level_floor_xp']);
    var next = json['next_level_xp'] == null
        ? nextLevelXpFor(level)
        : _count(json['next_level_xp']);
    if (next <= floor) {
      floor = levelFloorXpFor(level);
      next = nextLevelXpFor(level);
    }

    final dailyGoal = _count(json['daily_goal']);
    final week = _week(json['week_activity']);

    return ProgressEntity(
      streakDays: _count(json['streak_days']),
      bestStreak: _count(json['best_streak']),
      activeToday: json.containsKey('active_today')
          ? _bool(json['active_today'])
          : week.last,
      weekActivity: week,
      todaySwipes: _count(json['today_swipes']),
      dailyGoal: dailyGoal > 0 ? dailyGoal : Achievements.dailyGoal,
      goalDays: _count(json['goal_days']),
      totalSwipes: _count(json['total_swipes']),
      matches: _count(json['matches']),
      conversationsStarted: _count(json['conversations_started']),
      qualifiedConversations: _count(json['qualified_conversations']),
      messagesSent: _count(json['messages_sent']),
      profileComplete: _bool(json['profile_complete']),
      xp: xp,
      level: level,
      levelFloorXp: floor,
      nextLevelXp: next,
      achievements: _strings(json['achievements']),
    );
  }

  /// Level for [xp]: ⌊√(xp / 50)⌋ + 1.
  static int levelForXp(int xp) => math.sqrt(math.max(xp, 0) / 50).floor() + 1;

  /// XP at which [level] starts: 50·(level − 1)².
  static int levelFloorXpFor(int level) => 50 * (level - 1) * (level - 1);

  /// XP needed for the level after [level]: 50·level².
  static int nextLevelXpFor(int level) => 50 * level * level;

  // ── Field parsers ─────────────────────────────────────────────────────────

  /// A non-negative whole number from an int, double or numeric string.
  static int _count(Object? value) {
    int? parsed;
    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.isFinite ? value.toInt() : null;
    } else if (value is String) {
      final text = value.trim();
      parsed = int.tryParse(text);
      if (parsed == null) {
        final asDouble = double.tryParse(text);
        if (asDouble != null && asDouble.isFinite) parsed = asDouble.toInt();
      }
    }
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text == 'true' || text == 't' || text == '1' || text == 'yes';
    }
    return false;
  }

  /// Exactly 7 days, oldest first: longer lists keep the last 7, shorter
  /// ones are padded with inactive days at the start.
  static List<bool> _week(Object? value) {
    if (value is! List) return ProgressEntity.emptyWeek;
    final days = value.map(_bool).toList();
    if (days.length >= 7) {
      return List<bool>.unmodifiable(days.sublist(days.length - 7));
    }
    return List<bool>.unmodifiable([
      ...List<bool>.filled(7 - days.length, false),
      ...days,
    ]);
  }

  /// Distinct non-empty strings, in order. Also accepts a Postgres array
  /// literal such as `{first_swipe,streak_3}`.
  static List<String> _strings(Object? value) {
    Iterable<Object?> items;
    if (value is List) {
      items = value;
    } else if (value is String) {
      var text = value.trim();
      if (text.startsWith('{') && text.endsWith('}')) {
        text = text.substring(1, text.length - 1);
      }
      items = text.split(',');
    } else {
      return const [];
    }

    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      if (item == null) continue;
      final text = item.toString().trim().replaceAll('"', '');
      if (text.isEmpty) continue;
      if (seen.add(text)) result.add(text);
    }
    return List<String>.unmodifiable(result);
  }
}
