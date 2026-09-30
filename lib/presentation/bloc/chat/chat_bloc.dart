import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/entities/message_entity.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../../core/utils/logger.dart';
import 'chat_event.dart';
import 'chat_state.dart';

@injectable
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;

  StreamSubscription<MessageEntity>? _messageSubscription;
  List<MessageEntity> _currentMessages = [];

  String? _matchId;
  String? _currentUserId;
  bool _markingRead = false;
  bool _markReadQueued = false;

  ChatBloc(this._chatRepository) : super(ChatInitial()) {
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
  }

  Future<void> _onLoadMessages(
      LoadMessagesEvent event, Emitter<ChatState> emit) async {
    _matchId = event.matchId;
    _currentUserId = event.currentUserId;
    emit(ChatLoading());
    try {
      final messages =
          await _chatRepository.getMessages(matchId: event.matchId);
      // Closed while loading (user backed out): don't mark read, and don't
      // open a realtime channel that close() can no longer cancel.
      if (isClosed) return;
      _currentMessages = List.from(messages);
      _sortNewestFirst();
      emit(ChatLoaded(List.from(_currentMessages)));

      // Opening the chat marks everything received so far as read.
      _scheduleMarkRead();

      await _messageSubscription?.cancel();
      if (isClosed) return;
      _messageSubscription =
          _chatRepository.listenToMessages(event.matchId).listen(
        (message) {
          if (!isClosed) add(MessageReceivedEvent(message));
        },
        onError: (Object err) {
          AppLogger.w('Message stream error: $err');
        },
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendMessage(
      SendMessageEvent event, Emitter<ChatState> emit) async {
    try {
      final newMsg = await _chatRepository.sendMessage(
        matchId: event.matchId,
        receiverId: event.receiverId,
        content: event.content,
      );

      if (!_currentMessages.any((m) => m.id == newMsg.id)) {
        _currentMessages.add(newMsg);
        _sortNewestFirst();
        emit(ChatLoaded(List.from(_currentMessages)));
      }
    } catch (e) {
      emit(ChatSendError(
        messages: List.from(_currentMessages),
        error: 'Failed to send message. Please try again.',
      ));
      emit(ChatLoaded(List.from(_currentMessages)));
    }
  }

  void _onMessageReceived(
      MessageReceivedEvent event, Emitter<ChatState> emit) {
    final message = event.message;
    if (_currentMessages.any((m) => m.id == message.id)) return;

    _currentMessages.add(message);
    _sortNewestFirst();
    emit(ChatLoaded(List.from(_currentMessages)));

    // A message from the other person arrived while the chat is open.
    final myId = _currentUserId;
    if (myId != null && message.senderId != myId && !message.isRead) {
      _scheduleMarkRead();
    }
  }

  void _sortNewestFirst() {
    _currentMessages.sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  /// Calls `mark_match_read`, coalescing bursts of incoming messages into at
  /// most one in-flight request plus one follow-up.
  void _scheduleMarkRead() {
    final matchId = _matchId;
    if (matchId == null) return;
    if (_markingRead) {
      _markReadQueued = true;
      return;
    }
    _markingRead = true;
    unawaited(_markRead(matchId));
  }

  Future<void> _markRead(String matchId) async {
    try {
      await _chatRepository.markAllMessagesAsRead(matchId);
    } catch (e) {
      if (kDebugMode) AppLogger.w('Failed to mark messages as read: $e');
    } finally {
      _markingRead = false;
    }
    if (_markReadQueued && !isClosed) {
      _markReadQueued = false;
      _scheduleMarkRead();
    }
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
