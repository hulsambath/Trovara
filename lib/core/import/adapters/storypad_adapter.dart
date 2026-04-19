import 'dart:convert';

import 'package:trovara/core/import/converters/quill_to_markdown.dart';
import 'package:trovara/core/import/import_adapter.dart';

/// Imports notes from a Storypad JSON backup.
///
/// Storypad exports its data as a JSON file with a `tables` key containing
/// key–value maps (or lists) of table rows.  This adapter is a refactored
/// extraction of the heuristic parsing logic that previously lived directly
/// inside [NoteService].
///
/// The adapter produces [ImportedNote] objects with Markdown content so the
/// normaliser pipeline can convert them to Quill Delta via
/// [MarkdownToQuillConverter].
///
/// ## Detection heuristic
/// A JSON map is treated as a Storypad backup when:
/// - It contains a `tables` key
/// - It does NOT contain `notes` or `folders` keys (those are Trovara backups)
/// - It has either a `meta_data` / `metaData` key or a `version` key
///
/// ## Folder detection
/// The adapter looks for tables whose name contains `folder`, `category`,
/// `notebook`, or `collection` and maps them to Trovara folder IDs of the
/// form `storypad_folder_<id>`.
class StorypadAdapter implements NoteImportAdapter {
  @override
  String get sourceName => 'storypad';

  @override
  bool canHandle(dynamic rawInput) {
    if (rawInput is! Map<String, dynamic>) return false;
    if (rawInput.containsKey('notes') || rawInput.containsKey('folders')) return false;
    if (!rawInput.containsKey('tables')) return false;
    return rawInput.containsKey('meta_data') || rawInput.containsKey('metaData') || rawInput.containsKey('version');
  }

  @override
  Future<List<ImportedNote>> parse(dynamic rawInput) async {
    if (rawInput is! Map<String, dynamic>) return [];

    final tables = _normaliseTables(rawInput['tables']);
    if (tables.isEmpty) return [];

    // ── Folder map ─────────────────────────────────────────────────────────
    final folderRowsById = <String, Map<String, dynamic>>{};
    final folderIdByName = <String, String>{};
    final folderCandidates = _findTableCandidates(tables, const ['folder', 'category', 'notebook', 'collection']);

    for (final tableName in folderCandidates) {
      for (final row in tables[tableName] ?? <Map<String, dynamic>>[]) {
        final rawId = row['id'] ?? row['folder_id'] ?? row['folderId'] ?? row['category_id'] ?? row['categoryId'];
        final id = _str(rawId);
        if (id.isEmpty) continue;

        final name = _str(
          row['name'] ??
              row['title'] ??
              row['label'] ??
              row['folder_name'] ??
              row['folderName'] ??
              row['category_name'] ??
              row['categoryName'],
        );
        folderRowsById[id] = row;
        if (name.isNotEmpty) folderIdByName[name.toLowerCase()] = 'storypad_folder_$id';
      }
    }

    // ── Notes table ────────────────────────────────────────────────────────
    final notesTable = _pickBestNotesTable(tables);
    if (notesTable == null) return [];

    final noteRows = tables[notesTable] ?? [];
    final importedNotes = <ImportedNote>[];

    for (int i = 0; i < noteRows.length; i++) {
      final row = noteRows[i];
      try {
        importedNotes.add(_rowToImportedNote(row, i, folderRowsById: folderRowsById, folderIdByName: folderIdByName));
      } catch (_) {
        // Skip malformed rows
      }
    }

    return importedNotes;
  }

  // ── Row conversion ─────────────────────────────────────────────────────────

  ImportedNote _rowToImportedNote(
    Map<String, dynamic> row,
    int index, {
    required Map<String, Map<String, dynamic>> folderRowsById,
    required Map<String, String> folderIdByName,
  }) {
    final title = _str(row['title'] ?? row['name'] ?? row['subject']).trim();
    final rawContent =
        row['content'] ?? row['body'] ?? row['text'] ?? row['delta'] ?? row['content_json'] ?? row['contentJson'];

    // Convert content to Markdown (our adapter boundary format).
    // Storypad content may already be Quill Delta JSON — convert it.
    final markdownContent = _contentToMarkdown(rawContent);

    final createdAt = _date(row['created_at'] ?? row['createdAt'] ?? row['created']);
    final updatedAt = _date(row['updated_at'] ?? row['updatedAt'] ?? row['updated']);

    final folderId = _resolveFolderId(row, folderRowsById: folderRowsById, folderIdByName: folderIdByName);

    return ImportedNote(
      title: title.isNotEmpty ? title : 'Imported note ${index + 1}',
      markdownContent: markdownContent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      folderId: folderId == 'default' ? null : folderId,
      rawMetadata: Map<String, dynamic>.from(row),
    );
  }

  /// Convert raw Storypad content to Markdown.
  ///
  /// Storypad may store content as:
  /// - Quill Delta JSON (object or array) → convert via QuillToMarkdownConverter
  /// - Plain text string → return as-is
  String _contentToMarkdown(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';

    // Check if it looks like Quill Delta JSON
    if (s.startsWith('{') || s.startsWith('[')) {
      try {
        jsonDecode(s); // validate JSON
        return QuillToMarkdownConverter.convert(s);
      } catch (_) {
        // Not valid JSON — treat as plain text
      }
    }

    return s;
  }

  // ── Table helpers (ported from NoteService) ────────────────────────────────

  Map<String, List<Map<String, dynamic>>> _normaliseTables(dynamic tablesRaw) {
    final result = <String, List<Map<String, dynamic>>>{};

    if (tablesRaw is Map) {
      for (final entry in tablesRaw.entries) {
        final name = _str(entry.key);
        final rows = _coerceRows(entry.value);
        if (name.isNotEmpty && rows.isNotEmpty) result[name] = rows;
      }
      return result;
    }

    if (tablesRaw is List) {
      for (final t in tablesRaw) {
        if (t is! Map) continue;
        final map = Map<String, dynamic>.from(t);
        final name = _str(map['name'] ?? map['table'] ?? map['table_name'] ?? map['tableName']);
        final rows = _coerceRows(map['rows'] ?? map['data'] ?? map['items']);
        if (name.isNotEmpty && rows.isNotEmpty) result[name] = rows;
      }
      return result;
    }

    return result;
  }

  List<Map<String, dynamic>> _coerceRows(dynamic rowsRaw) {
    if (rowsRaw is! List) return const [];
    return rowsRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  List<String> _findTableCandidates(Map<String, List<Map<String, dynamic>>> tables, List<String> keywords) {
    final lower = keywords.map((k) => k.toLowerCase()).toList();
    return tables.keys.where((name) {
      final n = name.toLowerCase();
      return lower.any(n.contains);
    }).toList();
  }

  String? _pickBestNotesTable(Map<String, List<Map<String, dynamic>>> tables) {
    String? best;
    int bestScore = -1;

    for (final entry in tables.entries) {
      if (entry.value.isEmpty) continue;
      final name = entry.key;
      final keys = entry.value.first.keys.map((k) => k.toLowerCase()).toSet();
      int score = 0;
      final lower = name.toLowerCase();
      if (lower.contains('note')) score += 5;
      if (lower.contains('notes')) score += 5;
      if (lower.contains('document')) score += 3;
      if (keys.contains('title') || keys.contains('name') || keys.contains('subject')) score += 3;
      if (keys.contains('content') || keys.contains('body') || keys.contains('text') || keys.contains('delta')) {
        score += 4;
      }
      if (keys.contains('created_at') || keys.contains('createdat')) score += 1;
      if (keys.contains('updated_at') || keys.contains('updatedat')) score += 1;
      if (keys.contains('password') || keys.contains('token')) score -= 5;

      if (score > bestScore) {
        bestScore = score;
        best = name;
      }
    }
    return bestScore >= 4 ? best : null;
  }

  String _resolveFolderId(
    Map<String, dynamic> row, {
    required Map<String, Map<String, dynamic>> folderRowsById,
    required Map<String, String> folderIdByName,
  }) {
    final rawId =
        row['folder_id'] ??
        row['folderId'] ??
        row['category_id'] ??
        row['categoryId'] ??
        row['notebook_id'] ??
        row['notebookId'];
    final id = _str(rawId);
    if (id.isNotEmpty && folderRowsById.containsKey(id)) return 'storypad_folder_$id';

    final folderName = _str(
      row['folder_name'] ??
          row['folderName'] ??
          row['category_name'] ??
          row['categoryName'] ??
          row['notebook_name'] ??
          row['notebookName'],
    );
    if (folderName.isNotEmpty) {
      return folderIdByName[folderName.toLowerCase()] ?? 'storypad_${_slugify(folderName)}';
    }

    return 'default';
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  String _str(dynamic v) => v == null ? '' : v.toString();

  DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) {
      final n = v.toInt();
      if (n > 100000000000000) return DateTime.fromMicrosecondsSinceEpoch(n);
      if (n > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(n);
      if (n > 1000000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      return null;
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : DateTime.tryParse(s);
  }

  String _slugify(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
