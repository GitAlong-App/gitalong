import 'package:equatable/equatable.dart';

/// User entity
class UserEntity extends Equatable {
  final String id;
  final String username;

  /// Only present for the signed-in user's own profile; other profiles come
  /// from `public_profiles`, which never exposes email (empty string then).
  final String email;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final String? location;
  final String? company;
  final String? websiteUrl;
  final String? githubUrl;
  final int followers;
  final int following;
  final int publicRepos;
  final int totalStars;
  final List<String> languages;
  final List<String> interests;
  final List<String> githubTopics;

  /// Collaboration intents (`cofounder`, `side_project`, ...).
  final List<String> lookingFor;

  /// Skills / languages this user wants in a collaborator.
  final List<String> seekingSkills;

  /// "What I'm building" — at most 280 characters.
  final String? pitch;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  /// When the backend last synced GitHub stats (own profile only).
  final DateTime? githubSyncedAt;

  /// 0–100, only set on recommendations.
  final double? matchScore;
  final Map<String, dynamic>? scoreBreakdown;

  /// Human-readable reasons for a recommendation.
  final List<String> matchReasons;

  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.name,
    this.bio,
    this.avatarUrl,
    this.location,
    this.company,
    this.websiteUrl,
    this.githubUrl,
    this.followers = 0,
    this.following = 0,
    this.publicRepos = 0,
    this.totalStars = 0,
    this.languages = const [],
    this.interests = const [],
    this.githubTopics = const [],
    this.lookingFor = const [],
    this.seekingSkills = const [],
    this.pitch,
    required this.createdAt,
    this.lastActiveAt,
    this.githubSyncedAt,
    this.matchScore,
    this.scoreBreakdown,
    this.matchReasons = const [],
  });

  @override
  List<Object?> get props => [
    id,
    username,
    email,
    name,
    bio,
    avatarUrl,
    location,
    company,
    websiteUrl,
    githubUrl,
    followers,
    following,
    publicRepos,
    totalStars,
    languages,
    interests,
    githubTopics,
    lookingFor,
    seekingSkills,
    pitch,
    createdAt,
    lastActiveAt,
    githubSyncedAt,
    matchScore,
    scoreBreakdown,
    matchReasons,
  ];

  /// Copy with method.
  ///
  /// Passing `null` keeps the current value, so this cannot clear a field —
  /// use [withEditableFields] for profile edits.
  UserEntity copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? bio,
    String? avatarUrl,
    String? location,
    String? company,
    String? websiteUrl,
    String? githubUrl,
    int? followers,
    int? following,
    int? publicRepos,
    int? totalStars,
    List<String>? languages,
    List<String>? interests,
    List<String>? githubTopics,
    List<String>? lookingFor,
    List<String>? seekingSkills,
    String? pitch,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? githubSyncedAt,
    double? matchScore,
    Map<String, dynamic>? scoreBreakdown,
    List<String>? matchReasons,
  }) {
    return UserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      company: company ?? this.company,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      publicRepos: publicRepos ?? this.publicRepos,
      totalStars: totalStars ?? this.totalStars,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      githubTopics: githubTopics ?? this.githubTopics,
      lookingFor: lookingFor ?? this.lookingFor,
      seekingSkills: seekingSkills ?? this.seekingSkills,
      pitch: pitch ?? this.pitch,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      githubSyncedAt: githubSyncedAt ?? this.githubSyncedAt,
      matchScore: matchScore ?? this.matchScore,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      matchReasons: matchReasons ?? this.matchReasons,
    );
  }

  /// Returns a copy with every user-editable profile field replaced.
  ///
  /// Unlike [copyWith], `null` here really means "clear this field", so the
  /// edit and setup screens can remove a bio, location, website or pitch.
  UserEntity withEditableFields({
    required String? name,
    required String? bio,
    required String? location,
    required String? company,
    required String? websiteUrl,
    required List<String> languages,
    required List<String> interests,
    required List<String> lookingFor,
    required List<String> seekingSkills,
    required String? pitch,
  }) {
    return UserEntity(
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
  }
}
