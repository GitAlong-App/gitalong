/// Collaboration vocabulary shared by every screen.
///
/// Keys must stay in sync with docs/API_AND_DATA_CONTRACT.md and the
/// `users_looking_for_valid` / `reports.reason` CHECK constraints in
/// supabase/migrations — the database rejects anything else.
class CollabIntent {
  /// Value stored in `users.looking_for`.
  final String key;

  /// Human-readable label shown in the UI.
  final String label;

  /// Short emoji shown next to the label.
  final String emoji;

  const CollabIntent(this.key, this.label, this.emoji);

  /// Label with its emoji, e.g. "🚀 Co-founder".
  String get display => '$emoji $label';
}

/// A reason a user can pick when reporting someone.
class ReportReason {
  /// Value stored in `reports.reason`.
  final String key;

  /// Human-readable label shown in the UI.
  final String label;

  const ReportReason(this.key, this.label);
}

class CollabConstants {
  CollabConstants._();

  /// Max length of `users.pitch` (enforced by a CHECK constraint).
  static const int pitchMaxLength = 280;

  /// Max length of `reports.details` (enforced by a CHECK constraint).
  static const int reportDetailsMaxLength = 1000;

  // ── Intents (`looking_for`) ───────────────────────────────────────────────

  static const List<CollabIntent> intents = [
    CollabIntent('cofounder', 'Co-founder', '🚀'),
    CollabIntent('side_project', 'Side-project partner', '🛠️'),
    CollabIntent('open_source', 'Open-source collaborators', '🌍'),
    CollabIntent('hackathon', 'Hackathon teammates', '⚡'),
    CollabIntent('mentor', 'I want to mentor', '🧭'),
    CollabIntent('mentee', "I'm looking for a mentor", '🌱'),
  ];

  /// The intent for [key], or null when the key is unknown.
  static CollabIntent? intentFor(String key) {
    for (final intent in intents) {
      if (intent.key == key) return intent;
    }
    return null;
  }

  /// UI label for [key]; falls back to the raw key for unknown values.
  static String intentLabel(String key) => intentFor(key)?.label ?? key;

  /// Label with emoji for [key]; falls back to the raw key.
  static String intentDisplay(String key) => intentFor(key)?.display ?? key;

  /// Whether [key] is accepted by the database CHECK constraint.
  static bool isValidIntent(String key) => intentFor(key) != null;

  // ── Interests ─────────────────────────────────────────────────────────────

  static const List<String> interests = [
    'Open Source',
    'AI / ML',
    'Web Dev',
    'Mobile Dev',
    'Backend',
    'DevOps',
    'Data Science',
    'Game Dev',
    'Security',
    'Cloud',
    'Blockchain',
    'IoT',
    'UI / UX',
    'Embedded Systems',
    'AR / VR',
  ];

  // ── Languages (also used for `seeking_skills`) ────────────────────────────

  static const List<String> languages = [
    'Dart',
    'Python',
    'JavaScript',
    'TypeScript',
    'Rust',
    'Go',
    'Java',
    'Kotlin',
    'Swift',
    'C++',
    'C#',
    'Ruby',
    'PHP',
    'Scala',
    'Elixir',
    'Haskell',
    'Lua',
    'R',
    'Shell',
    'SQL',
  ];

  /// Returns the standard spelling of [language] when it matches an entry of
  /// [languages] case-insensitively (e.g. "typescript" → "TypeScript"),
  /// otherwise the trimmed input.
  static String canonicalLanguage(String language) {
    final trimmed = language.trim();
    final lower = trimmed.toLowerCase();
    for (final standard in languages) {
      if (standard.toLowerCase() == lower) return standard;
    }
    return trimmed;
  }

  /// The standard [languages] followed by any [extra] languages (e.g. the
  /// ones detected on GitHub) that are not already in the list, so
  /// pre-filled values are always visible and deselectable.
  static List<String> languageOptions(Iterable<String> extra) {
    final options = List<String>.of(languages);
    final seen = languages.map((l) => l.toLowerCase()).toSet();
    for (final language in extra) {
      final canonical = canonicalLanguage(language);
      if (canonical.isEmpty) continue;
      if (seen.add(canonical.toLowerCase())) options.add(canonical);
    }
    return options;
  }

  // ── Safety ────────────────────────────────────────────────────────────────

  static const List<ReportReason> reportReasons = [
    ReportReason('spam', 'Spam'),
    ReportReason('harassment', 'Harassment'),
    ReportReason('inappropriate', 'Inappropriate content'),
    ReportReason('fake_profile', 'Fake profile'),
    ReportReason('other', 'Other'),
  ];

  /// Whether [key] is accepted by the `reports.reason` CHECK constraint.
  static bool isValidReportReason(String key) =>
      reportReasons.any((reason) => reason.key == key);
}
