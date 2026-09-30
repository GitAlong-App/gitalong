import 'package:equatable/equatable.dart';
import '../../../domain/entities/message_entity.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<MessageEntity> messages;

  const ChatLoaded(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

class ChatSendError extends ChatState {
  final List<MessageEntity> messages;
  final String error;

  const ChatSendError({required this.messages, required this.error});

  @override
  List<Object?> get props => [messages, error];
}
