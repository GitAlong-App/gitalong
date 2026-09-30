import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../core/utils/logger.dart';

/// Chat repository implementation.
///
/// Messages are only ever inserted with
/// `{match_id, sender_id, receiver_id, content, type}`; database triggers set
/// `sent_at`, `is_read` and the match preview.
@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _supabase;

  ChatRepositoryImpl(this._supabase);

  @override
  Future<List<MessageEntity>> getMessages({
    required String matchId,
    int limit = 50,
    String? cursor,
  }) async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .eq('match_id', matchId)
          .order('sent_at', ascending: false)
          .limit(limit);

      return data
          .map((row) => _parseMessage(row, matchId))
          .whereType<MessageEntity>()
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e('Error getting messages', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<MessageEntity> sendMessage({
    required String matchId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('No user signed in');

      final row = await _supabase
          .from('messages')
          .insert({
            'match_id': matchId,
            'sender_id': currentUser.id,
            'receiver_id': receiverId,
            'content': content,
            'type': type.name,
          })
          .select()
          .single();

      return _parseMessage(row, matchId) ??
          MessageEntity(
            id: row['id']?.toString() ?? '',
            matchId: matchId,
            senderId: currentUser.id,
            receiverId: receiverId,
            content: content,
            type: type,
            sentAt: DateTime.now(),
          );
    } catch (e, stackTrace) {
      AppLogger.e('Error sending message', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('id', messageId);
    } catch (e, stackTrace) {
      AppLogger.e('Error marking message as read', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> markAllMessagesAsRead(String matchId) async {
    try {
      // Marks every message the caller received in this match as read and
      // clears the match's unread flag.
      await _supabase.rpc('mark_match_read', params: {'p_match_id': matchId});
    } catch (e, stackTrace) {
      AppLogger.e('Error marking all messages as read', e, stackTrace);
      rethrow;
    }
  }

  @override
  Stream<MessageEntity> listenToMessages(String matchId) {
    final processedIds = <String>{};
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('sent_at', ascending: false)
        .limit(100)
        .asyncExpand((data) async* {
          for (final row in data) {
            final message = _parseMessage(row, matchId);
            if (message == null) continue;
            if (processedIds.add(message.id)) {
              yield message;
            }
          }
        });
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
    } catch (e, stackTrace) {
      AppLogger.e('Error deleting message', e, stackTrace);
      rethrow;
    }
  }

  /// Parses a `messages` row; returns null for rows missing required data.
  static MessageEntity? _parseMessage(Map<String, dynamic> row, String matchId) {
    final id = row['id']?.toString();
    final senderId = row['sender_id']?.toString();
    final receiverId = row['receiver_id']?.toString();
    final content = row['content'];
    if (id == null || id.isEmpty || senderId == null || receiverId == null) {
      return null;
    }
    if (content is! String) return null;

    final rawType = row['type']?.toString();
    final rawSentAt = row['sent_at'];
    final rawIsRead = row['is_read'];

    return MessageEntity(
      id: id,
      matchId: row['match_id']?.toString() ?? matchId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      type: MessageType.values.firstWhere(
        (e) => e.name == rawType,
        orElse: () => MessageType.text,
      ),
      sentAt: (rawSentAt is String ? DateTime.tryParse(rawSentAt) : null) ??
          DateTime.now(),
      isRead: rawIsRead is bool ? rawIsRead : false,
    );
  }
}
