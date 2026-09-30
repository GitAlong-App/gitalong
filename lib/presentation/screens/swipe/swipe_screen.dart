import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import '../../../domain/entities/match_entity.dart';
import '../../../domain/entities/progress_entity.dart';
import '../../../domain/entities/swipe_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/discover/discover_bloc.dart';
import '../../bloc/discover/discover_event.dart';
import '../../bloc/discover/discover_state.dart';
import '../../bloc/progress/progress_cubit.dart';
import '../../bloc/progress/progress_state.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/daily_goal_memory.dart';
import 'widgets/discover_card.dart';
import 'widgets/discover_header.dart';
import 'widgets/discover_skeleton.dart';
import 'widgets/likes_teaser_banner.dart';
import 'widgets/match_avatars.dart';
import 'widgets/swipe_action_bar.dart';
import 'widgets/swipe_stamp.dart';

/// Discover: the swipe stack of recommended builders, with the streak, XP
/// and daily goal on top and the Nope / Super / Like buttons below.
class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen>
    with TickerProviderStateMixin {
  /// Releasing the card past this distance (px) commits the swipe.
  static const double _swipeThreshold = 100;

  /// Stamps start showing after this much drag (px).
  static const double _stampDeadZone = 20;

  /// The next card waits slightly smaller, peeking out below the top one.
  static const double _backScale = 0.95;
  static const double _backPeek = 10;

  /// Width of the content column on tablets.
  static const double _maxContentWidth = 560;

  static const Duration _snapDuration = Duration(milliseconds: 250);
  static const Duration _exitDuration = Duration(milliseconds: 300);

  late final DiscoverBloc _discoverBloc;

  /// The top card's drag offset. Only the card transforms, the stamps and
  /// the action buttons listen to it, so a drag frame never rebuilds the
  /// stack or the card contents.
  final ValueNotifier<Offset> _drag = ValueNotifier<Offset>(Offset.zero);

  late final AnimationController _snapController;
  late final AnimationController _exitController;

  /// What the card slots repaint on: the drag, and the exit fade under
  /// reduced motion.
  late final Listenable _slotMotion =
      Listenable.merge(<Listenable>[_drag, _exitController]);

  Tween<Offset>? _snapTween;
  Curve _snapCurve = Curves.elasticOut;
  Tween<Offset>? _exitTween;

  bool _isExiting = false;
  bool _thresholdCrossed = false;

  /// Under reduced motion the leaving card fades out in place (showing the
  /// stamp of [_exitAction]) instead of flying off.
  bool _fadeExit = false;
  SwipeAction? _exitAction;

  /// Home provides it; null when progress isn't available at all.
  ProgressCubit? _progressCubit;
  bool _progressResolved = false;

  /// On top of the navigator and the visible Home tab.
  bool _wasPresentable = false;

  bool _goalConfetti = false;
  int _goalConfettiRun = 0;
  bool _infoToastOpen = false;

  /// Matches already celebrated: each celebration shows exactly once.
  final Set<String> _celebratedMatchIds = <String>{};

  @override
  void initState() {
    super.initState();
    _discoverBloc = getIt<DiscoverBloc>()..add(LoadRecommendationsEvent());
    _snapController = AnimationController(vsync: this, duration: _snapDuration)
      ..addListener(_onSnapTick);
    _exitController = AnimationController(vsync: this, duration: _exitDuration)
      ..addListener(_onExitTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_progressResolved) {
      _progressResolved = true;
      _progressCubit = _resolveProgressCubit();
    }
    // Registers for route and tab changes, so a daily-goal celebration that
    // was held back plays when Discover is on screen again.
    final presentable = _isPresentable();
    if (presentable && !_wasPresentable) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrateGoal());
    }
    _wasPresentable = presentable;
  }

  @override
  void dispose() {
    _snapController.dispose();
    _exitController.dispose();
    _drag.dispose();
    _discoverBloc.close();
    super.dispose();
  }

  // ── Progress ───────────────────────────────────────────────────────────

  ProgressCubit? _resolveProgressCubit() {
    try {
      // Provided (and refreshed) by HomeScreen.
      return context.read<ProgressCubit>();
    } on ProviderNotFoundException {
      // Opened outside Home (the standalone /swipe route).
      if (!getIt.isRegistered<ProgressCubit>()) return null;
      final cubit = getIt<ProgressCubit>();
      if (cubit.state is ProgressInitial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(cubit.refresh());
        });
      }
      return cubit;
    }
  }

  void _refreshProgress() {
    final cubit = _progressCubit;
    if (cubit != null) unawaited(cubit.refresh());
  }

  bool _isPresentable() {
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    final visibleTab = Visibility.of(context);
    return onTop && visibleTab;
  }

  void _onProgressState(BuildContext context, ProgressState state) {
    if (state is ProgressLoaded && state.progress.goalReached) {
      _maybeCelebrateGoal();
    }
  }

  /// The daily-goal toast (with confetti), once per day. Held back while
  /// another screen or dialog (e.g. Home's level-up) is on top, or another
  /// tab is showing; [didChangeDependencies] retries when Discover is back.
  void _maybeCelebrateGoal() {
    if (!mounted) return;
    final state = _progressCubit?.state;
    if (state is! ProgressLoaded || !state.progress.goalReached) return;
    if (!_isPresentable()) return;
    final userId = _currentUser()?.id ?? '';
    if (DailyGoalMemory.shownToday(userId)) return;
    DailyGoalMemory.markShownToday(userId);

    final today = state.progress.todaySwipes;
    unawaited(showGaToast(
      context,
      title: 'Daily goal reached!',
      message: today == 1
          ? '1 builder reviewed today'
          : '$today builders reviewed today',
      illustration: Illustrations.trophy,
      tone: AppTone.gold,
    ));
    if (!AppTokens.reduceMotion(context)) {
      setState(() {
        _goalConfetti = true;
        _goalConfettiRun++;
      });
    }
  }

  void _onGoalConfettiDone() {
    if (!mounted || !_goalConfetti) return;
    setState(() => _goalConfetti = false);
  }

  void _showStreakInfo(ProgressEntity progress) {
    final days = progress.streakDays;
    final best = progress.bestStreak;
    final bestText = best == 1 ? '1 day' : '$best days';
    final String title;
    final String message;
    if (days <= 0) {
      title = 'Start a streak today';
      message = 'Review a builder or send a message every day to build one.';
    } else if (progress.activeToday) {
      title = '$days-day streak!';
      message = 'Best: $bestText. Come back tomorrow to keep it going.';
    } else {
      title = 'Keep your $days-day streak alive';
      message = 'Review a builder or send a message today.';
    }
    _showInfoToast(
      title: title,
      message: message,
      illustration: Illustrations.fire,
      tone: AppTone.flame,
    );
  }

  void _showXpInfo(ProgressEntity progress) {
    _showInfoToast(
      title: 'Level ${progress.level} · ${progress.xp} XP',
      message: '${progress.xpToNextLevel} XP to level ${progress.level + 1}. '
          'Reviewing builders, matching and chatting all earn XP.',
      illustration: Illustrations.highVoltage,
      tone: AppTone.gold,
    );
  }

  void _showInfoToast({
    required String title,
    required String message,
    required String illustration,
    required AppTone tone,
  }) {
    if (_infoToastOpen) return;
    _infoToastOpen = true;
    unawaited(showGaToast(
      context,
      title: title,
      message: message,
      illustration: illustration,
      tone: tone,
    ).whenComplete(() {
      _infoToastOpen = false;
    }));
  }

  // ── Discover events ────────────────────────────────────────────────────

  UserEntity? _currentUser() {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user : null;
  }

  void _reload() => _discoverBloc.add(LoadRecommendationsEvent());

  void _onDiscoverState(BuildContext context, DiscoverState state) {
    if (state is DiscoverMatch) {
      _refreshProgress();
      unawaited(_celebrateMatch(state.match));
    } else if (state is DiscoverSwipeSaved) {
      _refreshProgress();
    } else if (state is DiscoverSwipeFailed) {
      FeedbackService.errorBuzz();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(state.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// The full-screen match celebration; SAY HI opens the chat.
  Future<void> _celebrateMatch(MatchEntity match) async {
    if (!_celebratedMatchIds.add(match.id)) return;
    FeedbackService.onMatch();

    final other = match.user;
    final theirName = DiscoverCard.displayNameOf(other);
    final me = _currentUser();
    final sayHi = await showCelebration(
      context,
      title: "It's a match!",
      message: "You and $theirName liked each other. Say hi while it's fresh!",
      illustration: Illustrations.handshake,
      hero: MatchAvatars(
        myName: me == null ? 'You' : DiscoverCard.displayNameOf(me),
        myAvatarUrl: me?.avatarUrl,
        theirName: theirName,
        theirAvatarUrl: other.avatarUrl,
      ),
      xpGained: 10,
      ctaLabel: 'Say hi',
      secondaryLabel: 'Keep swiping',
      // FeedbackService.onMatch already played the match pattern.
      haptics: false,
    );
    if (!mounted) return;
    if (!sayHi) return;
    unawaited(context.push<void>(
      '/chats/${match.id}',
      extra: <String, String?>{
        'otherUserName': theirName,
        'otherUserAvatar': other.avatarUrl,
      },
    ));
  }

  // ── Drag physics ───────────────────────────────────────────────────────

  static double _unit(double value) =>
      value <= 0 ? 0.0 : (value >= 1 ? 1.0 : value);

  void _onSnapTick() {
    final tween = _snapTween;
    if (tween == null) return;
    _drag.value = tween.transform(_snapCurve.transform(_snapController.value));
  }

  void _onExitTick() {
    final tween = _exitTween;
    if (tween == null) return;
    _drag.value =
        tween.transform(Curves.easeInCubic.transform(_exitController.value));
  }

  /// Flies the card with [userId] off screen, then records the swipe.
  ///
  /// The id is captured now: the event is sent for this card even if the
  /// stack changes while it is leaving (a prefetch, or a failed swipe being
  /// restored behind it).
  void _handleSwipe(String userId, SwipeAction action) {
    if (_isExiting || !mounted) return;
    _isExiting = true;
    _snapController.stop();
    _snapTween = null;
    _thresholdCrossed = false;

    final width = MediaQuery.sizeOf(context).width;
    final from = _drag.value;
    Offset target;
    switch (action) {
      case SwipeAction.like:
        target = Offset(width * 1.5, from.dy);
        FeedbackService.onSwipeLike();
      case SwipeAction.dislike:
        target = Offset(-width * 1.5, from.dy);
        FeedbackService.onSwipeDislike();
      case SwipeAction.superLike:
        target = Offset(from.dx, -width * 1.5);
        FeedbackService.onSuperLike();
    }

    final reduced = AppTokens.reduceMotion(context);
    _fadeExit = reduced;
    _exitAction = action;
    // Under reduced motion the card stays put and fades out instead.
    _exitTween = Tween<Offset>(begin: from, end: reduced ? from : target);
    _exitController.duration = reduced ? AppTokens.fast : _exitDuration;
    _exitController.forward(from: 0).then((_) {
      if (!mounted) return;
      // The bloc drops this card before the next frame is built, so the
      // reset below never shows it back in the middle.
      _discoverBloc.add(SwipeUserEvent(swipedUserId: userId, action: action));
      _exitTween = null;
      _exitAction = null;
      _fadeExit = false;
      _isExiting = false;
      // Rewinding notifies the slots, so they repaint with the reset values.
      _exitController.value = 0;
      _drag.value = Offset.zero;
    });
  }

  void _onDragStart(DragStartDetails details) {
    if (_isExiting) return;
    _snapController.stop();
    _snapTween = null;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isExiting) return;
    final next = _drag.value + details.delta;
    _drag.value = next;

    // Haptic tick when crossing the swipe threshold.
    final crossed =
        next.dx.abs() > _swipeThreshold || next.dy.abs() > _swipeThreshold;
    if (crossed && !_thresholdCrossed) {
      FeedbackService.onThresholdCrossed();
      _thresholdCrossed = true;
    } else if (!crossed && _thresholdCrossed) {
      _thresholdCrossed = false;
    }
  }

  void _onDragEnd(DragEndDetails details, String userId) {
    if (_isExiting) return;
    final offset = _drag.value;
    if (offset.dx > _swipeThreshold) {
      _handleSwipe(userId, SwipeAction.like);
    } else if (offset.dx < -_swipeThreshold) {
      _handleSwipe(userId, SwipeAction.dislike);
    } else if (offset.dy < -_swipeThreshold) {
      _handleSwipe(userId, SwipeAction.superLike);
    } else {
      FeedbackService.onSnapBack();
      _thresholdCrossed = false;
      _snapTween = Tween<Offset>(begin: offset, end: Offset.zero);
      _snapCurve =
          AppTokens.reduceMotion(context) ? AppTokens.curve : Curves.elasticOut;
      _snapController.forward(from: 0);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  /// What the body shows for [state]. The stack only depends on the top two
  /// cards and the likes count, so the extra states around a swipe (saved,
  /// match, failed) only rebuild it when the visible cards change.
  static (String, String, int) _viewOf(DiscoverState state) {
    if (state is DiscoverError) return ('error', state.message, 0);
    if (state is DiscoverEmpty) return ('empty', '', 0);
    if (state is DiscoverLoaded) {
      final users = state.users;
      if (users.isEmpty) {
        return (state.isLoadingMore ? 'loading' : 'empty', '', 0);
      }
      final ids =
          users.length > 1 ? '${users[0].id}|${users[1].id}' : users[0].id;
      return ('stack', ids, state.likesReceivedCount);
    }
    return ('loading', '', 0);
  }

  static bool _needsRebuild(DiscoverState previous, DiscoverState current) =>
      _viewOf(previous) != _viewOf(current);

  @override
  Widget build(BuildContext context) {
    Widget screen = Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: BlocBuilder<DiscoverBloc, DiscoverState>(
                        bloc: _discoverBloc,
                        buildWhen: _needsRebuild,
                        builder: _buildBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_goalConfetti)
              Positioned.fill(
                child: ConfettiBurst(
                  key: ValueKey<int>(_goalConfettiRun),
                  particleCount: 60,
                  onComplete: _onGoalConfettiDone,
                ),
              ),
          ],
        ),
      ),
    );

    screen = BlocListener<DiscoverBloc, DiscoverState>(
      bloc: _discoverBloc,
      listener: _onDiscoverState,
      child: screen,
    );

    final progress = _progressCubit;
    if (progress != null) {
      screen = BlocListener<ProgressCubit, ProgressState>(
        bloc: progress,
        listener: _onProgressState,
        child: screen,
      );
    }

    return BlocProvider<DiscoverBloc>.value(value: _discoverBloc, child: screen);
  }

  Widget _buildHeader() {
    final progress = _progressCubit;
    if (progress == null) return const DiscoverHeader(progress: null);
    return BlocBuilder<ProgressCubit, ProgressState>(
      bloc: progress,
      builder: (context, state) => DiscoverHeader(
        progress: state,
        onStreakTap: _showStreakInfo,
        onXpTap: _showXpInfo,
      ),
    );
  }

  Widget _buildBody(BuildContext context, DiscoverState state) {
    if (state is DiscoverError) {
      return EmptyState(
        illustration: Illustrations.thinkingFace,
        title: "Hmm, that didn't load",
        message: "I couldn't reach the builder pool. "
            'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: _reload,
      );
    }
    if (state is DiscoverLoaded) {
      if (state.users.isNotEmpty) return _buildStack(context, state);
      return state.isLoadingMore ? _buildLoading() : _buildEmpty();
    }
    if (state is DiscoverEmpty) return _buildEmpty();
    return _buildLoading();
  }

  Widget _buildEmpty() {
    return EmptyState(
      illustration: Illustrations.octopus,
      title: "You're all caught up!",
      message: "I've introduced you to everyone I know for now. "
          "Check back soon, I'm always finding new builders.",
      actionLabel: 'Refresh',
      onAction: _reload,
    );
  }

  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.gutter,
              AppTokens.space12,
              AppTokens.gutter,
              AppTokens.space20,
            ),
            child: DiscoverCardSkeleton(),
          ),
        ),
        // Same key as in the stack, so the buttons just light up on load.
        SwipeActionBar(
          key: const ValueKey<String>('swipe-actions'),
          drag: _drag,
          threshold: _swipeThreshold,
        ),
      ],
    );
  }

  Widget _buildStack(BuildContext context, DiscoverLoaded state) {
    final users = state.users;
    final top = users.first;
    final likes = state.likesReceivedCount;
    final viewerIntents = _currentUser()?.lookingFor ?? const <String>[];
    final visible = users.length > 1 ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: AppTokens.motion(context, AppTokens.medium),
          curve: AppTokens.curve,
          alignment: Alignment.topCenter,
          child: likes > 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.gutter,
                    AppTokens.space8,
                    AppTokens.gutter,
                    0,
                  ),
                  child: LikesTeaserBanner(count: likes),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.gutter,
              AppTokens.space12,
              AppTokens.gutter,
              AppTokens.space20,
            ),
            child: Stack(
              // The leaving card flies over the rest of the screen.
              clipBehavior: Clip.none,
              children: [
                // Back to front, keyed by user, so the next card keeps its
                // element (and loaded avatar) when it becomes the top card.
                for (var i = visible - 1; i >= 0; i--)
                  Positioned.fill(
                    key: ValueKey<String>(users[i].id),
                    child: _buildSlot(
                      users[i],
                      isTop: i == 0,
                      viewerIntents: viewerIntents,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SwipeActionBar(
          key: const ValueKey<String>('swipe-actions'),
          drag: _drag,
          threshold: _swipeThreshold,
          onNope: () => _handleSwipe(top.id, SwipeAction.dislike),
          onSuperLike: () => _handleSwipe(top.id, SwipeAction.superLike),
          onLike: () => _handleSwipe(top.id, SwipeAction.like),
        ),
      ],
    );
  }

  /// One card in the stack. The top and the back card build the same widget
  /// structure (only values differ), so promoting the back card reuses its
  /// subtree. The card contents are built once and passed through; each drag
  /// frame only updates the transforms and the stamps.
  Widget _buildSlot(
    UserEntity user, {
    required bool isTop,
    required List<String> viewerIntents,
  }) {
    final card = RepaintBoundary(
      child: DiscoverCard(user: user, viewerIntents: viewerIntents),
    );

    return ExcludeSemantics(
      excluding: !isTop,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: isTop ? DiscoverCard.describe(user) : null,
        hint: isTop
            ? 'Swipe right to like, left to pass, or up to super like'
            : null,
        customSemanticsActions: isTop
            ? <CustomSemanticsAction, VoidCallback>{
                const CustomSemanticsAction(label: 'Like'): () =>
                    _handleSwipe(user.id, SwipeAction.like),
                const CustomSemanticsAction(label: 'Nope'): () =>
                    _handleSwipe(user.id, SwipeAction.dislike),
                const CustomSemanticsAction(label: 'Super like'): () =>
                    _handleSwipe(user.id, SwipeAction.superLike),
              }
            : null,
        child: GestureDetector(
          onPanStart: isTop ? _onDragStart : null,
          onPanUpdate: isTop ? _onDragUpdate : null,
          onPanEnd: isTop ? (details) => _onDragEnd(details, user.id) : null,
          child: AnimatedBuilder(
            animation: _slotMotion,
            builder: (context, child) =>
                isTop ? _topFrame(child!) : _backFrame(child!),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _topFrame(Widget card) {
    final offset = _drag.value;
    const stampRange = _swipeThreshold - _stampDeadZone;
    final horizontal =
        _unit((offset.dx.abs() - _stampDeadZone) / stampRange);
    var like = offset.dx > 0 ? horizontal : 0.0;
    var nope = offset.dx < 0 ? horizontal : 0.0;
    var superLike = _unit((-offset.dy - _stampDeadZone) / stampRange) *
        (1 - _unit(offset.dx.abs() / _swipeThreshold));
    var opacity = 1.0;
    if (_fadeExit) {
      opacity = 1 - _exitController.value;
      like = _exitAction == SwipeAction.like ? 1.0 : 0.0;
      nope = _exitAction == SwipeAction.dislike ? 1.0 : 0.0;
      superLike = _exitAction == SwipeAction.superLike ? 1.0 : 0.0;
    }
    return _cardFrame(
      card,
      opacity: opacity,
      offset: offset,
      angle: offset.dx / 1000,
      scale: 1,
      like: like,
      nope: nope,
      superLike: superLike,
    );
  }

  Widget _backFrame(Widget card) {
    final offset = _drag.value;
    // Rises into place as the top card is dragged away.
    final lift = _unit(
      math.max(offset.dx.abs(), offset.dy.abs()) / _swipeThreshold,
    );
    return _cardFrame(
      card,
      opacity: 1,
      offset: Offset(0, _backPeek * (1 - lift)),
      angle: 0,
      scale: _backScale + (1 - _backScale) * lift,
      like: 0,
      nope: 0,
      superLike: 0,
    );
  }

  Widget _cardFrame(
    Widget card, {
    required double opacity,
    required Offset offset,
    required double angle,
    required double scale,
    required double like,
    required double nope,
    required double superLike,
  }) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Stack(
              fit: StackFit.expand,
              children: [
                card,
                SwipeStampsOverlay(
                  like: like,
                  nope: nope,
                  superLike: superLike,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
