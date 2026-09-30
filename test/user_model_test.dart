import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/data/models/user_model.dart';
import 'package:gitalong/domain/entities/user_entity.dart';

void main() {
  group('UserModel.fromJson', () {
    test('parses a public_profiles row that has no email', () {
      final user = UserModel.fromJson(<String, dynamic>{
        'id': 'u-1',
        'username': 'octocat',
        'name': 'Mona',
        'followers': 12,
        'following': 3,
        'public_repos': 8,
        'total_stars': 1500,
        'languages': ['Dart', 'Go'],
        'interests': ['Open Source'],
        'github_topics': ['flutter'],
        'looking_for': ['cofounder'],
        'seeking_skills': ['TypeScript'],
        'pitch': 'Building a dev tool',
        'created_at': '2026-01-02T03:04:05Z',
      });

      expect(user.id, 'u-1');
      expect(user.username, 'octocat');
      expect(user.email, '');
      expect(user.name, 'Mona');
      expect(user.followers, 12);
      expect(user.following, 3);
      expect(user.publicRepos, 8);
      expect(user.totalStars, 1500);
      expect(user.languages, ['Dart', 'Go']);
      expect(user.interests, ['Open Source']);
      expect(user.githubTopics, ['flutter']);
      expect(user.lookingFor, ['cofounder']);
      expect(user.seekingSkills, ['TypeScript']);
      expect(user.pitch, 'Building a dev tool');
      expect(user.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(user.githubSyncedAt, isNull);
      expect(user.matchReasons, isEmpty);
    });

    test('tolerates nulls and missing fields', () {
      final user = UserModel.fromJson(<String, dynamic>{
        'id': 'u-2',
        'username': 'dev',
        'email': null,
        'name': null,
        'followers': null,
        'public_repos': null,
        'total_stars': null,
        'languages': null,
        'interests': null,
        'looking_for': null,
        'seeking_skills': null,
        'pitch': null,
        'last_active_at': null,
      });

      expect(user.email, '');
      expect(user.name, isNull);
      expect(user.followers, 0);
      expect(user.following, 0);
      expect(user.publicRepos, 0);
      expect(user.totalStars, 0);
      expect(user.languages, isEmpty);
      expect(user.interests, isEmpty);
      expect(user.githubTopics, isEmpty);
      expect(user.lookingFor, isEmpty);
      expect(user.seekingSkills, isEmpty);
      expect(user.pitch, isNull);
      expect(user.lastActiveAt, isNull);
      expect(user.matchScore, isNull);
      expect(user.scoreBreakdown, isNull);
      // Missing created_at falls back to "now".
      expect(
        DateTime.now().difference(user.createdAt).inMinutes.abs(),
        lessThan(1),
      );
    });

    test('converts numeric values of any num type to int', () {
      final user = UserModel.fromJson(<String, dynamic>{
        'id': 'u-3',
        'username': 'dev',
        'followers': 12.0,
        'public_repos': 7,
        'total_stars': 42.9,
      });

      expect(user.followers, 12);
      expect(user.publicRepos, 7);
      expect(user.totalStars, 42);
    });

    test('reads recommendation fields', () {
      final user = UserModel.fromJson(<String, dynamic>{
        'id': 'u-4',
        'username': 'dev',
        'match_score': 87,
        'match_reasons': [
          "You're both looking for a co-founder",
          'Knows TypeScript — a skill you want',
        ],
        'score_breakdown': {'intent_fit': 100, 'tech_match': 55.5},
        'github_synced_at': '2026-09-01T00:00:00Z',
      });

      expect(user.matchScore, 87.0);
      expect(user.matchReasons, hasLength(2));
      expect(user.matchReasons.first, "You're both looking for a co-founder");
      expect(user.scoreBreakdown, isNotNull);
      expect(user.scoreBreakdown!['intent_fit'], 100);
      expect(user.githubSyncedAt, DateTime.utc(2026, 9, 1));
    });
  });

  group('UserModel.toUpdateJson', () {
    const editableKeys = {
      'name',
      'bio',
      'location',
      'company',
      'website_url',
      'languages',
      'interests',
      'looking_for',
      'seeking_skills',
      'pitch',
    };

    UserEntity baseUser() => UserEntity(
          id: 'u-1',
          username: 'octocat',
          email: 'mona@example.com',
          name: 'Mona',
          bio: 'Bio',
          avatarUrl: 'https://example.com/a.png',
          location: 'Berlin',
          company: 'ACME',
          websiteUrl: 'https://example.com',
          githubUrl: 'https://github.com/octocat',
          followers: 100,
          following: 5,
          publicRepos: 20,
          totalStars: 999,
          languages: const ['Dart'],
          interests: const ['Open Source'],
          githubTopics: const ['flutter'],
          lookingFor: const ['side_project'],
          seekingSkills: const ['Go'],
          pitch: 'A pitch',
          createdAt: DateTime.utc(2026, 1, 1),
          lastActiveAt: DateTime.utc(2026, 9, 1),
          githubSyncedAt: DateTime.utc(2026, 9, 1),
          matchScore: 80,
          scoreBreakdown: const {'intent_fit': 100},
          matchReasons: const ['reason'],
        );

    test('contains only the editable columns', () {
      final json = UserModel.fromEntity(baseUser()).toUpdateJson();

      expect(json.keys.toSet(), editableKeys);
      for (final forbidden in [
        'id',
        'email',
        'username',
        'avatar_url',
        'github_url',
        'followers',
        'following',
        'public_repos',
        'total_stars',
        'github_topics',
        'github_synced_at',
        'created_at',
        'last_active_at',
        'match_score',
        'score_breakdown',
        'match_reasons',
      ]) {
        expect(json.containsKey(forbidden), isFalse, reason: forbidden);
      }
      expect(json['name'], 'Mona');
      expect(json['languages'], ['Dart']);
      expect(json['looking_for'], ['side_project']);
      expect(json['seeking_skills'], ['Go']);
      expect(json['pitch'], 'A pitch');
    });

    test('sends explicit nulls so fields can be cleared', () {
      final cleared = baseUser().withEditableFields(
        name: 'Mona',
        bio: null,
        location: null,
        company: '   ',
        websiteUrl: null,
        languages: const ['Dart'],
        interests: const ['Open Source'],
        lookingFor: const ['cofounder'],
        seekingSkills: const [],
        pitch: null,
      );
      final json = UserModel.fromEntity(cleared).toUpdateJson();

      expect(json.keys.toSet(), editableKeys);
      for (final key in ['bio', 'location', 'company', 'website_url', 'pitch']) {
        expect(json.containsKey(key), isTrue, reason: key);
        expect(json[key], isNull, reason: key);
      }
      expect(json['seeking_skills'], isEmpty);
    });

    test('drops looking_for values the database would reject', () {
      final user = baseUser().copyWith(
        lookingFor: const ['cofounder', 'not_a_real_intent', 'mentor'],
      );
      final json = UserModel.fromEntity(user).toUpdateJson();

      expect(json['looking_for'], ['cofounder', 'mentor']);
    });
  });
}
