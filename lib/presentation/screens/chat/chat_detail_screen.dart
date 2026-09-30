import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/illustrations.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import '../../../core/utils/icebreakers.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/chat/chat_bloc.dart';
import '../../bloc/chat/chat_event.dart';
import '../../bloc/chat/chat_state.dart';
import '../../bloc/progress/progress_cubit.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_format.dart';
import 'widgets/icebreaker_panel.dart';
import 'widgets/message_bubble.dart';
import 'widgets/safety_sheets.dart';

/// One conversation: messages with day separators, icebreakers while it's
/// empty, the composer, and the safety tools (unmatch / block / report).
class ChatDetailScreen extends StatefulWidget {
  final String matchId;
  final String? otherUserName;
  final String? otherUserAvatar;

  const ChatDetailScreen({
    super.key,
    required this.matchId,
    this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatBloc _chatBloc;
  String _otherUserId = '';
  String _currentUserId = '';
  UserEntity? _me;
  UserEntity? _otherUser;
  bool _matchUnavailable = false;
  bool _actionInProgress = false;
  String? _lastSentText;

  /// Ids in the last loaded message list (null until the history loads), to
  /// tell live messages apart from history.
  Set<String>? _knownMessageIds;

  /// Live messages whose entrance animation hasn't finished yet.
  final Set<String> _entranceIds = <String>{};

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _me = authState.user;
      _currentUserId = authState.user.id;
    }
    // Loading marks the chat read; the bloc also marks incoming messages
    // read while the chat is open (it needs the current user id for that).
    _chatBloc = getIt<ChatBloc>()..add(_loadEvent());
    _fetchMatch();
  }

  LoadMessagesEvent _loadEvent() => LoadMessagesEvent(
        widget.matchId,
        currentUserId: _currentUserId.isEmpty ? null : _currentUserId,
      );

  Future<void> _fetchMatch() async {
    try {
      final match = await getIt<MatchRepository>().getMatchById(widget.matchId);
      if (!mounted) return;
      setState(() {
        _otherUserId = match.user.id;
        _otherUser = match.user;
        _matchUnavailable = false;
      });
    } catch (_) {
      // Unmatched, blocked or offline: sending stays disabled.
      if (mounted) setState(() => _matchUnavailable = true);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatBloc.close();
    super.dispose();
  }

  /// The other person's name once known (from the route or the match).
  String? get _knownName =>
      _otherUser?.name ?? widget.otherUserName ?? _otherUser?.username;

  String get _otherName => _knownName ?? 'your match';

  String get _composerHint {
    if (_matchUnavailable) return 'This conversation is no longer available';
    final name = _knownName?.trim() ?? '';
    return name.isEmpty ? 'Write a message…' : 'Message ${firstNameOf(name)}…';
  }

  /// Sending needs the other member's id, so it stays off until the match
  /// has loaded (and for good if it's gone).
  bool get _canSend => _otherUserId.isNotEmpty;

  void _sendMessage() {
    final text = normalizeOutgoingMessage(_messageController.text);
    if (text == null || !_canSend) return;

    FeedbackService.onMessageSent();
    _chatBloc.add(
      SendMessageEvent(
        matchId: widget.matchId,
        receiverId: _otherUserId,
        content: text,
      ),
    );
    _lastSentText = text;
    _messageController.clear();
  }

  void _useIcebreaker(String text) {
    _messageController.text = text;
    _messageController.selection =
        TextSelection.collapsed(offset: _messageController.text.length);
  }

  void _retry() {
    _chatBloc.add(_loadEvent());
    if (_otherUserId.isEmpty) {
      setState(() => _matchUnavailable = false);
      _fetchMatch();
    }
  }

  void _copyMessage(MessageEntity message) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Message copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (AppTokens.reduceMotion(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: AppTokens.slow,
          curve: AppTokens.curve,
        );
      }
    });
  }

  // ── Bloc events ───────────────────────────────────────────────────────────

  void _onChatState(BuildContext context, ChatState state) {
    if (state is ChatLoading) {
      _knownMessageIds = null;
      return;
    }

    if (state is ChatSendError) {
      final unsent = _lastSentText;
      if (unsent != null && _messageController.text.isEmpty) {
        _messageController.text = unsent;
        _messageController.selection =
            TextSelection.collapsed(offset: unsent.length);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (state is ChatLoaded) {
      final known = _knownMessageIds;
      _knownMessageIds = {for (final message in state.messages) message.id};
      if (known == null) return; // The history: nothing is "new".

      final animate = !AppTokens.reduceMotion(context);
      var sentByMe = false;
      for (final message in state.messages) {
        if (known.contains(message.id)) continue;
        if (animate) _entranceIds.add(message.id);
        if (_currentUserId.isNotEmpty && message.senderId == _currentUserId) {
          sentByMe = true;
        }
      }
      if (sentByMe) {
        // A message of mine landed: the send succeeded, so streak / XP /
        // achievements may have moved. HomeScreen shows any celebration;
        // progress is optional, so never let it break the chat.
        if (getIt.isRegistered<ProgressCubit>()) {
          unawaited(getIt<ProgressCubit>().refresh());
        }
        _scrollToLatest();
      }
    }
  }

  // ── Safety actions ────────────────────────────────────────────────────────

  Future<void> _openSafetyTools() async {
    final action = await showSafetySheet(
      context,
      name: _otherName,
      canUnmatch: !_matchUnavailable,
      canBlockOrReport: _otherUserId.isNotEmpty,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case SafetyAction.unmatch:
        await _unmatch();
      case SafetyAction.block:
        await _block();
      case SafetyAction.report:
        await _report();
    }
  }

  Future<void> _unmatch() async {
    final confirmed = await showSafetyConfirmDialog(
      context,
      illustration: Illustrations.wavingHand,
      title: 'Unmatch $_otherName?',
      message: 'This removes the match and your conversation for both of you.',
      confirmLabel: 'Unmatch',
    );
    if (!confirmed || !mounted) return;
    await _runAction(
      () => getIt<MatchRepository>().unmatch(widget.matchId),
      successMessage: 'You unmatched $_otherName.',
    );
  }

  Future<void> _block() async {
    if (_otherUserId.isEmpty) return;
    final confirmed = await showSafetyConfirmDialog(
      context,
      illustration: Illustrations.locked,
      title: 'Block $_otherName?',
      message: "You won't see each other again and this match will be removed. "
          "They won't be notified.",
      confirmLabel: 'Block',
    );
    if (!confirmed || !mounted) return;
    final userId = _otherUserId;
    await _runAction(
      () => getIt<MatchRepository>().blockUser(userId),
      successMessage: 'Blocked $_otherName.',
    );
  }

  Future<void> _report() async {
    if (_otherUserId.isEmpty) return;
    final result = await showReportDialog(context, name: _otherName);
    if (result == null || !mounted) return;

    final userId = _otherUserId;
    final repo = getIt<MatchRepository>();
    await _runAction(
      () async {
        await repo.reportUser(
          userId: userId,
          matchId: widget.matchId,
          reason: result.reason,
          details: result.details,
        );
        if (result.alsoBlock) {
          await repo.blockUser(userId);
        }
      },
      successMessage: result.alsoBlock
          ? "Thanks for reporting. $_otherName has been blocked."
          : "Thanks for reporting. We'll review it.",
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(RoutePaths.home);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionInProgress = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BlocProvider.value(
      value: _chatBloc,
      child: BlocListener<ChatBloc, ChatState>(
        listener: _onChatState,
        child: Scaffold(
          backgroundColor: palette.bg,
          appBar: _buildAppBar(context),
          body: Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: palette.surface,
                  child: BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      final (kind, child) = _buildBody(context, state);
                      return AnimatedSwitcher(
                        duration: AppTokens.motion(context, AppTokens.medium),
                        child: KeyedSubtree(
                          key: ValueKey<String>(kind),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ),
              ChatComposer(
                controller: _messageController,
                enabled: !_matchUnavailable,
                canSend: _canSend,
                hintText: _composerHint,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final palette = context.palette;
    final title = widget.otherUserName ??
        _otherUser?.name ??
        _otherUser?.username ??
        'Chat';
    final username = _otherUser?.username.trim() ?? '';
    final String subtitle;
    if (_matchUnavailable) {
      subtitle = 'Chat unavailable';
    } else if (username.isNotEmpty) {
      subtitle = '@$username';
    } else {
      subtitle = 'Matched';
    }

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      shape: Border(
        bottom: BorderSide(color: palette.border, width: AppTokens.borderWidth),
      ),
      title: Row(
        children: [
          ChatAvatar(
            name: title,
            imageUrl: widget.otherUserAvatar ?? _otherUser?.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: AppTokens.space12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3(palette.ink),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall(palette.inkMuted)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_actionInProgress)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTokens.space16),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.green,
                semanticsLabel: 'Working',
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Safety tools',
            icon: Icon(PhosphorIconsRegular.dotsThreeVertical),
            onPressed: _openSafetyTools,
          ),
        const SizedBox(width: AppTokens.space4),
      ],
    );
  }

  /// The body for [state], with a key for the cross-fade between kinds.
  (String, Widget) _buildBody(BuildContext context, ChatState state) {
    if (state is ChatError) {
      return (
        'error',
        EmptyState(
          illustration: Illustrations.thinkingFace,
          title: "Couldn't load this chat",
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: _retry,
        ),
      );
    }

    final List<MessageEntity>? messages;
    if (state is ChatLoaded) {
      messages = state.messages;
    } else if (state is ChatSendError) {
      messages = state.messages;
    } else {
      messages = null;
    }

    if (messages == null) return ('loading', const _MessagesSkeleton());
    if (messages.isNotEmpty) return ('list', _buildMessages(context, messages));
    if (_matchUnavailable) {
      return (
        'unavailable',
        EmptyState(
          illustration: Illustrations.thinkingFace,
          title: 'Chat unavailable',
          message: "This match may have ended, or you're offline.",
          actionLabel: 'Try again',
          onAction: _retry,
        ),
      );
    }

    final other = _otherUser;
    final icebreakers = other == null
        ? const <String>[]
        : generateIcebreakers(me: _me, other: other);
    return (
      'empty',
      IcebreakerPanel(
        name: _otherName,
        icebreakers: icebreakers,
        loading: other == null,
        onPick: _canSend ? _useIcebreaker : null,
      ),
    );
  }

  Widget _buildMessages(BuildContext context, List<MessageEntity> messages) {
    final items = _chatItems(messages);
    final indexByKey = <String, int>{
      for (var i = 0; i < items.length; i++) items[i].key: i,
    };
    final reduceMotion = AppTokens.reduceMotion(context);
    final senderName = _otherName;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space8,
        AppTokens.space16,
        AppTokens.space16,
      ),
      itemCount: items.length,
      // Keeps each row's state (e.g. a running entrance) when new messages
      // shift the indexes.
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indexByKey[key.value] : null,
      itemBuilder: (context, index) {
        final item = items[index];
        final message = item.message;
        if (message == null) {
          return DaySeparator(
            key: ValueKey<String>(item.key),
            label: dayLabel(context, item.day ?? DateTime.now()),
          );
        }

        Widget bubble = MessageBubble(
          message: message,
          isMine: message.senderId == _currentUserId,
          senderName: senderName,
          isGroupTop: item.isGroupTop,
          showTime: item.isGroupBottom,
          onLongPress: () => _copyMessage(message),
        );
        if (!reduceMotion && _entranceIds.contains(message.id)) {
          bubble = bubble
              .animate(onComplete: (_) => _entranceIds.remove(message.id))
              .fadeIn(duration: AppTokens.medium, curve: AppTokens.curve)
              .moveY(
                begin: AppTokens.entranceOffset,
                end: 0,
                duration: AppTokens.medium,
                curve: AppTokens.curve,
              );
        }
        return Padding(
          key: ValueKey<String>(item.key),
          padding: EdgeInsets.only(
            top: item.isGroupTop ? AppTokens.space12 : 3.0,
          ),
          child: bubble,
        );
      },
    );
  }
}

// ── Message list items ──────────────────────────────────────────────────────

/// A row of the (reversed) message list: a message or a day separator.
class _ChatItem {
  const _ChatItem.message(
    MessageEntity this.message, {
    required this.isGroupTop,
    required this.isGroupBottom,
  }) : day = null;

  const _ChatItem.day(DateTime this.day)
      : message = null,
        isGroupTop = false,
        isGroupBottom = false;

  final MessageEntity? message;
  final DateTime? day;
  final bool isGroupTop;
  final bool isGroupBottom;

  String get key {
    final m = message;
    if (m != null) return 'm:${m.id}';
    final d = day;
    return d == null ? 'd:?' : 'd:${d.year}-${d.month}-${d.day}';
  }
}

/// Messages from the same person within a few minutes on the same day read
/// as one group.
const Duration _groupGap = Duration(minutes: 5);

bool _sameGroup(MessageEntity older, MessageEntity newer) =>
    older.senderId == newer.senderId &&
    isSameLocalDay(older.sentAt, newer.sentAt) &&
    newer.sentAt.difference(older.sentAt).abs() < _groupGap;

/// Rows for [messages] (newest first, as the bloc keeps them): each message
/// knows its place in its group, and each day ends with a separator (shown
/// above the day's first message in the reversed list).
List<_ChatItem> _chatItems(List<MessageEntity> messages) {
  final items = <_ChatItem>[];
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final newer = i > 0 ? messages[i - 1] : null;
    final older = i + 1 < messages.length ? messages[i + 1] : null;
    items.add(_ChatItem.message(
      message,
      isGroupTop: older == null || !_sameGroup(older, message),
      isGroupBottom: newer == null || !_sameGroup(message, newer),
    ));
    if (older == null || !isSameLocalDay(older.sentAt, message.sentAt)) {
      items.add(_ChatItem.day(message.sentAt.toLocal()));
    }
  }
  return items;
}

/// Loading placeholder: a few bubble-shaped blocks on both sides.
class _MessagesSkeleton extends StatelessWidget {
  const _MessagesSkeleton();

  /// (mine, width, height) of each placeholder bubble, bottom first.
  static const List<(bool, double, double)> _bubbles = [
    (true, 180.0, 44.0),
    (true, 120.0, 44.0),
    (false, 220.0, 64.0),
    (false, 150.0, 44.0),
    (true, 200.0, 44.0),
    (false, 170.0, 44.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading messages',
      container: true,
      child: ExcludeSemantics(
        child: ListView(
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTokens.space16),
          children: [
            for (final (mine, width, height) in _bubbles)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space12),
                child: Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GaSkeleton(
                    width: width,
                    height: height,
                    radius: AppTokens.radiusLg,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
