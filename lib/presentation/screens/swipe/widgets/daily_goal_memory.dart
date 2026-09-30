import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';

/// Remembers, per user and local day, that the "daily goal reached"
/// celebration has been shown, so it plays once a day, even across restarts.
///
/// Kept in the settings Hive box (opened in `main()`), with an in-memory
/// copy that also covers the case where the box isn't open (e.g. tests).
class DailyGoalMemory {
  DailyGoalMemory._();

  static const String _keyPrefix = 'daily_goal_celebrated_v1_';

  static final Map<String, String> _memory = <String, String>{};

  /// Today's local date, e.g. `2026-09-30` (the progress RPC also counts in
  /// the device's local day).
  static String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  static Box<dynamic>? get _box {
    try {
      if (!Hive.isBoxOpen(AppConstants.settingsBox)) return null;
      return Hive.box<dynamic>(AppConstants.settingsBox);
    } catch (_) {
      // Not available (e.g. tests); the in-memory copy still works.
      return null;
    }
  }

  /// Whether the celebration already ran today for [userId].
  static bool shownToday(String userId) {
    final key = '$_keyPrefix$userId';
    final today = _today();
    if (_memory[key] == today) return true;
    try {
      return _box?.get(key) == today;
    } catch (_) {
      // Unreadable storage: treat it as not shown.
      return false;
    }
  }

  /// Records that the celebration ran today for [userId].
  static void markShownToday(String userId) {
    final key = '$_keyPrefix$userId';
    final today = _today();
    _memory[key] = today;
    final box = _box;
    if (box != null) unawaited(_persist(box, key, today));
  }

  static Future<void> _persist(Box<dynamic> box, String key, String day) async {
    try {
      await box.put(key, day);
    } catch (e, stackTrace) {
      // Best effort: the in-memory copy still prevents a repeat this session.
      AppLogger.w('Saving the daily goal celebration day failed', e, stackTrace);
    }
  }
}
