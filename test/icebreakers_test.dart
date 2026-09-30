import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/utils/icebreakers.dart';
import 'package:gitalong/domain/entities/user_entity.dart';

UserEntity _user({
  String id = 'u',
  String username = 'dev',
  String? name,
  String? pitch,
  List<String> languages = const [],
  List<String> interests = const [],
  List<String> lookingFor = const [],
  List<String> seekingSkills = const [],
}) {
  return UserEntity(
    id: id,
    username: username,
    email: '',
    name: name,
    pitch: pitch,
    languages: languages,
    interests: interests,
    lookingFor: lookingFor,
    seekingSkills: seekingSkills,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('generateIcebreakers', () {
    test('always returns three unique suggestions, even for empty profiles',
        () {
      final result = generateIcebreakers(
        me: _user(id: 'me'),
        other: _user(id: 'other', username: 'octocat'),
      );

      expect(result, hasLength(3));
      expect(result.toSet(), hasLength(3));
      expect(result.first, contains('octocat'));
    });

    test('works without the current user profile', () {
      final result = generateIcebreakers(
        me: null,
        other: _user(id: 'other', name: 'Mona Lisa'),
      );

      expect(result, hasLength(3));
      expect(result.any((s) => s.contains('Mona')), isTrue);
    });

    test("leads with the other person's pitch", () {
      final result = generateIcebreakers(
        me: _user(id: 'me'),
        other: _user(id: 'other', pitch: 'A realtime code review bot'),
      );

      expect(result.first, contains('A realtime code review bot'));
    });

    test('mentions a shared language case-insensitively', () {
      final result = generateIcebreakers(
        me: _user(id: 'me', languages: ['dart', 'Python']),
        other: _user(id: 'other', languages: ['Rust', 'Dart']),
      );

      expect(result.any((s) => s.contains('Dart')), isTrue);
    });

    test('mentions a shared interest', () {
      final result = generateIcebreakers(
        me: _user(id: 'me', interests: ['AI / ML']),
        other: _user(id: 'other', interests: ['AI / ML', 'Cloud']),
      );

      expect(result.any((s) => s.contains('AI / ML')), isTrue);
    });

    test('uses a shared intent', () {
      final result = generateIcebreakers(
        me: _user(id: 'me', lookingFor: ['cofounder']),
        other: _user(id: 'other', lookingFor: ['cofounder']),
      );

      expect(result.any((s) => s.contains('co-founder')), isTrue);
    });

    test('pairs mentees with mentors', () {
      final result = generateIcebreakers(
        me: _user(id: 'me', lookingFor: ['mentee']),
        other: _user(id: 'other', lookingFor: ['mentor']),
      );

      expect(result.any((s) => s.contains('mentor')), isTrue);
    });

    test("references what the other person is here for when it isn't shared",
        () {
      final result = generateIcebreakers(
        me: _user(id: 'me'),
        other: _user(id: 'other', lookingFor: ['hackathon']),
      );

      expect(
        result.any((s) => s.toLowerCase().contains('hackathon teammates')),
        isTrue,
      );
    });

    test('prioritises personal suggestions over generic ones', () {
      final result = generateIcebreakers(
        me: _user(
          id: 'me',
          languages: ['Go'],
          interests: ['Cloud'],
          lookingFor: ['open_source'],
        ),
        other: _user(
          id: 'other',
          pitch: 'Kubernetes operator for hobby clusters',
          languages: ['Go'],
          interests: ['Cloud'],
          lookingFor: ['open_source'],
        ),
      );

      expect(result, hasLength(3));
      expect(result[0], contains('Kubernetes operator'));
      expect(result[1], contains('open-source'));
      expect(result[2], contains('Go'));
    });

    test('respects a custom count', () {
      final result = generateIcebreakers(
        me: _user(id: 'me'),
        other: _user(id: 'other'),
        count: 2,
      );

      expect(result, hasLength(2));
    });
  });
}
