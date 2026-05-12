import 'dart:convert';

import 'package:trovara/core/import/import_adapter.dart';
import 'package:uuid/uuid.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Centralizes deterministic syncId generation so legacy backups, fresh imports,
/// and merge operations all key notes the same way across devices.
class NoteSyncId {
  const NoteSyncId._();

  /// Deterministic UUID v5 from a note's title + createdAt timestamp.
  ///
  /// Used to assign stable identities to legacy backups that were created
  /// before the [Note.syncId] field existed. NOT cryptographically strong —
  /// just a stable fingerprint.
  static String deterministic(String title, DateTime createdAt) {
    const ns = Namespace.url;
    final name = '${title.trim()}|${createdAt.toUtc().toIso8601String()}';
    return const Uuid().v5(ns.value, name);
  }

  /// Returns the stable syncId for a note from its JSON. Uses [syncId] if
  /// present and non-empty; otherwise falls back to a deterministic id from
  /// title + createdAt.
  static String fromNoteJson(Map<String, dynamic> noteJson) {
    final raw = noteJson['syncId'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    final title = noteJson['title'] as String? ?? '';
    final createdAt = parseCreatedAtStable(noteJson);
    return deterministic(title, createdAt);
  }

  /// Parses [createdAt] from a note map for deterministic syncId generation.
  /// Uses a fixed epoch when missing or invalid so the same note yields the
  /// same syncId across devices/runs.
  static DateTime parseCreatedAtStable(Map<String, dynamic> note) {
    final raw = note['createdAt'] as String? ?? '';
    return DateTime.tryParse(raw) ?? DateTime.utc(1970, 1, 1);
  }

  /// When adapter imports omit timestamps (common for plain Markdown), we still
  /// need a deterministic createdAt to build a stable syncId. Must never depend
  /// on wall-clock time.
  static DateTime syntheticForImport(ImportedNote imported) {
    final seed = '${imported.title.trim()}\n${imported.markdownContent}';
    final seconds = _stableHash32(seed);
    return DateTime.utc(1970, 1, 1).add(Duration(seconds: seconds));
  }

  /// Simple deterministic non-crypto 32-bit hash (FNV-1a).
  static int _stableHash32(String input) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
