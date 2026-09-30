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
import 'widgets/conversation_skeletons.dart';
import 'widgets/conversation_tile.dart';
import 'widgets/matches_refresh.dart';

/// Chats: every match as a conversation tile, most recent activity first,
/// with unread rows highlighted.
///
/// Reads the [MatchesBloc] provided by HomeScreen (shared with the Matches
/// tab) or by the standalone route.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  /// The staggered entrance plays once, for the first list shown.
  bool _entranceArmed = true;
  bool _entranceDisarmScheduled = false;

  @override
  Widget build(BuildContext context) {
    final matchesBloc = context.read<MatchesBloc>();
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: BlocBuilder<MatchesBloc, MatchesState>(
        builder: (context, state) {
          final String kind;
          final Widget child;
          if (state is MatchesLoaded) {
            if (state.matches.isEmpty) {
              kind = 'empty';
              child = RefreshableFill(
                onRefresh: () => refreshMatchesSilently(matchesBloc),
                child: EmptyState(
                  illustration: Illustrations.speechBalloon,
                  title: 'No chats yet',
                  message: 'Match with builders on Discover and your '
                      'conversations will show up here.',
                ),
              );
            } else {
              kind = 'list';
              child = _buildList(context, matchesBloc, state.matches);
            }
          } else if (state is MatchesError) {
            kind = 'error';
            child = RefreshableFill(
              onRefresh: () => refreshMatchesSilently(matchesBloc),
              child: EmptyState(
                illustration: Illustrations.thinkingFace,
                title: "Couldn't load your chats",
                message: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: () {
                  if (!matchesBloc.isClosed) {
                    matchesBloc.add(RefreshMatchesEvent());
                  }
                },
              ),
            );
          } else {
            kind = 'loading';
            child = const ConversationListSkeleton(
              semanticLabel: 'Loading chats',
            );
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
    // All matches (with or without messages), most recent activity first.
    final conversations = List<MatchEntity>.from(matches)
      ..sort(compareByRecency);
    final authState = context.read<AuthBloc>().state;
    final myId = authState is AuthAuthenticated ? authState.user.id : null;
    final reduceMotion = AppTokens.reduceMotion(context);
    _scheduleEntranceDisarm();

    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: context.palette.card,
      onRefresh: () => refreshMatchesSilently(matchesBloc),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          AppTokens.space16,
          AppTokens.gutter,
          AppTokens.space24,
        ),
        itemCount: conversations.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppTokens.space12),
        itemBuilder: (context, index) {
          final match = conversations[index];
          Widget tile = ConversationTile(
            match: match,
            myUserId: myId,
            onTap: () => _openChat(context, match),
          );
          if (_entranceArmed && !reduceMotion && index <= 8) {
            tile = tile
                .animate(delay: AppTokens.stagger * index)
                .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
                .moveY(
                  begin: AppTokens.entranceOffset,
                  end: 0,
                  duration: AppTokens.medium,
                  curve: AppTokens.curve,
                );
          }
          return tile;
        },
      ),
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
