// Hand-written fakes and builders shared by the BLoC tests.
//
// Every fake implements a domain repository interface and exposes its
// behaviour as a replaceable `on...` callback plus a call log, so tests can
// script responses (values, errors, or a Completer's future to control
// ordering) without codegen.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/data/services/backend_api_client.dart';
import 'package:gitalong/domain/entities/match_entity.dart';
import 'package:gitalong/domain/entities/message_entity.dart';
import 'package:gitalong/domain/entities/swipe_entity.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:gitalong/domain/repositories/auth_repository.dart';
import 'package:gitalong/domain/repositories/chat_repository.dart';
import 'package:gitalong/domain/repositories/match_repository.dart';
import 'package:gitalong/domain/repositories/swipe_repository.dart';
import 'package:gitalong/domain/repositories/user_repository.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Lets pending microtasks and zero-duration timers run (event handlers,
/// stream deliveries, unawaited futures).
Future<void> settle([int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final DateTime kEpoch = DateTime.utc(2025, 1, 1);

UserEntity buildUser(
  String id, {
  String? username,
  String? bio,
  List<String> languages = const [],
}) {
  return UserEntity(
    id: id,
    username: username ?? 'user_$id',
    email: '$id@example.com',
    bio: bio,
    languages: languages,
    createdAt: kEpoch,
  );
}

MatchEntity buildMatch(
  String id, {
  UserEntity? user,
  String? lastMessage,
  String? lastMessageSenderId,
  bool isRead = false,
}) {
  return MatchEntity(
    id: id,
    user: user ?? buildUser('other_$id'),
    matchedAt: kEpoch,
    lastMessage: lastMessage,
    lastMessageAt: lastMessage == null ? null : kEpoch,
    lastMessageSenderId: lastMessageSenderId,
    isRead: isRead,
  );
}

MessageEntity buildMessage(
  String id, {
  String matchId = 'm1',
  String senderId = 'other',
  String receiverId = 'me',
  String? content,
  int minute = 0,
  bool isRead = false,
}) {
  return MessageEntity(
    id: id,
    matchId: matchId,
    senderId: senderId,
    receiverId: receiverId,
    content: content ?? 'message $id',
    sentAt: kEpoch.add(Duration(minutes: minute)),
    isRead: isRead,
  );
}

// ── Auth ────────────────────────────────────────────────────────────────────

class FakeAuthRepository implements AuthRepository {
  Future<UserEntity?> Function() onGetCurrentUser = () async => null;
  Future<UserEntity> Function() onSignInWithGitHub =
      () async => buildUser('gh');
  Future<UserEntity> Function() onSignInWithGoogle =
      () async => buildUser('google');
  Future<UserEntity> Function() onSignInWithApple =
      () async => buildUser('apple');
  Future<void> Function() onSignOut = () async {};
  Future<void> Function() onDeleteAccount = () async {};

  int getCurrentUserCalls = 0;
  int signInWithGitHubCalls = 0;
  int signInWithGoogleCalls = 0;
  int signInWithAppleCalls = 0;
  int signOutCalls = 0;
  int deleteAccountCalls = 0;

  @override
  Future<UserEntity?> getCurrentUser() {
    getCurrentUserCalls++;
    return onGetCurrentUser();
  }

  @override
  Future<UserEntity> signInWithGitHub() {
    signInWithGitHubCalls++;
    return onSignInWithGitHub();
  }

  @override
  Future<UserEntity> signInWithGoogle() {
    signInWithGoogleCalls++;
    return onSignInWithGoogle();
  }

  @override
  Future<UserEntity> signInWithApple() {
    signInWithAppleCalls++;
    return onSignInWithApple();
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    return onSignOut();
  }

  @override
  Future<void> deleteAccount() {
    deleteAccountCalls++;
    return onDeleteAccount();
  }

  @override
  Future<bool> isAuthenticated() async => throw UnimplementedError();
}

// ── Users / recommendations ────────────────────────────────────────────────

class FakeUserRepository implements UserRepository {
  Future<List<UserEntity>> Function(int limit) onGetRecommendedUsers =
      (_) async => const [];
  Future<UserEntity> Function(UserEntity user) onUpdateUserProfile =
      (user) async => user;

  final List<int> recommendedLimits = [];
  final List<UserEntity> updatedProfiles = [];

  @override
  Future<List<UserEntity>> getRecommendedUsers({
    int limit = 20,
    String? cursor,
  }) {
    recommendedLimits.add(limit);
    return onGetRecommendedUsers(limit);
  }

  @override
  Future<UserEntity> updateUserProfile(UserEntity user) {
    updatedProfiles.add(user);
    return onUpdateUserProfile(user);
  }

  @override
  Future<UserEntity> getCurrentUserProfile() => throw UnimplementedError();

  @override
  Future<UserEntity> getUserById(String userId) => throw UnimplementedError();

  @override
  Future<UserEntity> getUserByUsername(String username) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getUserGitHubStats(String username) =>
      throw UnimplementedError();

  @override
  Future<List<UserEntity>> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  }) =>
      throw UnimplementedError();
}

// ── Swipes ─────────────────────────────────────────────────────────────────

class FakeSwipeRepository implements SwipeRepository {
  Future<MatchEntity?> Function(String swipedUserId, SwipeAction action)
      onSwipeUser = (_, __) async => null;

  final List<(String, SwipeAction)> swipes = [];

  @override
  Future<MatchEntity?> swipeUser({
    required String swipedUserId,
    required SwipeAction action,
  }) {
    swipes.add((swipedUserId, action));
    return onSwipeUser(swipedUserId, action);
  }

  @override
  Future<MatchEntity?> checkForMatch(String swipedUserId) =>
      throw UnimplementedError();

  @override
  Future<List<SwipeEntity>> getSwipeHistory({int limit = 50, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<List<String>> getSwipedUserIds() => throw UnimplementedError();

  @override
  Future<void> undoLastSwipe() => throw UnimplementedError();
}

// ── Matches ────────────────────────────────────────────────────────────────

class FakeMatchRepository implements MatchRepository {
  Future<List<MatchEntity>> Function(int limit) onGetMatches =
      (_) async => const [];
  Future<int> Function() onGetLikesReceivedCount = () async => 0;

  final List<int> matchLimits = [];
  int likesReceivedCalls = 0;

  @override
  Future<List<MatchEntity>> getMatches({int limit = 50, String? cursor}) {
    matchLimits.add(limit);
    return onGetMatches(limit);
  }

  @override
  Future<int> getLikesReceivedCount() {
    likesReceivedCalls++;
    return onGetLikesReceivedCount();
  }

  @override
  Future<void> blockUser(String userId) => throw UnimplementedError();

  @override
  Future<MatchEntity> getMatchById(String matchId) =>
      throw UnimplementedError();

  @override
  Future<bool> isMatched(String userId) => throw UnimplementedError();

  @override
  Future<void> reportUser({
    required String userId,
    String? matchId,
    required String reason,
    String? details,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> unmatch(String matchId) => throw UnimplementedError();
}

// ── Chat ───────────────────────────────────────────────────────────────────

class FakeChatRepository implements ChatRepository {
  Future<List<MessageEntity>> Function(String matchId) onGetMessages =
      (_) async => const [];
  Future<MessageEntity> Function(
    String matchId,
    String receiverId,
    String content,
  ) onSendMessage = (matchId, receiverId, content) async => MessageEntity(
        id: 'sent_${content.hashCode}',
        matchId: matchId,
        senderId: 'me',
        receiverId: receiverId,
        content: content,
        sentAt: kEpoch.add(const Duration(days: 1)),
      );
  Future<void> Function(String matchId) onMarkAllMessagesAsRead =
      (_) async {};

  final List<String> getMessagesCalls = [];
  final List<(String, String, String)> sentMessages = [];
  final List<String> markAllReadCalls = [];
  final List<String> listenCalls = [];
  final List<String> cancelledStreams = [];

  /// Realtime feed per match; push messages with `controllers[id]!.add`.
  final Map<String, StreamController<MessageEntity>> controllers = {};

  @override
  Future<List<MessageEntity>> getMessages({
    required String matchId,
    int limit = 50,
    String? cursor,
  }) {
    getMessagesCalls.add(matchId);
    return onGetMessages(matchId);
  }

  @override
  Future<MessageEntity> sendMessage({
    required String matchId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) {
    sentMessages.add((matchId, receiverId, content));
    return onSendMessage(matchId, receiverId, content);
  }

  @override
  Future<void> markAllMessagesAsRead(String matchId) {
    markAllReadCalls.add(matchId);
    return onMarkAllMessagesAsRead(matchId);
  }

  @override
  Stream<MessageEntity> listenToMessages(String matchId) {
    listenCalls.add(matchId);
    final controller = StreamController<MessageEntity>(
      onCancel: () => cancelledStreams.add(matchId),
    );
    controllers[matchId] = controller;
    return controller.stream;
  }

  @override
  Future<void> markMessageAsRead(String messageId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMessage(String messageId) => throw UnimplementedError();
}

// ── Backend ────────────────────────────────────────────────────────────────

/// [BackendApiClient] is concrete (HTTP + Supabase session), so this fake
/// only overrides what the blocs call; anything else throws via [Fake].
class FakeBackendApiClient extends Fake implements BackendApiClient {
  Future<Map<String, dynamic>> Function() onRefreshGitHubStats =
      () async => <String, dynamic>{};

  int refreshGitHubStatsCalls = 0;

  @override
  Future<Map<String, dynamic>> refreshGitHubStats() {
    refreshGitHubStatsCalls++;
    return onRefreshGitHubStats();
  }
}
