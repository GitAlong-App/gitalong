import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/match_entity.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/matches/matches_bloc.dart';
import '../../bloc/matches/matches_event.dart';
import '../../bloc/matches/matches_state.dart';
import '../../widgets/ui/ui.dart';
import '../chat/widgets/conversation_skeletons.dart';
import '../chat/widgets/conversation_tile.dart';
import '../chat/widgets/matches_refresh.dart';
import 'widgets/new_match_avatar.dart';

/// Matches: a "New matches" row (no messages yet, avatars in a green ring),
/// then the conversations as tiles with unread pills.
///
/// Reads the [MatchesBloc] provided by HomeScreen (shared with the Chats
/// tab) or by the standalone route.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  /// The staggered entrance plays once, for the first list shown; later
  /// rebuilds (refreshes, scrolling) show items straight away.
  bool _entranceArmed = true;
  bool _entranceDisarmScheduled = false;

  @override
  Widget build(BuildContext context) {
    final matchesBloc = context.read<MatchesBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: BlocBuilder<MatchesBloc, MatchesState>(
        builder: (context, state) {
          final String kind;
          final Widget child;
          if (state is MatchesLoaded) {
            if (state.matches.isEmpty) {
              kind = 'empty';
              child = _buildEmpty(matchesBloc);
            } else {
              kind = 'list';
              child = _buildList(context, matchesBloc, state.matches);
            }
          } else if (state is MatchesError) {
            kind = 'error';
            child = _buildError(matchesBloc);
          } else {
            kind = 'loading';
            child = const _MatchesSkeleton();
          }
          return AnimatedSwitcher(
            duration: AppTokens.motion(context, AppTokens.medium),
            child: KeyedSubtree(key: ValueKey<String>(kind), child: child),
          );
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    MatchesBloc matchesBloc,
    List<MatchEntity> matches,
  ) {
    final myId = _myUserId(context);
    // Repository order (newest match first) for the new-matches row.
    final newMatches = matches.where((m) => m.lastMessage == null).toList();
    final conversations = matches.where((m) => m.lastMessage != null).toList()
      ..sort(compareByRecency);
    final unreadCount = conversations.where(isMatchUnread).length;
    _scheduleEntranceDisarm();

    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: context.palette.card,
      onRefresh: () => refreshMatchesSilently(matchesBloc),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (newMatches.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.gutter,
                AppTokens.space16,
                AppTokens.gutter,
                AppTokens.space4,
              ),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'New matches',
                  subtitle: newMatches.length == 1
                      ? '1 builder is waiting for your hello'
                      : '${newMatches.length} builders are waiting for your '
                          'hello',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: NewMatchAvatar.heightFor(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.gutter - 6,
                  ),
                  itemCount: newMatches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppTokens.space4),
                  itemBuilder: (context, index) {
                    final match = newMatches[index];
                    return _entrance(
                      context,
                      index,
                      NewMatchAvatar(
                        match: match,
                        onTap: () => _openChat(context, match),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (conversations.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.gutter,
                newMatches.isEmpty ? AppTokens.space16 : AppTokens.space20,
                AppTokens.gutter,
                AppTokens.space12,
              ),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Conversations',
                  trailing: unreadCount == 0
                      ? null
                      : GaBadge(
                          count: unreadCount,
                          semanticLabel: unreadCount == 1
                              ? '1 unread conversation'
                              : '$unreadCount unread conversations',
                        ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.gutter),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final match = conversations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTokens.space12),
                      child: _entrance(
                        context,
                        index + 2,
                        ConversationTile(
                          match: match,
                          myUserId: myId,
                          onTap: () => _openChat(context, match),
                        ),
                      ),
                    );
                  },
                  childCount: conversations.length,
                ),
              ),
            ),
          ],
          // Only new matches so far: nudge towards the first message.
          if (conversations.isEmpty && newMatches.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.gutter,
                  AppTokens.space24,
                  AppTokens.gutter,
                  AppTokens.space24,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: MascotBubble(
                    message: "Tap a new match to say hi. I've got "
                        'icebreakers ready for you!',
                    mascotSize: 72,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppTokens.space24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(MatchesBloc matchesBloc) {
    return RefreshableFill(
      onRefresh: () => refreshMatchesSilently(matchesBloc),
      child: EmptyState(
        illustration: Illustrations.octopus,
        title: 'No matches yet',
        message: "Keep swiping on Discover! When someone you like likes you "
            "back, I'll bring them right here.",
      ),
    );
  }

  Widget _buildError(MatchesBloc matchesBloc) {
    return RefreshableFill(
      onRefresh: () => refreshMatchesSilently(matchesBloc),
      child: EmptyState(
        illustration: Illustrations.thinkingFace,
        title: "Couldn't load your matches",
        message: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: () => _retry(matchesBloc),
      ),
    );
  }

  /// Staggered fade + slide-up, only for the first list shown and never
  /// under reduced motion.
  Widget _entrance(BuildContext context, int index, Widget child) {
    if (!_entranceArmed || index > 8 || AppTokens.reduceMotion(context)) {
      return child;
    }
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

  void _scheduleEntranceDisarm() {
    if (_entranceDisarmScheduled) return;
    _entranceDisarmScheduled = true;
    // Longer than the last staggered item (8 × 40 ms + 250 ms).
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      _entranceArmed = false;
    });
  }

  String? _myUserId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.id : null;
  }

  void _retry(MatchesBloc matchesBloc) {
    if (!matchesBloc.isClosed) matchesBloc.add(RefreshMatchesEvent());
  }

  Future<void> _openChat(BuildContext context, MatchEntity match) async {
    final matchesBloc = context.read<MatchesBloc>();
    await context.push(
      '/chats/${match.id}',
      extra: {
        'otherUserName': match.user.name ?? match.user.username,
        'otherUserAvatar': match.user.avatarUrl,
      },
    );
    // Back from the chat: pick up read state, unmatch/block, new messages.
    if (!matchesBloc.isClosed) matchesBloc.add(RefreshMatchesEvent());
  }
}

/// Loading placeholder shaped like the loaded screen.
class _MatchesSkeleton extends StatelessWidget {
  const _MatchesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading matches',
      container: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            AppTokens.space16,
            AppTokens.gutter,
            AppTokens.space24,
          ),
          children: [
            GaSkeleton(width: 150, height: 20),
            const SizedBox(height: AppTokens.space16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: AppTokens.space16),
                      child: Column(
                        children: [
                          GaSkeleton.circle(size: 72),
                          const SizedBox(height: AppTokens.space8),
                          GaSkeleton(width: 52, height: 12),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space32),
            GaSkeleton(width: 170, height: 20),
            const SizedBox(height: AppTokens.space16),
            for (var i = 0; i < 4; i++) ...[
              const ConversationTileSkeleton(),
              const SizedBox(height: AppTokens.space12),
            ],
          ],
        ),
      ),
    );
  }
}
