import '../../entities/user_entity.dart';

/// One of the 8 profile-strength checks (docs/DESIGN_SYSTEM.md §6).
class ProfileCheck {
  /// Stable key, used in [profileStrength]'s `missing` list.
  final String key;

  /// Checklist label, e.g. "Write a bio".
  final String label;

  /// One-line hint on how to complete it.
  final String hint;

  const ProfileCheck({
    required this.key,
    required this.label,
    required this.hint,
  });
}

/// The profile-strength checklist. The server's `profile_complete` uses the
/// same 8 checks, in this order.
class ProfileChecks {
  ProfileChecks._();

  static const String avatar = 'avatar';
  static const String bio = 'bio';
  static const String pitch = 'pitch';
  static const String lookingFor = 'looking_for';
  static const String languages = 'languages';
  static const String interests = 'interests';
  static const String seekingSkills = 'seeking_skills';
  static const String location = 'location';

  static const List<ProfileCheck> all = [
    ProfileCheck(
      key: avatar,
      label: 'Add a profile photo',
      hint: 'Your photo comes from GitHub. Add one there, then refresh.',
    ),
    ProfileCheck(
      key: bio,
      label: 'Write a bio',
      hint: 'A line or two about you and what you like to build.',
    ),
    ProfileCheck(
      key: pitch,
      label: 'Add your pitch',
      hint: "Say what you're building or want to build.",
    ),
    ProfileCheck(
      key: lookingFor,
      label: "Say what you're looking for",
      hint: 'Co-founder, side project, open source, hackathon or mentoring.',
    ),
    ProfileCheck(
      key: languages,
      label: 'Add your languages',
      hint: 'The languages you code in.',
    ),
    ProfileCheck(
      key: interests,
      label: 'Pick your interests',
      hint: 'Topics you care about, like AI or mobile.',
    ),
    ProfileCheck(
      key: seekingSkills,
      label: 'Add skills you want',
      hint: 'What should your collaborator be good at?',
    ),
    ProfileCheck(
      key: location,
      label: 'Add your location',
      hint: 'Your city or time zone helps people plan.',
    ),
  ];

  /// The check for [key], or null.
  static ProfileCheck? byKey(String key) {
    for (final check in all) {
      if (check.key == key) return check;
    }
    return null;
  }
}

/// Profile strength: how many of the 8 checks [user] passes, and the keys of
/// the ones still missing (in [ProfileChecks.all] order).
///
/// Checks: avatar, bio, pitch, ≥ 1 looking_for, ≥ 1 language, ≥ 1 interest,
/// ≥ 1 seeking skill, location. Text fields must be non-blank.
({int done, int total, List<String> missing}) profileStrength(
  UserEntity user,
) {
  bool filled(String? value) => value != null && value.trim().isNotEmpty;

  final passed = <String, bool>{
    ProfileChecks.avatar: filled(user.avatarUrl),
    ProfileChecks.bio: filled(user.bio),
    ProfileChecks.pitch: filled(user.pitch),
    ProfileChecks.lookingFor: user.lookingFor.isNotEmpty,
    ProfileChecks.languages: user.languages.isNotEmpty,
    ProfileChecks.interests: user.interests.isNotEmpty,
    ProfileChecks.seekingSkills: user.seekingSkills.isNotEmpty,
    ProfileChecks.location: filled(user.location),
  };

  final missing = <String>[
    for (final check in ProfileChecks.all)
      if (passed[check.key] != true) check.key,
  ];
  final total = ProfileChecks.all.length;
  return (done: total - missing.length, total: total, missing: missing);
}
