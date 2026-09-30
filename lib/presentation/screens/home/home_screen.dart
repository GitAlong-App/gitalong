import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import '../../bloc/matches/matches_bloc.dart';
import '../../bloc/matches/matches_event.dart';
import '../../bloc/matches/matches_state.dart';
import '../../bloc/progress/progress_cubit.dart';
import '../../bloc/progress/progress_state.dart';
import '../../widgets/notifications_listener.dart';
import '../../widgets/ui/ui.dart';
import '../chat/chat_list_screen.dart';
import '../matches/matches_screen.dart';
import '../profile/profile_screen.dart';
import '../swipe/swipe_screen.dart';

/// Home screen with bottom navigation.
///
/// Owns the app-wide progress experience: it provides [ProgressCubit] to the
/// tabs, refreshes it (on start, tab switch, app resume and when a pushed
/// screen closes) and shows achievement toasts and level-up celebrations.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _matchesTab = 1;
  static const int _chatsTab = 2;

  int _currentIndex = 0;

  /// Shared by the Matches and Chats tabs so both always show the same data.
  late final MatchesBloc _matchesBloc;

  /// App-wide singleton; reset here so a new session never shows the
  /// previous user's numbers.
  late final ProgressCubit _progressCubit;

  /// Another route (chat, settings, a dialog) is on top of Home.
  bool _coveredByRoute = false;

  /// Home is the top-most route (cached from [ModalRoute.isCurrentOf]).
  bool _isCurrentRoute = true;

  /// A level-up that arrived while Home was covered; celebrated on return.
  int? _pendingLevelUp;

  final List<Widget> _screens = const [
    SwipeScreen(),
    MatchesScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _matchesBloc = getIt<MatchesBloc>()..add(LoadMatchesEvent());
    _progressCubit = getIt<ProgressCubit>()..reset();
    unawaited(_progressCubit.refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _isCurrentRoute = isCurrent;
    if (!isCurrent) {
      _coveredByRoute = true;
      return;
    }
    if (_coveredByRoute) {
      // Back from a pushed screen: chats and progress may have changed.
      _coveredByRoute = false;
      _refreshMatches();
      _refreshProgress();
      final level = _pendingLevelUp;
      if (level != null) {
        _pendingLevelUp = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_celebrateLevel(level));
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new day may have started: streak and daily goal change.
    if (state == AppLifecycleState.resumed) _refreshProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchesBloc.close();
    super.dispose();
  }

  void _refreshMatches() {
    if (!_matchesBloc.isClosed) _matchesBloc.add(RefreshMatchesEvent());
  }

  void _refreshProgress() => unawaited(_progressCubit.refresh());

  void _onTabSelected(int index) {
    FeedbackService.onTabChange();
    if (index == _matchesTab || index == _chatsTab) {
      _refreshMatches();
    }
    _refreshProgress();
    setState(() {
      _currentIndex = index;
    });
  }

  /// Toasts for new achievements right away (they float above any screen);
  /// the level-up celebration waits until Home is on top.
  void _onProgressNews(ProgressLoaded state) {
    for (final key in state.newAchievements) {
      unawaited(showAchievementToast(context, key));
    }
    if (!state.leveledUp) return;
    final level = state.progress.level;
    if (_isCurrentRoute) {
      unawaited(_celebrateLevel(level));
    } else {
      _pendingLevelUp = level;
    }
  }

  Future<void> _celebrateLevel(int level) async {
    if (!mounted) return;
    await showCelebration(
      context,
      title: 'Level $level!',
      message: "You're on a roll. Keep reviewing builders and starting chats.",
      illustration: Illustrations.crown,
      ctaLabel: 'Keep going',
    );
  }

  static int _unreadCount(MatchesState state) {
    if (state is! MatchesLoaded) return 0;
    return state.matches.where((match) => !match.isRead).length;
  }

  NavigationDestination _destination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool reduceMotion,
    int badge = 0,
  }) {
    Widget withBadge(Widget child) => badge > 0
        ? GaBadge(
            count: badge,
            semanticLabel: badge == 1 ? '1 unread' : '$badge unread',
            child: child,
          )
        : child;

    Widget active = Icon(selectedIcon);
    if (!reduceMotion) {
      // Plays each time the tab becomes selected (the icon is swapped in).
      active = active.animate().scaleXY(
            begin: 0.7,
            end: 1,
            duration: AppTokens.slow,
            curve: AppTokens.bounceCurve,
          );
    }

    return NavigationDestination(
      icon: withBadge(Icon(icon)),
      selectedIcon: withBadge(active),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final palette = context.palette;
    final reduceMotion = AppTokens.reduceMotion(context);

    final navigation = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: AppTokens.borderWidth, color: palette.border),
        BlocBuilder<MatchesBloc, MatchesState>(
          bloc: _matchesBloc,
          buildWhen: (previous, current) =>
              _unreadCount(previous) != _unreadCount(current),
          builder: (context, matchesState) {
            final unread = _unreadCount(matchesState);
            return NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              destinations: [
                _destination(
                  icon: PhosphorIconsRegular.cards,
                  selectedIcon: PhosphorIconsFill.cards,
                  label: 'Discover',
                  reduceMotion: reduceMotion,
                ),
                _destination(
                  icon: PhosphorIconsRegular.heart,
                  selectedIcon: PhosphorIconsFill.heart,
                  label: 'Matches',
                  reduceMotion: reduceMotion,
                ),
                _destination(
                  icon: PhosphorIconsRegular.chatCircle,
                  selectedIcon: PhosphorIconsFill.chatCircle,
                  label: 'Chats',
                  reduceMotion: reduceMotion,
                  badge: unread,
                ),
                _destination(
                  icon: PhosphorIconsRegular.user,
                  selectedIcon: PhosphorIconsFill.user,
                  label: 'Profile',
                  reduceMotion: reduceMotion,
                ),
              ],
            );
          },
        ),
      ],
    );

    final scaffold = Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: navigation,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<MatchesBloc>.value(value: _matchesBloc),
        BlocProvider<ProgressCubit>.value(value: _progressCubit),
      ],
      child: BlocListener<ProgressCubit, ProgressState>(
        bloc: _progressCubit,
        listenWhen: (previous, current) =>
            current is ProgressLoaded && current.hasNews,
        listener: (context, state) {
          if (state is ProgressLoaded) _onProgressNews(state);
        },
        child: userId != null
            ? NotificationsListener(
                userId: userId,
                onNewMatch: (_) {
                  _refreshMatches();
                  _refreshProgress();
                },
                child: scaffold,
              )
            : scaffold,
      ),
    );
  }
}
