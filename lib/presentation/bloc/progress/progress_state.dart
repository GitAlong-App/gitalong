import 'package:equatable/equatable.dart';

import '../../../domain/entities/progress_entity.dart';

abstract class ProgressState extends Equatable {
  const ProgressState();

  @override
  List<Object?> get props => [];
}

/// Nothing loaded yet (first load in flight). Hide the progress UI or show
/// a skeleton.
class ProgressInitial extends ProgressState {
  const ProgressInitial();
}

/// Progress is available.
///
/// [newAchievements] (achievement keys, in display order) and [leveledUp]
/// describe what changed since the user was last shown their progress on
/// this device. They are reported once; the next state no longer has them.
class ProgressLoaded extends ProgressState {
  final ProgressEntity progress;

  /// Keys of achievements unlocked since last seen (known keys only).
  final List<String> newAchievements;

  /// The level went up since last seen.
  final bool leveledUp;

  const ProgressLoaded({
    required this.progress,
    this.newAchievements = const [],
    this.leveledUp = false,
  });

  /// Something to celebrate.
  bool get hasNews => leveledUp || newAchievements.isNotEmpty;

  @override
  List<Object?> get props => [progress, newAchievements, leveledUp];
}

/// Progress can't be loaded (e.g. the RPC isn't deployed yet). Hide every
/// progress element; the core flows keep working.
class ProgressUnavailable extends ProgressState {
  const ProgressUnavailable();
}
