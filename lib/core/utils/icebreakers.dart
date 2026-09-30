import '../../domain/entities/user_entity.dart';
import '../constants/collab_constants.dart';

/// Conversation starters for an empty chat, built from both profiles.
///
/// Pure and deterministic (no I/O, no randomness) so it is unit-testable.
/// Suggestions are ordered by how personal they are: the other person's
/// pitch, a shared (or complementary) intent, skills they want that [me]
/// has, shared languages, shared interests, what they're here for — then
/// generic fallbacks, so there are always [count] unique suggestions.
List<String> generateIcebreakers({
  required UserEntity? me,
  required UserEntity other,
  int count = 3,
}) {
  final suggestions = <String>[];
  void add(String suggestion) {
    if (!suggestions.contains(suggestion)) suggestions.add(suggestion);
  }

  final myIntents = (me?.lookingFor ?? const <String>[]).toSet();
  final theirIntents = other.lookingFor.toSet();

  // 1. Their pitch.
  final pitch = other.pitch?.trim() ?? '';
  if (pitch.isNotEmpty) {
    add('Your pitch caught my eye — "${_shorten(pitch, 60)}". '
        "What's the next milestone?");
  }

  // 2. Shared or complementary intent.
  final intentOpener = _intentOpener(myIntents, theirIntents);
  if (intentOpener != null) add(intentOpener);

  // 3. A skill they're looking for that I have.
  final skillIHave = _firstShared(other.seekingSkills, me?.languages);
  if (skillIHave != null) {
    add("You're looking for $skillIHave skills — I write $skillIHave a lot. "
        'What are you building?');
  }

  // 4. Shared language.
  final sharedLanguage = _firstShared(other.languages, me?.languages);
  if (sharedLanguage != null) {
    add("Fellow $sharedLanguage dev! What's the coolest thing you've built "
        'with it?');
  }

  // 5. Shared interest.
  final sharedInterest = _firstShared(other.interests, me?.interests);
  if (sharedInterest != null) {
    add("Looks like we're both into $sharedInterest — what are you working "
        'on there?');
  }

  // 6. What they're here for, even if it isn't shared.
  if (intentOpener == null) {
    for (final key in other.lookingFor) {
      final intent = CollabConstants.intentFor(key);
      if (intent == null) continue;
      add("You're here for ${intent.label.toLowerCase()} — what would your "
          'ideal collaborator bring to the table?');
      break;
    }
  }

  // 7. Fallbacks.
  final name = _firstName(other);
  add('Hey $name! What are you building right now?');
  add("What's a project on your GitHub you're most proud of?");
  add('What tech are you excited to try next?');

  return suggestions.take(count).toList();
}

String? _intentOpener(Set<String> mine, Set<String> theirs) {
  if (mine.contains('mentee') && theirs.contains('mentor')) {
    return "I'm looking for a mentor — what do you wish you'd known earlier "
        'in your career?';
  }
  if (mine.contains('mentor') && theirs.contains('mentee')) {
    return "Happy to help you level up — what are you trying to get better "
        'at right now?';
  }
  if (mine.contains('cofounder') && theirs.contains('cofounder')) {
    return "We're both looking for a co-founder — what kind of company do "
        'you want to build?';
  }
  if (mine.contains('side_project') && theirs.contains('side_project')) {
    return 'What side project would you start this month if you had a '
        'partner?';
  }
  if (mine.contains('open_source') && theirs.contains('open_source')) {
    return 'Which open-source project would you love to contribute to '
        'together?';
  }
  if (mine.contains('hackathon') && theirs.contains('hackathon')) {
    return "Got a hackathon coming up? I'm in if you need a teammate.";
  }
  return null;
}

/// First entry of [theirs] that also appears in [mine] (case-insensitive),
/// using the spelling from [theirs].
String? _firstShared(List<String> theirs, List<String>? mine) {
  if (mine == null || mine.isEmpty) return null;
  final mineLower = mine.map((s) => s.trim().toLowerCase()).toSet();
  for (final value in theirs) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    if (mineLower.contains(trimmed.toLowerCase())) return trimmed;
  }
  return null;
}

String _firstName(UserEntity user) {
  final name = user.name?.trim() ?? '';
  if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
  return user.username.isNotEmpty ? user.username : 'there';
}

String _shorten(String text, int maxLength) {
  final singleLine = text.replaceAll(RegExp(r'\s+'), ' ');
  if (singleLine.length <= maxLength) return singleLine;
  return '${singleLine.substring(0, maxLength).trimRight()}…';
}
