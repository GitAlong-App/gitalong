import '../../core/constants/collab_constants.dart';
import '../../domain/entities/user_entity.dart';

/// User data model — maps Postgres rows (`users`, `public_profiles`) and
/// backend recommendation payloads to [UserEntity].
///
/// Parsing is deliberately tolerant: other people's profiles come from
/// `public_profiles`, which has no `email`, and older rows may have null
/// arrays or counters.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.username,
    required super.email,
    super.name,
    super.bio,
    super.avatarUrl,
    super.location,
    super.company,
    super.websiteUrl,
    super.githubUrl,
    super.followers,
    super.following,
    super.publicRepos,
    super.totalStars,
    super.languages,
    super.interests,
    super.githubTopics,
    super.lookingFor,
    super.seekingSkills,
    super.pitch,
    required super.createdAt,
    super.lastActiveAt,
    super.githubSyncedAt,
    super.matchScore,
    super.scoreBreakdown,
    super.matchReasons,
  });

  /// From a Supabase row or backend JSON object.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: _string(json['username']) ?? '',
      email: _string(json['email']) ?? '',
      name: _string(json['name']),
      bio: _string(json['bio']),
      avatarUrl: _string(json['avatar_url']),
      location: _string(json['location']),
      company: _string(json['company']),
      websiteUrl: _string(json['website_url']),
      githubUrl: _string(json['github_url']),
      followers: _int(json['followers']),
      following: _int(json['following']),
      publicRepos: _int(json['public_repos']),
      totalStars: _int(json['total_stars']),
      languages: _stringList(json['languages']),
      interests: _stringList(json['interests']),
      githubTopics: _stringList(json['github_topics']),
      lookingFor: _stringList(json['looking_for']),
      seekingSkills: _stringList(json['seeking_skills']),
      pitch: _string(json['pitch']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      lastActiveAt: _date(json['last_active_at']),
      githubSyncedAt: _date(json['github_synced_at']),
      matchScore: (json['match_score'] is num)
          ? (json['match_score'] as num).toDouble()
          : null,
      scoreBreakdown: _map(json['score_breakdown']),
      matchReasons: _stringList(json['match_reasons']),
    );
  }

  /// The payload for `update users set ... where id = me`.
  ///
  /// Contains ONLY the columns a client may write (see the data contract);
  /// stats, email, ids and timestamps are owned by the server and rejected
  /// by the database. Nullable fields are always present (as explicit nulls)
  /// so users can clear them.
  Map<String, dynamic> toUpdateJson() => <String, dynamic>{
    'name': _clean(name),
    'bio': _clean(bio),
    'location': _clean(location),
    'company': _clean(company),
    'website_url': _clean(websiteUrl),
    'languages': _cleanList(languages),
    'interests': _cleanList(interests),
    'looking_for': _cleanList(
      lookingFor,
    ).where(CollabConstants.isValidIntent).toList(),
    'seeking_skills': _cleanList(seekingSkills),
    'pitch': _cleanPitch(pitch),
  };

  /// From entity
  factory UserModel.fromEntity(UserEntity entity) => UserModel(
    id: entity.id,
    username: entity.username,
    email: entity.email,
    name: entity.name,
    bio: entity.bio,
    avatarUrl: entity.avatarUrl,
    location: entity.location,
    company: entity.company,
    websiteUrl: entity.websiteUrl,
    githubUrl: entity.githubUrl,
    followers: entity.followers,
    following: entity.following,
    publicRepos: entity.publicRepos,
    totalStars: entity.totalStars,
    languages: entity.languages,
    interests: entity.interests,
    githubTopics: entity.githubTopics,
    lookingFor: entity.lookingFor,
    seekingSkills: entity.seekingSkills,
    pitch: entity.pitch,
    createdAt: entity.createdAt,
    lastActiveAt: entity.lastActiveAt,
    githubSyncedAt: entity.githubSyncedAt,
    matchScore: entity.matchScore,
    scoreBreakdown: entity.scoreBreakdown,
    matchReasons: entity.matchReasons,
  );

  /// To entity
  UserEntity toEntity() => UserEntity(
    id: id,
    username: username,
    email: email,
    name: name,
    bio: bio,
    avatarUrl: avatarUrl,
    location: location,
    company: company,
    websiteUrl: websiteUrl,
    githubUrl: githubUrl,
    followers: followers,
    following: following,
    publicRepos: publicRepos,
    totalStars: totalStars,
    languages: languages,
    interests: interests,
    githubTopics: githubTopics,
    lookingFor: lookingFor,
    seekingSkills: seekingSkills,
    pitch: pitch,
    createdAt: createdAt,
    lastActiveAt: lastActiveAt,
    githubSyncedAt: githubSyncedAt,
    matchScore: matchScore,
    scoreBreakdown: scoreBreakdown,
    matchReasons: matchReasons,
  );

  // ── Parsing helpers ──────────────────────────────────────────────────────

  static String? _string(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .where((e) => e != null)
        .map((e) => e.toString())
        .toList(growable: false);
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) return null;
    return value.map((key, v) => MapEntry(key.toString(), v));
  }

  // ── Serialisation helpers ────────────────────────────────────────────────

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _cleanPitch(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null) return null;
    // users_pitch_len counts code points (char_length), not UTF-16 units.
    final runes = cleaned.runes;
    if (runes.length <= CollabConstants.pitchMaxLength) return cleaned;
    return String.fromCharCodes(runes.take(CollabConstants.pitchMaxLength));
  }

  static List<String> _cleanList(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) result.add(trimmed);
    }
    return result;
  }
}
