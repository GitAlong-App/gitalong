import '../entities/progress_entity.dart';

/// Streaks, XP, levels and achievements for the signed-in user.
abstract class ProgressRepository {
  /// Calls `get_my_progress` for the device's time zone.
  ///
  /// Returns null whenever progress is unavailable (signed out, offline, or
  /// the RPC isn't deployed yet). Never throws: the progress UI simply hides.
  Future<ProgressEntity?> getMyProgress();

  /// The milestones the current user was last shown on this device, or null
  /// if they have never been recorded (first run).
  Future<ProgressMilestones?> readSeenMilestones();

  /// Remembers [milestones] as shown for the current user.
  Future<void> saveSeenMilestones(ProgressMilestones milestones);
}
