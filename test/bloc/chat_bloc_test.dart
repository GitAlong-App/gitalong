import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/message_entity.dart';
import 'package:gitalong/presentation/bloc/chat/chat_bloc.dart';
import 'package:gitalong/presentation/bloc/chat/chat_event.dart';
import 'package:gitalong/presentation/bloc/chat/chat_state.dart';

import 'fakes.dart';

const _sendError = 'Failed to send message. Please try again.';

void main() {
  late FakeChatRepository repo;
  late ChatBloc bloc;
  late List<ChatState> states;
  late StreamSubscription<ChatState> sub;

  // Out of order on purpose: the bloc keeps newest first.
  final oldest = buildMessage('1', minute: 1);
  final middle = buildMessage('2', minute: 2, senderId: 'me', receiverId: 'other');
  final newest = buildMessage('3', minute: 3);

  setUp(() {
    repo = FakeChatRepository()
      ..onGetMessages = (_) async => [middle, oldest, newest];
    bloc = ChatBloc(repo);
    states = [];
    sub = bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await sub.cancel();
    await bloc.close();
  });

  Future<void> open({String matchId = 'm1', String? me = 'me'}) async {
    bloc.add(LoadMessagesEvent(matchId, currentUserId: me));
    await settle();
  }

  List<MessageEntity> shown() {
    final s = bloc.state;
    if (s is ChatLoaded) return s.messages;
    if (s is ChatSendError) return s.messages;
    return const [];
  }

  group('LoadMessagesEvent', () {
    test('loads messages newest first, marks the chat read and goes live',
        () async {
      await open();

      expect(states, [
        ChatLoading(),
        ChatLoaded([newest, middle, oldest]),
      ]);
      expect(repo.getMessagesCalls, ['m1']);
      expect(repo.markAllReadCalls, ['m1']);
      expect(repo.listenCalls, ['m1']);
    });

    test('an empty conversation is loaded (not an error)', () async {
      repo.onGetMessages = (_) async => const [];
      await open();

      expect(states, [ChatLoading(), const ChatLoaded([])]);
      expect(repo.listenCalls, ['m1']);
    });

    test('a load failure emits ChatError and does not subscribe', () async {
      repo.onGetMessages = (_) async => throw Exception('rls denied');
      await open();

      expect(states, [ChatLoading(), const ChatError('Exception: rls denied')]);
      expect(repo.listenCalls, isEmpty);
      expect(repo.markAllReadCalls, isEmpty);
    });

    test('switching to another match cancels the previous realtime feed',
        () async {
      await open(matchId: 'm1');
      repo.onGetMessages = (_) async => const [];
      await open(matchId: 'm2');

      expect(repo.listenCalls, ['m1', 'm2']);
      expect(repo.cancelledStreams, ['m1']);
      expect(repo.markAllReadCalls, ['m1', 'm2']);
    });

    test('closing the bloc while loading opens no feed and marks nothing read',
        () async {
      final load = Completer<List<MessageEntity>>();
      repo.onGetMessages = (_) => load.future;

      bloc.add(const LoadMessagesEvent('m1', currentUserId: 'me'));
      await settle();
      await bloc.close();
      load.complete([oldest]);
      await settle();

      expect(repo.listenCalls, isEmpty);
      expect(repo.markAllReadCalls, isEmpty);
    });

    test('close() cancels the realtime subscription', () async {
      await open();
      expect(repo.cancelledStreams, isEmpty);

      await bloc.close();

      expect(repo.cancelledStreams, ['m1']);
    });
  });

  group('realtime messages', () {
    test('an incoming message is inserted in time order', () async {
      await open();
      final latest = buildMessage('4', minute: 10);

      repo.controllers['m1']!.add(latest);
      await settle();

      expect(states.last, ChatLoaded([latest, newest, middle, oldest]));
    });

    test('a late-arriving older message is sorted, not appended', () async {
      await open();
      final backfill = buildMessage('0', minute: 0);

      repo.controllers['m1']!.add(backfill);
      await settle();

      expect(shown().map((m) => m.id), ['3', '2', '1', '0']);
    });

    test('a duplicate delivery (same id) is ignored', () async {
      await open();
      final before = states.length;

      repo.controllers['m1']!.add(newest);
      await settle();

      expect(states.length, before);
      expect(shown(), hasLength(3));
    });

    test('an unread message from the other person marks the chat read again',
        () async {
      await open();
      expect(repo.markAllReadCalls, hasLength(1));

      repo.controllers['m1']!.add(buildMessage('4', minute: 4));
      await settle();

      expect(repo.markAllReadCalls, ['m1', 'm1']);
    });

    test('my own echoed message does not trigger mark-read', () async {
      await open();

      repo.controllers['m1']!.add(
        buildMessage('4', minute: 4, senderId: 'me', receiverId: 'other'),
      );
      await settle();

      expect(repo.markAllReadCalls, hasLength(1));
      expect(shown().first.id, '4');
    });

    test('an already-read message does not trigger mark-read', () async {
      await open();

      repo.controllers['m1']!.add(buildMessage('4', minute: 4, isRead: true));
      await settle();

      expect(repo.markAllReadCalls, hasLength(1));
    });

    test('without a current user id incoming messages are not marked read',
        () async {
      await open(me: null);
      expect(repo.markAllReadCalls, hasLength(1)); // opening still marks read

      repo.controllers['m1']!.add(buildMessage('4', minute: 4));
      await settle();

      expect(repo.markAllReadCalls, hasLength(1));
    });

    test('a burst of messages coalesces into one in-flight call plus one '
        'follow-up', () async {
      final firstMarkRead = Completer<void>();
      var calls = 0;
      repo.onMarkAllMessagesAsRead = (_) {
        calls++;
        return calls == 1 ? firstMarkRead.future : Future<void>.value();
      };

      await open();
      for (var i = 4; i < 9; i++) {
        repo.controllers['m1']!.add(buildMessage('$i', minute: i));
      }
      await settle();
      expect(repo.markAllReadCalls, hasLength(1), reason: 'still in flight');

      firstMarkRead.complete();
      await settle();

      expect(repo.markAllReadCalls, hasLength(2));
      expect(shown(), hasLength(8));
    });

    test('a failing mark-read is swallowed and does not block later ones',
        () async {
      repo.onMarkAllMessagesAsRead =
          (_) async => throw Exception('rpc missing');
      await open();

      repo.controllers['m1']!.add(buildMessage('4', minute: 4));
      await settle();

      expect(states.whereType<ChatError>(), isEmpty);
      expect(repo.markAllReadCalls, hasLength(2));
    });

    test('a stream error is logged and the chat stays usable', () async {
      await open();

      repo.controllers['m1']!.addError(Exception('socket closed'));
      await settle();
      expect(bloc.state, isA<ChatLoaded>());

      repo.controllers['m1']!.add(buildMessage('4', minute: 4));
      await settle();
      expect(shown(), hasLength(4));
    });
  });

  group('SendMessageEvent', () {
    test('appends the sent message (newest first) and passes the arguments',
        () async {
      await open();

      bloc.add(const SendMessageEvent(
        matchId: 'm1',
        receiverId: 'other',
        content: 'hello there',
      ));
      await settle();

      expect(repo.sentMessages, [('m1', 'other', 'hello there')]);
      expect(shown().first.content, 'hello there');
      expect(shown(), hasLength(4));
      expect(states.last, isA<ChatLoaded>());
    });

    test('does not duplicate a message the realtime feed already delivered',
        () async {
      await open();
      final echoed = buildMessage(
        'x',
        minute: 99,
        senderId: 'me',
        receiverId: 'other',
        content: 'race',
      );
      final send = Completer<MessageEntity>();
      repo.onSendMessage = (_, __, ___) => send.future;

      bloc.add(const SendMessageEvent(
        matchId: 'm1',
        receiverId: 'other',
        content: 'race',
      ));
      await settle();
      repo.controllers['m1']!.add(echoed);
      await settle();
      final before = states.length;

      send.complete(echoed);
      await settle();

      expect(states.length, before, reason: 'no redundant emit');
      expect(shown().where((m) => m.id == 'x'), hasLength(1));
    });

    test('a failed send reports the error and keeps the messages', () async {
      await open();
      repo.onSendMessage = (_, __, ___) async => throw Exception('offline');

      bloc.add(const SendMessageEvent(
        matchId: 'm1',
        receiverId: 'other',
        content: 'lost',
      ));
      await settle();

      expect(states.sublist(2), [
        ChatSendError(messages: [newest, middle, oldest], error: _sendError),
        ChatLoaded([newest, middle, oldest]),
      ]);
    });
  });

  blocTest<ChatBloc, ChatState>(
    'starts in ChatInitial and emits nothing without events',
    build: () => ChatBloc(FakeChatRepository()),
    expect: () => <ChatState>[],
    verify: (bloc) => expect(bloc.state, ChatInitial()),
  );
}
