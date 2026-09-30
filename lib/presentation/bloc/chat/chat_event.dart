import 'package:equatable/equatable.dart';
import '../../../domain/entities/message_entity.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessagesEvent extends ChatEvent {
  final String matchId;

  /// The signed-in user's id, used to mark incoming messages from the other
  /// person as read while the chat is open.
  final String? currentUserId;

  const LoadMessagesEvent(this.matchId, {this.currentUserId});

  @override
  List<Object?> get props => [matchId, currentUserId];
}

class SendMessageEvent extends ChatEvent {
  final String matchId;
  final String receiverId;
  final String content;

  const SendMessageEvent({
    required this.matchId,
    required this.receiverId,
    required this.content,
  });

  @override
  List<Object?> get props => [matchId, receiverId, content];
}

class MessageReceivedEvent extends ChatEvent {
  final MessageEntity message;

  const MessageReceivedEvent(this.message);

  @override
  List<Object?> get props => [message];
}
