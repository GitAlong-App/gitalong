import 'package:flutter/material.dart';

import '../../../core/constants/achievements.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/feedback_service.dart';
import 'ga_toast.dart';

/// The toast tile for a freshly unlocked achievement (gold).
class AchievementToast extends StatelessWidget {
  const AchievementToast({super.key, required this.achievement, this.onTap});

  final AchievementDefinition achievement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GaToast(
      eyebrow: 'Achievement unlocked',
      title: achievement.title,
      message: achievement.description,
      illustration: achievement.illustration,
      tone: AppTone.gold,
      onTap: onTap,
    );
  }
}

/// Slides an [AchievementToast] for [achievementKey] down from the top,
/// holds it for 3 s and slides it away. Queued with other toasts; unknown
/// keys are ignored. Completes when the toast is gone.
///
/// The HomeScreen already calls this for achievements reported by
/// `ProgressCubit`; screens don't need to.
///
/// ```dart
/// showAchievementToast(context, Achievements.firstMatch);
/// ```
Future<void> showAchievementToast(BuildContext context, String achievementKey) {
  final achievement = Achievements.byKey(achievementKey);
  if (achievement == null) return Future<void>.value();
  return enqueueToast(
    context,
    haptic: FeedbackService.mediumTap,
    builder: (dismiss) =>
        AchievementToast(achievement: achievement, onTap: dismiss),
  );
}
