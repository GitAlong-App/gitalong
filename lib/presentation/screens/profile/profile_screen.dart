import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/achievements.dart';
import '../../../core/constants/illustrations.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import '../../../domain/entities/progress_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/progress/profile_strength.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../bloc/progress/progress_cubit.dart';
import '../../bloc/progress/progress_state.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/achievements_grid.dart';
import 'widgets/equal_height_row.dart';
import 'widgets/external_link.dart';
import 'widgets/profile_about_tile.dart';
import 'widgets/profile_checklist_tile.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_skeleton.dart';
import 'widgets/stat_tile.dart';

/// The signed-in user's profile (a Home tab): avatar in a strength ring with
/// the level badge, streak / XP / matches / stars, what's still missing, the
/// pitch, achievements and chips. Pull to refresh.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileBloc _profileBloc;
  late final ProgressCubit _progressCubit;

  /// A profile has been shown; later errors appear as SnackBars instead of
  /// replacing the screen.
  bool _hasLoaded = false;
  bool _refreshingGitHub = false;

  @override
  void initState() {
    super.initState();
    _profileBloc = getIt<ProfileBloc>()..add(LoadProfileEvent());
    _progressCubit = _resolveProgressCubit();
  }

  /// HomeScreen provides the shared cubit. The standalone `/profile` route
  /// has no provider above it, so it falls back to the same DI instance.
  ProgressCubit _resolveProgressCubit() {
    try {
      return context.read<ProgressCubit>();
    } on ProviderNotFoundException {
      return getIt<ProgressCubit>();
    }
  }

  @override
  void dispose() {
    _profileBloc.close();
    super.dispose();
  }

  void _reload() => _profileBloc.add(LoadProfileEvent());

  /// Reloads the profile and progress; the spinner stays until both have
  /// settled (or a timeout passes).
  Future<void> _onPullToRefresh() async {
    final settled = _profileBloc.stream.firstWhere(
      (state) => state is ProfileLoaded || state is ProfileError,
      orElse: () => _profileBloc.state,
    );
    _reload();
    final progressDone = _progressCubit.refresh();
    await settled.timeout(
      const Duration(seconds: 20),
      onTimeout: () => _profileBloc.state,
    );
    await progressDone.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  void _refreshFromGitHub() {
    if (_refreshingGitHub) return;
    setState(() => _refreshingGitHub = true);
    _profileBloc.add(RefreshGitHubEvent());
  }

  Future<void> _openSettings() async {
    FeedbackService.onButtonPress();
    await context.push(RoutePaths.settings);
    // Settings links to Edit Profile: pick up changes made there.
    if (mounted) _reload();
  }

  Future<void> _openEditProfile() async {
    await context.push(RoutePaths.editProfile);
    if (mounted) _reload();
  }

  void _onProfileState(BuildContext context, ProfileState state) {
    if (state is ProfileLoaded) {
      if (_refreshingGitHub) {
        setState(() => _refreshingGitHub = false);
        // New languages or a bio from GitHub can change progress.
        _progressCubit.refresh();
        showGaToast(
          context,
          title: 'Refreshed from GitHub',
          message: 'Your repos, stars and languages are up to date.',
        );
      }
      _hasLoaded = true;
    } else if (state is ProfileError && _hasLoaded) {
      if (_refreshingGitHub) setState(() => _refreshingGitHub = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _profileBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(PhosphorIconsBold.gear),
              onPressed: _openSettings,
            ),
            const SizedBox(width: AppTokens.space4),
          ],
        ),
        body: BlocConsumer<ProfileBloc, ProfileState>(
          listener: _onProfileState,
          // Keep the current profile on screen while refreshing or when a
          // refresh fails.
          buildWhen: (previous, current) =>
              current is! ProfileUpdating &&
              !(_hasLoaded &&
                  (current is ProfileLoading || current is ProfileError)),
          builder: (context, state) {
            if (state is ProfileLoaded) return _buildProfile(context, state);
            if (state is ProfileError) return _buildError(state.message);
            return const ProfileSkeleton();
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      color: AppColors.green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          AppTokens.space40,
          AppTokens.gutter,
          AppTokens.space40,
        ),
        children: [
          EmptyState(
            illustration: Illustrations.octopus,
            title: "Couldn't load your profile",
            message: message,
            actionLabel: 'Try again',
            onAction: _reload,
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context, ProfileLoaded state) {
    final user = state.user;
    final strength = profileStrength(user);
    final missing = [
      for (final check in ProfileChecks.all)
        if (strength.missing.contains(check.key)) check,
    ];
    final pitch = user.pitch?.trim() ?? '';

    return BlocBuilder<ProgressCubit, ProgressState>(
      bloc: _progressCubit,
      builder: (context, progressState) {
        final loaded = progressState is ProgressLoaded ? progressState : null;
        final progress = loaded?.progress;
        final progressPending = progressState is ProgressInitial;

        final sections = <Widget>[
          ProfileHeader(
            key: const ValueKey('header'),
            user: user,
            strengthDone: strength.done,
            strengthTotal: strength.total,
            level: progress?.level,
          ),
          _StatsSection(
            key: const ValueKey('stats'),
            user: user,
            matchCount: state.matchCount,
            chatCount: state.chatCount,
            progress: progress,
            pending: progressPending,
          ),
          if (strength.done < strength.total)
            ProfileChecklistTile(
              key: const ValueKey('checklist'),
              done: strength.done,
              total: strength.total,
              missing: missing,
              onEdit: _openEditProfile,
              onRefreshGitHub: _refreshFromGitHub,
              refreshingGitHub: _refreshingGitHub,
              showXpReward: progress != null && !progress.profileComplete,
            ),
          if (pitch.isNotEmpty)
            _PitchTile(key: const ValueKey('pitch'), pitch: pitch),
          if (loaded != null)
            _AchievementsSection(
              key: const ValueKey('achievements'),
              progress: loaded.progress,
              newKeys: loaded.newAchievements,
            )
          else if (progressPending)
            const _AchievementsSkeleton(key: ValueKey('achievements-loading')),
          if (ProfileAboutTile.hasContent(user))
            ProfileAboutTile(key: const ValueKey('about'), user: user),
          _ProfileActions(
            key: const ValueKey('actions'),
            githubUrl: user.githubUrl,
            refreshingGitHub: _refreshingGitHub,
            onEditProfile: _openEditProfile,
            onRefreshGitHub: _refreshFromGitHub,
          ),
        ];

        return RefreshIndicator(
          onRefresh: _onPullToRefresh,
          color: AppColors.green,
          backgroundColor: context.palette.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTokens.gutter,
              AppTokens.space16,
              AppTokens.gutter,
              AppTokens.space40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++)
                  Padding(
                    key: sections[i].key,
                    padding: EdgeInsets.only(
                      top: i == 0 ? 0 : AppTokens.space24,
                    ),
                    child: _entrance(context, i, sections[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Fade + slide up, staggered; skipped under reduced motion.
  Widget _entrance(BuildContext context, int index, Widget child) {
    if (AppTokens.reduceMotion(context)) return child;
    return child
        .animate(delay: AppTokens.stagger * index)
        .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
        .moveY(
          begin: AppTokens.entranceOffset,
          end: 0,
          duration: AppTokens.medium,
          curve: AppTokens.curve,
        );
  }
}

/// Streak and XP (when progress is available), matches and stars.
class _StatsSection extends StatelessWidget {
  const _StatsSection({
    super.key,
    required this.user,
    required this.matchCount,
    required this.chatCount,
    required this.progress,
    required this.pending,
  });

  final UserEntity user;
  final int matchCount;
  final int chatCount;

  /// Null while progress is loading ([pending]) or unavailable.
  final ProgressEntity? progress;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final rows = <Widget>[
      if (progress != null)
        EqualHeightRow(
          spacing: AppTokens.space12,
          children: [
            _streakTile(context, progress),
            _xpTile(context, progress),
          ],
        )
      else if (pending)
        const StatSkeletonRow(),
      EqualHeightRow(
        spacing: AppTokens.space12,
        children: [_matchesTile(context), _starsTile(context)],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Statistics'),
        const SizedBox(height: AppTokens.space12),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTokens.space12),
          rows[i],
        ],
      ],
    );
  }

  Widget _footerText(BuildContext context, String text, {Color? color}) {
    return Text(
      text,
      style: AppTextStyles.bodySm(color ?? context.palette.inkMuted),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _streakTile(BuildContext context, ProgressEntity progress) {
    final days = progress.streakDays;
    final String hint;
    Color? hintColor;
    if (days == 0) {
      hint = 'Swipe today to start one';
    } else if (progress.isStreakAtRisk) {
      hint = 'Swipe today to keep it!';
      hintColor = context.palette.toneText(AppTone.flame);
    } else {
      hint = 'Best: ${plural(progress.bestStreak, 'day')}';
    }

    return StatTile(
      illustration: Illustrations.fire,
      value: days,
      label: 'Day streak',
      grayscale: !progress.activeToday,
      semanticLabel: '$days day streak. $hint',
      footer: _footerText(context, hint, color: hintColor),
    );
  }

  Widget _xpTile(BuildContext context, ProgressEntity progress) {
    final nextLevel = progress.level + 1;
    final toGo = '${progress.xpToNextLevel} XP to level $nextLevel';

    return StatTile(
      illustration: Illustrations.highVoltage,
      value: progress.xp,
      label: 'Total XP',
      semanticLabel:
          '${progress.xp} total XP. Level ${progress.level}, $toGo',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GaProgressBar(
            value: progress.levelProgress,
            tone: AppTone.gold,
            height: 10,
            animateOnMount: true,
          ),
          const SizedBox(height: 6),
          _footerText(context, toGo),
        ],
      ),
    );
  }

  Widget _matchesTile(BuildContext context) {
    final chats = plural(chatCount, 'conversation');
    return StatTile(
      illustration: Illustrations.handshake,
      value: matchCount,
      label: 'Matches',
      semanticLabel: '${plural(matchCount, 'match', 'matches')}, $chats',
      footer: _footerText(context, chats),
    );
  }

  Widget _starsTile(BuildContext context) {
    final repos = plural(user.publicRepos, 'public repo');
    return StatTile(
      illustration: Illustrations.glowingStar,
      value: user.totalStars,
      label: 'GitHub stars',
      semanticLabel: '${plural(user.totalStars, 'GitHub star')}, $repos',
      footer: _footerText(context, repos),
    );
  }
}

/// "What I'm building".
class _PitchTile extends StatelessWidget {
  const _PitchTile({super.key, required this.pitch});

  final String pitch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GaTile(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Illustration(Illustrations.rocket, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    "WHAT I'M BUILDING",
                    style: AppTextStyles.caption(palette.inkMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“$pitch”',
            style: AppTextStyles.body(palette.ink).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({
    super.key,
    required this.progress,
    required this.newKeys,
  });

  final ProgressEntity progress;

  /// Achievements unlocked since last seen: they get the kit's one-off
  /// highlight (the toast itself is HomeScreen's job).
  final List<String> newKeys;

  @override
  Widget build(BuildContext context) {
    final total = Achievements.all.length;
    final unlocked =
        Achievements.all.where((a) => progress.hasAchievement(a.key)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Achievements',
          subtitle: '$unlocked of $total unlocked',
        ),
        const SizedBox(height: AppTokens.space12),
        AchievementsGrid(
          isUnlocked: progress.hasAchievement,
          isNew: newKeys.contains,
        ),
      ],
    );
  }
}

class _AchievementsSkeleton extends StatelessWidget {
  const _AchievementsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Achievements'),
        const SizedBox(height: AppTokens.space12),
        ExcludeSemantics(
          child: EqualHeightRow(
            spacing: AppTokens.space12,
            children: [
              for (var i = 0; i < 3; i++)
                GaSkeleton(height: 120, radius: AppTokens.radiusLg),
            ],
          ),
        ),
      ],
    );
  }
}

/// Edit profile (secondary), View on GitHub and Refresh from GitHub.
class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    super.key,
    required this.githubUrl,
    required this.refreshingGitHub,
    required this.onEditProfile,
    required this.onRefreshGitHub,
  });

  final String? githubUrl;
  final bool refreshingGitHub;
  final VoidCallback onEditProfile;
  final VoidCallback onRefreshGitHub;

  @override
  Widget build(BuildContext context) {
    final githubUrl = this.githubUrl;
    final hasGitHub = githubUrl != null && githubUrl.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressableButton(
          label: 'Edit profile',
          variant: PressableVariant.secondary,
          icon: PhosphorIconsBold.pencilSimple,
          onPressed: onEditProfile,
        ),
        if (hasGitHub) ...[
          const SizedBox(height: AppTokens.space12),
          PressableButton(
            label: 'View on GitHub',
            variant: PressableVariant.ghost,
            icon: PhosphorIconsBold.githubLogo,
            trailingIcon: PhosphorIconsBold.arrowSquareOut,
            semanticLabel: 'View on GitHub, opens in your browser',
            onPressed: () => openExternalLink(context, githubUrl),
          ),
        ],
        const SizedBox(height: AppTokens.space8),
        // Re-sync repos, stars and languages from GitHub (backend-owned).
        PressableButton(
          label: refreshingGitHub ? 'Refreshing…' : 'Refresh from GitHub',
          variant: PressableVariant.ghost,
          icon: PhosphorIconsBold.arrowClockwise,
          loading: refreshingGitHub,
          onPressed: onRefreshGitHub,
        ),
      ],
    );
  }
}
