import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/progress_entity.dart';
import '../../domain/repositories/progress_repository.dart';
import '../models/progress_model.dart';

/// [ProgressRepository] backed by the `get_my_progress` RPC, with the
/// "already shown" milestones kept per user in the settings Hive box.
@LazySingleton(as: ProgressRepository)
class ProgressRepositoryImpl implements ProgressRepository {
  final SupabaseClient _supabase;

  ProgressRepositoryImpl(this._supabase);

  static const Duration _timeout = Duration(seconds: 12);
  static const String _seenKeyPrefix = 'progress_seen_v1_';

  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  Future<ProgressEntity?> getMyProgress() async {
    if (_userId == null) return null;
    try {
      final result = await _supabase.rpc(
        'get_my_progress',
        params: {
          'p_tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      ).timeout(_timeout);
      final progress = ProgressModel.fromRpc(result);
      if (progress == null) {
        AppLogger.w('get_my_progress returned an unexpected payload');
      }
      return progress;
    } catch (e, stackTrace) {
      // Expected until the migration is deployed; never block the app.
      AppLogger.w('Progress unavailable', e, stackTrace);
      return null;
    }
  }

  @override
  Future<ProgressMilestones?> readSeenMilestones() async {
    final box = _box;
    final userId = _userId;
    if (box == null || userId == null) return null;
    try {
      final raw = box.get('$_seenKeyPrefix$userId');
      if (raw is! Map) return null;
      final level = raw['level'];
      final achievements = raw['achievements'];
      return ProgressMilestones(
        level: level is int ? level : 1,
        achievements: achievements is List
            ? achievements.map((a) => a.toString()).toList()
            : const [],
      );
    } catch (e, stackTrace) {
      AppLogger.w('Reading seen progress milestones failed', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> saveSeenMilestones(ProgressMilestones milestones) async {
    final box = _box;
    final userId = _userId;
    if (box == null || userId == null) return;
    try {
      await box.put('$_seenKeyPrefix$userId', <String, dynamic>{
        'level': milestones.level,
        'achievements': List<String>.of(milestones.achievements),
      });
    } catch (e, stackTrace) {
      AppLogger.w('Saving seen progress milestones failed', e, stackTrace);
    }
  }

  /// The settings box, opened in `main()` before the app starts.
  Box<dynamic>? get _box {
    try {
      if (!Hive.isBoxOpen(AppConstants.settingsBox)) return null;
      return Hive.box<dynamic>(AppConstants.settingsBox);
    } catch (_) {
      return null;
    }
  }
}
