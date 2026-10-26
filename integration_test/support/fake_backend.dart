// In-memory stand-ins for every Supabase/backend-facing dependency, sharing
// one small "world" (users, swipes, matches, messages, progress) so the real
// blocs, use cases, router and screens can run end to end without a network.

import 'dart:async';

import 'package:gitalong/core/auth/auth_session.dart';
import 'package:gitalong/data/services/backend_api_client.dart';
import 'package:gitalong/domain/entities/match_entity.dart';
import 'package:gitalong/domain/entities/message_entity.dart';
import 'package:gitalong/domain/entities/notification_entity.dart';
import 'package:gitalong/domain/entities/progress_entity.dart';
import 'package:gitalong/domain/entities/swipe_entity.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:gitalong/domain/repositories/auth_repository.dart';
import 'package:gitalong/domain/repositories/chat_repository.dart';
import 'package:gitalong/domain/repositories/match_repository.dart';
import 'package:gitalong/domain/repositories/notification_repository.dart';
import 'package:gitalong/domain/repositories/progress_repository.dart';
import 'package:gitalong/domain/repositories/swipe_repository.dart';
import 'package:gitalong/domain/repositories/user_repository.dart';

/// Seeded sample developers and ids used by the flows.
class Seed {
  Seed._();

  static final DateTime now = DateTime(2026, 10, 26, 12);

  static const String meId = 'u-me';
  static const String newUserId = 'u-new';
  static const String linusId = 'u-linus';
  static const String graceId = 'u-grace';
  static const String margaretId = 'u-margaret';
  static const String samId = 'u-sam';
  static const String noorId = 'u-noor';

  static const String samMatchId = 'm-sam';
  static const String noorMatchId = 'm-noor';

  static const String samLastMessage =
      'Want to pair on the sync engine this weekend?';

  static const String linusReason = 'You both want a side-project partner';
  static const String linusReason2 = 'Writes Go, a skill you are looking for';
  static const String graceReason = 'You both write Dart';

  /// Signed-in user with a finished profile.
  static UserEntity me() => UserEntity(
        id: meId,
        username: 'ada-dev',
        email: 'ada@example.com',
        name: 'Ada Lovelace',
        bio: 'Flutter engineer who loves offline-first apps.',
        location: 'London',
        githubUrl: 'https://github.com/ada-dev',
        followers: 310,
        following: 12,
        publicRepos: 42,
        totalStars: 1280,
        languages: const ['Dart', 'Rust'],
        interests: const ['Mobile Dev', 'Open Source'],
        lookingFor: const ['side_project', 'open_source'],
        seekingSkills: const ['Go'],
        pitch: 'Building an offline-first notes app in Flutter.',
        createdAt: now.subtract(const Duration(days: 90)),
        githubSyncedAt: now.subtract(const Duration(hours: 2)),
      );

  /// Freshly signed-up user: no setup answers, GitHub never synced.
  static UserEntity newUser() => UserEntity(
        id: newUserId,
        username: 'riley-codes',
        email: 'riley@example.com',
        name: 'Riley Chen',
        createdAt: now,
      );

  static UserEntity linus() => UserEntity(
        id: linusId,
        username: 'lpark',
        email: '',
        name: 'Linus Park',
        location: 'Berlin',
        publicRepos: 61,
        totalStars: 2400,
        followers: 520,
        languages: const ['Go', 'Rust'],
        interests: const ['Backend', 'Open Source'],
        lookingFor: const ['side_project'],
        pitch: 'A tiny self-hosted CI runner written in Go.',
        createdAt: now.subtract(const Duration(days: 400)),
        matchScore: 92,
        matchReasons: const [linusReason, linusReason2],
      );

  static UserEntity grace() => UserEntity(
        id: graceId,
        username: 'gkim',
        email: '',
        name: 'Grace Kim',
        location: 'Seoul',
        publicRepos: 33,
        totalStars: 870,
        followers: 210,
        languages: const ['Dart', 'Kotlin'],
        interests: const ['Mobile Dev'],
        lookingFor: const ['open_source'],
        bio: 'Android + Flutter. Maintainer of a popular animation package.',
        createdAt: now.subtract(const Duration(days: 300)),
        matchScore: 88,
        matchReasons: const [graceReason],
      );

  static UserEntity margaret() => UserEntity(
        id: margaretId,
        username: 'mhamilton',
        email: '',
        name: 'Margaret Hamilton',
        publicRepos: 12,
        totalStars: 95,
        followers: 40,
        languages: const ['Python'],
        lookingFor: const ['mentor'],
        createdAt: now.subtract(const Duration(days: 50)),
        matchScore: 61,
        matchReasons: const ['Wants to mentor'],
      );

  static UserEntity sam() => UserEntity(
        id: samId,
        username: 'samr',
        email: '',
        name: 'Sam Rivera',
        languages: const ['Dart', 'Go'],
        lookingFor: const ['side_project'],
        createdAt: now.subtract(const Duration(days: 200)),
      );

  static UserEntity noor() => UserEntity(
        id: noorId,
        username: 'noorh',
        email: '',
        name: 'Noor Haddad',
        languages: const ['Rust', 'TypeScript'],
        interests: const ['Open Source'],
        lookingFor: const ['open_source'],
        pitch: 'A Rust-powered static site generator.',
        createdAt: now.subtract(const Duration(days: 120)),
      );

  static ProgressEntity progress() => const ProgressEntity(
        streakDays: 3,
        bestStreak: 5,
        activeToday: true,
        weekActivity: [false, false, false, false, true, true, true],
        todaySwipes: 2,
        totalSwipes: 48,
        matches: 2,
        conversationsStarted: 1,
        messagesSent: 7,
        xp: 160,
        level: 2,
        levelFloorXp: 100,
        nextLevelXp: 250,
        achievements: ['first_swipe', 'first_match', 'streak_3'],
      );
}

class _MatchRow {
  _MatchRow({
    required this.id,
    required this.otherId,
    required this.matchedAt,
  });

  final String id;
  final String otherId;
  final DateTime matchedAt;
  String? lastMessage;
  DateTime? lastMessageAt;
  String? lastMessageSenderId;

  /// The `matches.is_read` flag.
  bool isRead = true;
}

/// The in-memory world behind all fakes.
class FakeBackend {
  FakeBackend._();

  /// Signed out on launch; signing in with GitHub creates [newUser] (a
  /// brand-new account that still has to set up its profile).
  factory FakeBackend.signedOutNewUser() {
    final b = FakeBackend._();
    b._addUser(Seed.newUser());
    b.signInAs = Seed.newUserId;
    b._seedCandidates();
    return b;
  }

  /// Already signed in as [Seed.me] with a finished profile, two matches
  /// (one with an unread message) and three recommendations, the second of
  /// whom already liked the user.
  factory FakeBackend.signedInWithProfile() {
    final b = FakeBackend._();
    b._addUser(Seed.me());
    b.currentUserId = Seed.meId;
    b.signInAs = Seed.meId;
    b._seedCandidates();
    b._addUser(Seed.sam());
    b._addUser(Seed.noor());

    final sam = _MatchRow(
      id: Seed.samMatchId,
      otherId: Seed.samId,
      matchedAt: Seed.now.subtract(const Duration(days: 2)),
    );
    b._matches[sam.id] = sam;
    b._messages[sam.id] = [
      MessageEntity(
        id: 'msg-1',
        matchId: sam.id,
        senderId: Seed.meId,
        receiverId: Seed.samId,
        content: 'Hey Sam! Loved your sync engine repo.',
        sentAt: Seed.now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
      MessageEntity(
        id: 'msg-2',
        matchId: sam.id,
        senderId: Seed.samId,
        receiverId: Seed.meId,
        content: Seed.samLastMessage,
        sentAt: Seed.now.subtract(const Duration(hours: 5)),
      ),
    ];
    sam
      ..lastMessage = Seed.samLastMessage
      ..lastMessageAt = Seed.now.subtract(const Duration(hours: 5))
      ..lastMessageSenderId = Seed.samId
      ..isRead = false;

    final noor = _MatchRow(
      id: Seed.noorMatchId,
      otherId: Seed.noorId,
      matchedAt: Seed.now.subtract(const Duration(hours: 1)),
    );
    b._matches[noor.id] = noor;
    b._messages[noor.id] = [];
    return b;
  }

  // ── State ────────────────────────────────────────────────────────────────

  final Map<String, UserEntity> _users = {};
  final List<String> _candidateIds = [];

  /// People who liked the signed-in user and wait for their swipe.
  final Set<String> _likedMe = {};
  final Map<String, SwipeAction> _swipes = {};
  final Map<String, _MatchRow> _matches = {};
  final Map<String, List<MessageEntity>> _messages = {};
  final Map<String, StreamController<MessageEntity>> _messageStreams = {};
  final StreamController<AuthSessionChange> _sessionChanges =
      StreamController<AuthSessionChange>.broadcast();
  final StreamController<NewMatchNotification> _notifications =
      StreamController<NewMatchNotification>.broadcast();

  String? currentUserId;

  /// Who "Continue with GitHub" signs in.
  String? signInAs;

  /// How long the launch session lookup takes (keeps the splash visible).
  Duration sessionLookupDelay = Duration.zero;

  ProgressEntity? progress = Seed.progress();
  ProgressMilestones? seenMilestones;
  int _ids = 0;

  /// Calls made, for assertions.
  final List<String> calls = [];

  void _addUser(UserEntity user) => _users[user.id] = user;

  void _seedCandidates() {
    for (final user in [Seed.linus(), Seed.grace(), Seed.margaret()]) {
      _addUser(user);
      _candidateIds.add(user.id);
    }
    _likedMe.add(Seed.graceId);
  }

  String _requireMe() {
    final id = currentUserId;
    if (id == null) throw Exception('No user signed in');
    return id;
  }

  String _nextId(String prefix) => '$prefix-${++_ids}';

  UserEntity user(String id) {
    final user = _users[id];
    if (user == null) throw Exception('User $id not found');
    return user;
  }

  MatchEntity _toEntity(_MatchRow row) {
    final myId = _requireMe();
    final unread = MatchEntity.isUnreadFor(
      lastMessage: row.lastMessage,
      isRead: row.isRead,
      lastMessageSenderId: row.lastMessageSenderId,
      myId: myId,
    );
    return MatchEntity(
      id: row.id,
      user: user(row.otherId),
      matchedAt: row.matchedAt,
      lastMessage: row.lastMessage,
      lastMessageAt: row.lastMessageAt,
      lastMessageSenderId: row.lastMessageSenderId,
      isRead: !unread,
    );
  }

  _MatchRow? _matchWith(String otherId) {
    for (final row in _matches.values) {
      if (row.otherId == otherId) return row;
    }
    return null;
  }

  StreamController<MessageEntity> _streamFor(String matchId) =>
      _messageStreams.putIfAbsent(
        matchId,
        () => StreamController<MessageEntity>.broadcast(),
      );

  /// Simulates the other person sending a message in realtime.
  void receiveMessage(String matchId, String content) {
    final row = _matches[matchId]!;
    final message = MessageEntity(
      id: _nextId('msg'),
      matchId: matchId,
      senderId: row.otherId,
      receiverId: _requireMe(),
      content: content,
      sentAt: DateTime.now(),
    );
    _messages[matchId]!.add(message);
    row
      ..lastMessage = content
      ..lastMessageAt = message.sentAt
      ..lastMessageSenderId = row.otherId
      ..isRead = false;
    _streamFor(matchId).add(message);
  }

  /// Whether the `is_read` flag of [matchId] is set.
  bool isMatchRead(String matchId) => _matches[matchId]!.isRead;

  List<MessageEntity> messagesOf(String matchId) =>
      List.unmodifiable(_messages[matchId] ?? const []);

  // ── Fakes ────────────────────────────────────────────────────────────────

  late final FakeAuthSession session = FakeAuthSession(this);
  late final FakeAuthRepository auth = FakeAuthRepository(this);
  late final FakeUserRepository users = FakeUserRepository(this);
  late final FakeSwipeRepository swipes = FakeSwipeRepository(this);
  late final FakeMatchRepository matches = FakeMatchRepository(this);
  late final FakeChatRepository chat = FakeChatRepository(this);
  late final FakeNotificationRepository notifications =
      FakeNotificationRepository(this);
  late final FakeProgressRepository progressRepository =
      FakeProgressRepository(this);
  late final FakeBackendApiClient backendApi = FakeBackendApiClient(this);

  Future<void> dispose() async {
    await _sessionChanges.close();
    await _notifications.close();
    for (final controller in _messageStreams.values) {
      await controller.close();
    }
  }
}

class FakeAuthSession implements AuthSession {
  FakeAuthSession(this._b);
  final FakeBackend _b;

  @override
  String? get currentUserId => _b.currentUserId;

  @override
  Stream<AuthSessionChange> get changes => _b._sessionChanges.stream;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._b);
  final FakeBackend _b;

  /// Like the real OAuth flow: the browser "returns" asynchronously and the
  /// session stream reports the sign-in; the returned entity is a dummy.
  @override
  Future<UserEntity> signInWithGitHub() async {
    _b.calls.add('signInWithGitHub');
    final id = _b.signInAs;
    if (id == null) throw Exception('Failed to launch GitHub login');
    scheduleMicrotask(() {
      _b.currentUserId = id;
      _b._sessionChanges.add(AuthSessionChange.signedIn);
    });
    return UserEntity(id: '', username: '', email: '', createdAt: Seed.now);
  }

  @override
  Future<UserEntity> signInWithGoogle() =>
      Future.error(UnsupportedError('Google sign-in is not used'));

  @override
  Future<UserEntity> signInWithApple() =>
      Future.error(UnsupportedError('Apple sign-in is not used'));

  @override
  Future<void> signOut() async {
    _b.calls.add('signOut');
    _b.currentUserId = null;
    _b._sessionChanges.add(AuthSessionChange.signedOut);
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    if (_b.sessionLookupDelay > Duration.zero) {
      await Future<void>.delayed(_b.sessionLookupDelay);
    }
    final id = _b.currentUserId;
    return id == null ? null : _b._users[id];
  }

  @override
  Future<bool> isAuthenticated() async => _b.currentUserId != null;

  @override
  Future<void> deleteAccount() async {
    _b.calls.add('deleteAccount');
    final id = _b._requireMe();
    _b._users.remove(id);
    _b.currentUserId = null;
    _b._sessionChanges.add(AuthSessionChange.signedOut);
  }
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository(this._b);
  final FakeBackend _b;

  @override
  Future<UserEntity> getUserById(String userId) async => _b.user(userId);

  @override
  Future<UserEntity> getUserByUsername(String username) async =>
      _b._users.values.firstWhere(
        (u) => u.username == username,
        orElse: () => throw Exception('User $username not found'),
      );

  @override
  Future<UserEntity> getCurrentUserProfile() async => _b.user(_b._requireMe());

  @override
  Future<UserEntity> updateUserProfile(UserEntity user) async {
    _b.calls.add('updateUserProfile');
    final id = _b._requireMe();
    if (user.id != id) throw Exception('Can only update your own profile');
    _b._users[id] = user;
    return user;
  }

  @override
  Future<List<UserEntity>> getRecommendedUsers({
    int limit = 20,
    String? cursor,
  }) async {
    final myId = _b._requireMe();
    return _b._candidateIds
        .where((id) =>
            id != myId &&
            !_b._swipes.containsKey(id) &&
            _b._matchWith(id) == null)
        .map(_b.user)
        .take(limit)
        .toList();
  }

  @override
  Future<List<UserEntity>> searchUsers({
    required String query,
    int limit = 20,
    String? cursor,
  }) async {
    final q = query.toLowerCase();
    return _b._users.values
        .where((u) =>
            u.username.toLowerCase().contains(q) ||
            (u.name?.toLowerCase().contains(q) ?? false))
        .take(limit)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getUserGitHubStats(String username) async {
    final user = await getUserByUsername(username);
    return {
      'public_repos': user.publicRepos,
      'total_stars': user.totalStars,
      'followers': user.followers,
    };
  }
}

class FakeSwipeRepository implements SwipeRepository {
  FakeSwipeRepository(this._b);
  final FakeBackend _b;

  /// Mirrors the database trigger: a like on someone who already liked you
  /// creates the match.
  @override
  Future<MatchEntity?> swipeUser({
    required String swipedUserId,
    required SwipeAction action,
  }) async {
    _b._requireMe();
    _b.calls.add('swipe:$swipedUserId:${action.name}');
    _b._swipes[swipedUserId] = action;
    if (action == SwipeAction.dislike) return null;
    if (_b._likedMe.remove(swipedUserId)) {
      final row = _MatchRow(
        id: _b._nextId('m'),
        otherId: swipedUserId,
        matchedAt: DateTime.now(),
      );
      _b._matches[row.id] = row;
      _b._messages[row.id] = [];
    }
    return checkForMatch(swipedUserId);
  }

  @override
  Future<MatchEntity?> checkForMatch(String swipedUserId) async {
    final row = _b._matchWith(swipedUserId);
    return row == null ? null : _b._toEntity(row);
  }

  @override
  Future<List<SwipeEntity>> getSwipeHistory({
    int limit = 50,
    String? cursor,
  }) async {
    final myId = _b._requireMe();
    return [
      for (final entry in _b._swipes.entries)
        SwipeEntity(
          id: 'swipe-${entry.key}',
          swiperId: myId,
          swipedUserId: entry.key,
          action: entry.value,
          swipedAt: Seed.now,
        ),
    ].take(limit).toList();
  }

  @override
  Future<void> undoLastSwipe() async {
    if (_b._swipes.isNotEmpty) _b._swipes.remove(_b._swipes.keys.last);
  }

  @override
  Future<List<String>> getSwipedUserIds() async => _b._swipes.keys.toList();
}

class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository(this._b);
  final FakeBackend _b;

  @override
  Future<List<MatchEntity>> getMatches({int limit = 50, String? cursor}) async {
    _b._requireMe();
    final rows = _b._matches.values.toList()
      ..sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
    return rows.take(limit).map(_b._toEntity).toList();
  }

  @override
  Future<MatchEntity> getMatchById(String matchId) async {
    final row = _b._matches[matchId];
    if (row == null) throw Exception('Match $matchId not found');
    return _b._toEntity(row);
  }

  @override
  Future<void> unmatch(String matchId) async {
    _b.calls.add('unmatch:$matchId');
    _b._matches.remove(matchId);
    _b._messages.remove(matchId);
  }

  @override
  Future<bool> isMatched(String userId) async => _b._matchWith(userId) != null;

  @override
  Future<void> blockUser(String userId) async {
    _b.calls.add('block:$userId');
    final row = _b._matchWith(userId);
    if (row != null) await unmatch(row.id);
    _b._candidateIds.remove(userId);
  }

  @override
  Future<void> reportUser({
    required String userId,
    String? matchId,
    required String reason,
    String? details,
  }) async {
    _b.calls.add('report:$userId:$reason');
  }

  @override
  Future<int> getLikesReceivedCount() async => _b._likedMe
      .where((id) => !_b._swipes.containsKey(id))
      .length;
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository(this._b);
  final FakeBackend _b;

  @override
  Future<List<MessageEntity>> getMessages({
    required String matchId,
    int limit = 50,
    String? cursor,
  }) async {
    final messages = _b._messages[matchId];
    if (messages == null) throw Exception('Match $matchId not found');
    final sorted = List.of(messages)
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<MessageEntity> sendMessage({
    required String matchId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final myId = _b._requireMe();
    final row = _b._matches[matchId];
    if (row == null) throw Exception('Match $matchId not found');
    final message = MessageEntity(
      id: _b._nextId('msg'),
      matchId: matchId,
      senderId: myId,
      receiverId: receiverId,
      content: content,
      type: type,
      sentAt: DateTime.now(),
    );
    _b._messages[matchId]!.add(message);
    row
      ..lastMessage = content
      ..lastMessageAt = message.sentAt
      ..lastMessageSenderId = myId
      ..isRead = false;
    // Realtime echoes your own insert too; the bloc de-duplicates by id.
    _b._streamFor(matchId).add(message);
    return message;
  }

  @override
  Future<void> markMessageAsRead(String messageId) async {}

  @override
  Future<void> markAllMessagesAsRead(String matchId) async {
    final myId = _b._requireMe();
    final row = _b._matches[matchId];
    // `mark_match_read` only clears messages the other person sent.
    if (row != null && row.lastMessageSenderId != myId) row.isRead = true;
  }

  @override
  Stream<MessageEntity> listenToMessages(String matchId) =>
      _b._streamFor(matchId).stream;

  @override
  Future<void> deleteMessage(String messageId) async {
    for (final list in _b._messages.values) {
      list.removeWhere((m) => m.id == messageId);
    }
  }
}

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(this._b);
  final FakeBackend _b;

  @override
  Stream<NewMatchNotification> listenToNewMatchNotifications(String userId) =>
      _b._notifications.stream;
}

class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository(this._b);
  final FakeBackend _b;

  @override
  Future<ProgressEntity?> getMyProgress() async =>
      _b.currentUserId == null ? null : _b.progress;

  @override
  Future<ProgressMilestones?> readSeenMilestones() async => _b.seenMilestones;

  @override
  Future<void> saveSeenMilestones(ProgressMilestones milestones) async {
    _b.seenMilestones = milestones;
  }
}

/// Stands in for the Python backend client (implements its public API only;
/// it never touches Supabase).
class FakeBackendApiClient implements BackendApiClient {
  FakeBackendApiClient(this._b);
  final FakeBackend _b;

  /// Languages "found on GitHub" by [refreshGitHubStats].
  List<String> githubLanguages = const ['TypeScript', 'Python'];

  @override
  Future<List<UserEntity>> getRecommendations({int limit = 20}) =>
      _b.users.getRecommendedUsers(limit: limit);

  @override
  Future<Map<String, dynamic>> refreshGitHubStats() async {
    _b.calls.add('refreshGitHubStats');
    final id = _b._requireMe();
    final user = _b.user(id);
    _b._users[id] = user.copyWith(
      languages: githubLanguages,
      publicRepos: 18,
      totalStars: 240,
      followers: 75,
      githubSyncedAt: DateTime.now(),
    );
    return {'status': 'ok'};
  }

  @override
  Future<bool> deleteAccount() async => true;
}
