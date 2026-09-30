import 'package:flutter/material.dart';

import '../../../../domain/entities/user_entity.dart';

// Text helpers shared by the Matches, Chats and chat screens. Every date is
// converted with `toLocal()` before it is shown.

/// The name to show for [user]: their name, else their username.
String displayNameOf(UserEntity user) {
  final name = user.name?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final username = user.username.trim();
  return username.isNotEmpty ? username : 'GitAlong dev';
}

/// The first word of [name] (for friendly copy like "Message Ana…").
String firstNameOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return name;
  return trimmed.split(RegExp(r'\s+')).first;
}

/// A one-line preview of a message: runs of whitespace (including
/// newlines) collapse to one space. Only for list previews; the chat itself
/// always shows the content verbatim.
String previewLine(String text) {
  final single = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return single.isEmpty ? text : single;
}

/// What the composer sends for [raw], or null when there is nothing to send.
///
/// Leading blank lines and trailing whitespace are dropped; everything else,
/// including the indentation of the first line, is kept verbatim so code
/// snippets survive (docs/API_AND_DATA_CONTRACT.md: never trim indentation).
String? normalizeOutgoingMessage(String raw) {
  if (raw.trim().isEmpty) return null;
  return raw.replaceFirst(RegExp(r'^(?:[ \t]*\r?\n)+'), '').trimRight();
}

/// Whether [text] looks like code, so it can be shown in monospace.
///
/// Deliberately conservative: fenced blocks, a single inline-code message,
/// shell prompts, or several lines with indentation / `;` `{` `}` endings.
bool looksLikeCode(String text) {
  if (text.contains('```')) return true;
  final trimmed = text.trim();
  if (trimmed.startsWith(r'$ ')) return true;
  if (trimmed.length > 2 && trimmed.startsWith('`') && trimmed.endsWith('`')) {
    return true;
  }
  final lines = text.split('\n');
  if (lines.length < 2) return false;
  var signals = 0;
  for (final line in lines) {
    if (line.startsWith('  ') || line.startsWith('\t')) signals++;
    final end = line.trimRight();
    if (end.endsWith(';') || end.endsWith('{') || end.endsWith('}')) {
      signals++;
    }
  }
  return signals >= 2;
}

/// Short relative time for list rows: "now", "5m", "3h", "2d", then a date
/// ("Jan 21", or "Jan 21, 2024" for another year).
String shortRelativeTime(BuildContext context, DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = time.toLocal();
  final diff = current.difference(local);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final l10n = MaterialLocalizations.of(context);
  return local.year == current.year
      ? l10n.formatShortMonthDay(local)
      : l10n.formatShortDate(local);
}

/// Spoken form of [shortRelativeTime], e.g. "5 minutes ago".
String longRelativeTime(BuildContext context, DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = time.toLocal();
  final diff = current.difference(local);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${_count(diff.inMinutes, 'minute')} ago';
  if (diff.inDays < 1) return '${_count(diff.inHours, 'hour')} ago';
  if (diff.inDays < 7) return '${_count(diff.inDays, 'day')} ago';
  return 'on ${MaterialLocalizations.of(context).formatMediumDate(local)}';
}

String _count(int value, String unit) => value == 1 ? '1 $unit' : '$value ${unit}s';

/// The local clock time of [time] in the device's 12/24-hour format.
String clockTime(BuildContext context, DateTime time) {
  final local = time.toLocal();
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Label of a day separator: "Today", "Yesterday", "Tue, Jan 21", or the
/// full date for another year.
String dayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = day.toLocal();
  // Whole days between calendar dates, immune to DST (UTC has no DST).
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  final l10n = MaterialLocalizations.of(context);
  return local.year == current.year
      ? l10n.formatMediumDate(local)
      : l10n.formatFullDate(local);
}

/// Whether [a] and [b] fall on the same local calendar day.
bool isSameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
