import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/data/models/match_model.dart';
import 'package:gitalong/domain/entities/match_entity.dart';
import 'package:gitalong/domain/entities/user_entity.dart';

void main() {
  const me = 'aaaaaaaa-0000-0000-0000-000000000001';
  const other = 'bbbbbbbb-0000-0000-0000-000000000002';

  group('MatchEntity.isUnreadFor', () {
    test('unread when the other person sent the last message', () {
      expect(
        MatchEntity.isUnreadFor(
          lastMessage: 'hey!',
          isRead: false,
          lastMessageSenderId: other,
          myId: me,
        ),
        isTrue,
      );
    });

    test('never unread for my own last message', () {
      expect(
        MatchEntity.isUnreadFor(
          lastMessage: 'hey!',
          isRead: false,
          lastMessageSenderId: me,
          myId: me,
        ),
        isFalse,
      );
    });

    test('read when the flag is set', () {
      expect(
        MatchEntity.isUnreadFor(
          lastMessage: 'hey!',
          isRead: true,
          lastMessageSenderId: other,
          myId: me,
        ),
        isFalse,
      );
    });

    test('a match without messages is not unread', () {
      expect(
        MatchEntity.isUnreadFor(
          lastMessage: null,
          isRead: false,
          lastMessageSenderId: null,
          myId: me,
        ),
        isFalse,
      );
    });
  });

  group('MatchModel', () {
    final otherUser = UserEntity(
      id: other,
      username: 'octocat',
      email: '',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    test('fromRow applies the unread rule for the current user', () {
      final unread = MatchModel.fromRow(
        <String, dynamic>{
          'id': 'm-1',
          'users': [me, other],
          'matched_at': '2026-09-01T10:00:00Z',
          'last_message': 'hi',
          'last_message_at': '2026-09-01T11:00:00Z',
          'last_message_sender_id': other,
          'is_read': false,
        },
        otherUser: otherUser,
        myId: me,
      );
      expect(unread.isRead, isFalse);
      expect(unread.lastMessageSenderId, other);
      expect(unread.matchedAt, DateTime.utc(2026, 9, 1, 10));

      final mine = MatchModel.fromRow(
        <String, dynamic>{
          'id': 'm-2',
          'users': [me, other],
          'matched_at': '2026-09-01T10:00:00Z',
          'last_message': 'hi',
          'last_message_sender_id': me,
          'is_read': false,
        },
        otherUser: otherUser,
        myId: me,
      );
      expect(mine.isRead, isTrue);
    });

    test('otherUserId picks the member that is not me', () {
      expect(
        MatchModel.otherUserId(<String, dynamic>{'users': [me, other]}, me),
        other,
      );
      expect(
        MatchModel.otherUserId(<String, dynamic>{'users': [other, me]}, me),
        other,
      );
      expect(MatchModel.otherUserId(<String, dynamic>{}, me), isNull);
    });

    test('pairKey sorts ids ascending regardless of order', () {
      const expected = '$me:$other';
      expect(MatchModel.pairKey(me, other), expected);
      expect(MatchModel.pairKey(other, me), expected);
    });
  });
}
