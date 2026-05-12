import 'dart:convert';

/// Internal helper for [StorypadConverter]. Do not import from outside `lib/core/services/notes/_storypad/`.
///
/// Lenient value coercion for Storypad backups, which use mixed types and
/// inconsistent column naming across versions.
class StorypadValueParsers {
  const StorypadValueParsers._();

  static bool parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  /// Parse a date from a String, num (epoch s/ms/us heuristic), or DateTime.
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is num) {
      final n = value.toInt();
      // Heuristic: seconds vs milliseconds vs microseconds.
      if (n > 100000000000000) {
        return DateTime.fromMicrosecondsSinceEpoch(n);
      }
      if (n > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
      if (n > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
      return null;
    }

    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Wrap arbitrary content in a valid Quill Delta JSON envelope.
  /// Returns the input unchanged if it's already valid JSON.
  static String ensureQuillContentJson(dynamic content) {
    final raw = content == null ? '' : content.toString();
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return jsonEncode({
        'ops': [
          {'insert': '\n'},
        ],
      });
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        jsonDecode(trimmed);
        return trimmed;
      } catch (_) {
        // Fall through to wrap as plain text.
      }
    }

    return jsonEncode({
      'ops': [
        {'insert': '$trimmed\n'},
      ],
    });
  }

  static String slugify(String input) {
    final lower = input.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  static String stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
