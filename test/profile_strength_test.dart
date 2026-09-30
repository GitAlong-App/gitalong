import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:gitalong/domain/usecases/progress/profile_strength.dart';

UserEntity _user({
  String? avatarUrl,
  String? bio,
  String? pitch,
  String? location,
  List<String> lookingFor = const [],
  List<String> languages = const [],
  List<String> interests = const [],
  List<String> seekingSkills = const [],
}) {
  return UserEntity(
    id: 'u-1',
    username: 'dev',
    email: '',
    avatarUrl: avatarUrl,
    bio: bio,
    pitch: pitch,
    location: location,
    lookingFor: lookingFor,
    languages: languages,
    interests: interests,
    seekingSkills: seekingSkills,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

UserEntity _complete() => _user(
      avatarUrl: 'https://avatars.githubusercontent.com/u/1',
      bio: 'I build dev tools.',
      pitch: 'A CLI that explains CI failures.',
      location: 'Bengaluru',
      lookingFor: const ['cofounder'],
      languages: const ['Dart'],
      interests: const ['Open Source'],
      seekingSkills: const ['TypeScript'],
    );

void main() {
  group('profileStrength', () {
    test('an empty profile passes none of the 8 checks, in order', () {
      final s = profileStrength(_user());
      expect(s.total, 8);
      expect(s.done, 0);
      expect(s.missing, [
        'avatar',
        'bio',
        'pitch',
        'looking_for',
        'languages',
        'interests',
        'seeking_skills',
        'location',
      ]);
    });

    test('a complete profile passes all 8', () {
      final s = profileStrength(_complete());
      expect(s.done, 8);
      expect(s.total, 8);
      expect(s.missing, isEmpty);
    });

    test('each check can fail on its own', () {
      final base = _complete();
      final cases = <String, UserEntity>{
        ProfileChecks.avatar: _user(
          bio: base.bio,
          pitch: base.pitch,
          location: base.location,
          lookingFor: base.lookingFor,
          languages: base.languages,
          interests: base.interests,
          seekingSkills: base.seekingSkills,
        ),
        ProfileChecks.bio: base.withEditableFields(
          name: base.name,
          bio: null,
          location: base.location,
          company: base.company,
          websiteUrl: base.websiteUrl,
          languages: base.languages,
          interests: base.interests,
          lookingFor: base.lookingFor,
          seekingSkills: base.seekingSkills,
          pitch: base.pitch,
        ),
        ProfileChecks.pitch: base.copyWith(pitch: ''),
        ProfileChecks.lookingFor: base.copyWith(lookingFor: const []),
        ProfileChecks.languages: base.copyWith(languages: const []),
        ProfileChecks.interests: base.copyWith(interests: const []),
        ProfileChecks.seekingSkills: base.copyWith(seekingSkills: const []),
        ProfileChecks.location: base.copyWith(location: '   '),
      };

      cases.forEach((key, user) {
        final s = profileStrength(user);
        expect(s.missing, [key], reason: key);
        expect(s.done, 7, reason: key);
      });
    });

    test('blank text does not count', () {
      final s = profileStrength(
        _user(avatarUrl: ' ', bio: '\n\t', pitch: '  ', location: ''),
      );
      expect(s.missing, containsAll(<String>['avatar', 'bio', 'pitch', 'location']));
    });

    test('a single entry is enough for the list checks', () {
      final s = profileStrength(_user(
        lookingFor: const ['mentor'],
        languages: const ['Go'],
        interests: const ['AI / ML'],
        seekingSkills: const ['Rust'],
      ));
      expect(s.done, 4);
      expect(s.missing, ['avatar', 'bio', 'pitch', 'location']);
    });
  });

  group('ProfileChecks', () {
    test('defines the 8 checks with labels and hints', () {
      expect(ProfileChecks.all, hasLength(8));
      final keys = ProfileChecks.all.map((c) => c.key).toSet();
      expect(keys, hasLength(8));
      for (final check in ProfileChecks.all) {
        expect(check.label.trim(), isNotEmpty);
        expect(check.hint.trim(), isNotEmpty);
        expect(ProfileChecks.byKey(check.key), same(check));
      }
      expect(ProfileChecks.byKey('nope'), isNull);
    });
  });
}
