import 'package:logger/logger.dart';
import 'package:trovara/core/import/adapters/storypad_adapter.dart';
import 'package:trovara/core/services/notes/_storypad/storypad_value_parsers.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Converts a Storypad backup JSON (which uses `tables: { ... }` schema) into
/// Trovara's import schema (`{folders: [...], notes: [...]}`). This lets the
/// regular `importAllFromJson` pipeline handle both Trovara-native and
/// Storypad backups.
class StorypadConverter {
  final Logger _logger;
  final StorypadAdapter _adapter = StorypadAdapter();

  StorypadConverter({Logger? logger}) : _logger = logger ?? Logger();

  /// True if the JSON looks like a Storypad backup. Delegates to the existing
  /// `StorypadAdapter.canHandle` so detection logic stays in one place.
  bool canHandle(Map<String, dynamic> json) => _adapter.canHandle(json);

  /// Convert a Storypad backup JSON into Trovara import schema.
  ///
  /// Heuristic: scans for a folder/category/notebook table for folders, scores
  /// remaining tables to identify the notes table, and best-effort maps the
  /// columns. Skips rows that fail to convert and logs them.
  Map<String, dynamic> convert(
    Map<String, dynamic> storypadJson, {
    required String source,
    required bool verbose,
  }) {
    final tablesRaw = storypadJson['tables'];
    final tables = _normalizeStorypadTables(tablesRaw, source: source, verbose: verbose);

    if (tables.isEmpty) {
      _logger.w('Storypad conversion (source=$source): no tables found');
    }

    if (verbose) {
      final tableNames = tables.keys.toList()..sort();
      _logger.d('Storypad conversion (source=$source): tables=$tableNames');
      for (final name in tableNames) {
        _logger.d('Storypad conversion (source=$source): table=$name rows=${tables[name]!.length}');
      }
    }

    final folderRowsById = <String, Map<String, dynamic>>{};
    final folderIdByName = <String, String>{};
    final foldersOut = <Map<String, dynamic>>[];

    final nowIso = DateTime.now().toIso8601String();
    foldersOut.add({
      'id': 0,
      'folderId': 'default',
      'name': 'Default',
      'description': null,
      'color': null,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'isDefault': true,
      'noteCount': 0,
    });

    final folderTableCandidates = _findTableCandidates(tables, const ['folder', 'category', 'notebook', 'collection']);
    for (final tableName in folderTableCandidates) {
      final rows = tables[tableName] ?? const <Map<String, dynamic>>[];
      for (final row in rows) {
        final rawId = row['id'] ?? row['folder_id'] ?? row['folderId'] ?? row['category_id'] ?? row['categoryId'];
        final id = StorypadValueParsers.stringify(rawId);
        if (id.isEmpty) continue;

        final name = StorypadValueParsers.stringify(
          row['name'] ??
              row['title'] ??
              row['label'] ??
              row['folder_name'] ??
              row['folderName'] ??
              row['category_name'] ??
              row['categoryName'],
        );
        final folderId = 'storypad_folder_$id';

        folderRowsById[id] = row;
        if (name.isNotEmpty) {
          folderIdByName[name.toLowerCase()] = folderId;
        }

        final createdAt = StorypadValueParsers.parseDate(row['created_at'] ?? row['createdAt']) ?? DateTime.now();
        final updatedAt = StorypadValueParsers.parseDate(row['updated_at'] ?? row['updatedAt']) ?? createdAt;

        final description = StorypadValueParsers.stringify(row['description'] ?? row['desc']);
        final color = StorypadValueParsers.stringify(row['color']);
        foldersOut.add({
          'id': 0,
          'folderId': folderId,
          'name': name.isNotEmpty ? name : 'Storypad $id',
          'description': description.isEmpty ? null : description,
          'color': color.isEmpty ? null : color,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'isDefault': false,
          'noteCount': 0,
        });
      }
    }

    final notesTable = _pickBestNotesTable(tables);
    final noteRows = notesTable == null
        ? const <Map<String, dynamic>>[]
        : (tables[notesTable] ?? const <Map<String, dynamic>>[]);
    if (notesTable == null) {
      _logger.w('Storypad conversion (source=$source): could not identify notes table; importing 0 notes');
    } else {
      _logger.i('Storypad conversion (source=$source): notesTable=$notesTable rows=${noteRows.length}');
      if (verbose && noteRows.isNotEmpty) {
        final sampleKeys = noteRows.first.keys.toList()..sort();
        _logger.d('Storypad conversion (source=$source): notesTable sample keys=$sampleKeys');
      }
    }

    final notesOut = <Map<String, dynamic>>[];
    for (int i = 0; i < noteRows.length; i++) {
      final row = noteRows[i];
      try {
        final title = StorypadValueParsers.stringify(row['title'] ?? row['name'] ?? row['subject']).trim();
        final rawContent =
            row['content'] ?? row['body'] ?? row['text'] ?? row['delta'] ?? row['content_json'] ?? row['contentJson'];
        final contentJson = StorypadValueParsers.ensureQuillContentJson(rawContent);

        final createdAt =
            StorypadValueParsers.parseDate(row['created_at'] ?? row['createdAt'] ?? row['created']) ?? DateTime.now();
        final updatedAt =
            StorypadValueParsers.parseDate(row['updated_at'] ?? row['updatedAt'] ?? row['updated']) ?? createdAt;
        final deletedAt = StorypadValueParsers.parseDate(row['deleted_at'] ?? row['deletedAt']);

        final isFavorite = StorypadValueParsers.parseBool(row['is_favorite'] ?? row['isFavorite'] ?? row['favorite']);
        final isArchived = StorypadValueParsers.parseBool(row['is_archived'] ?? row['isArchived'] ?? row['archived']);
        final isDeleted =
            deletedAt != null ||
            StorypadValueParsers.parseBool(row['is_deleted'] ?? row['isDeleted'] ?? row['deleted']);

        final folderId = _resolveFolderIdForNote(row, folderRowsById: folderRowsById, folderIdByName: folderIdByName);

        notesOut.add({
          'id': 0,
          'title': title.isNotEmpty ? title : 'Imported note ${i + 1}',
          'contentJson': contentJson,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'isFavorite': isFavorite,
          'isArchived': isArchived,
          'isDeleted': isDeleted,
          'deletedAt': deletedAt?.toIso8601String() ?? '',
          'driveFileId': null,
          'userId': null,
          'folderId': folderId,
          'customTagIds': const <int>[],
          'moodTags': const <String>[],
          'activityTags': const <String>[],
          'timeTags': const <String>[],
          'personalGrowthTags': const <String>[],
        });
      } catch (e, st) {
        _logger.e('Storypad note conversion failed (source=$source) index=$i error=$e', error: e, stackTrace: st);
      }
    }

    _logger.i('Storypad conversion (source=$source): produced folders=${foldersOut.length} notes=${notesOut.length}');

    return {'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'folders': foldersOut, 'notes': notesOut};
  }

  Map<String, List<Map<String, dynamic>>> _normalizeStorypadTables(
    dynamic tablesRaw, {
    required String source,
    required bool verbose,
  }) {
    final result = <String, List<Map<String, dynamic>>>{};

    if (tablesRaw is Map) {
      for (final entry in tablesRaw.entries) {
        final name = StorypadValueParsers.stringify(entry.key);
        final rows = _coerceRows(entry.value);
        if (name.isNotEmpty && rows.isNotEmpty) {
          result[name] = rows;
        }
      }
      return result;
    }

    if (tablesRaw is List) {
      for (final t in tablesRaw) {
        if (t is! Map) continue;
        final map = Map<String, dynamic>.from(t);
        final name = StorypadValueParsers.stringify(
          map['name'] ?? map['table'] ?? map['table_name'] ?? map['tableName'],
        );
        final rowsRaw = map['rows'] ?? map['data'] ?? map['items'];
        final rows = _coerceRows(rowsRaw);
        if (name.isNotEmpty && rows.isNotEmpty) {
          result[name] = rows;
        }
      }
      return result;
    }

    if (tablesRaw != null) {
      _logger.w('Storypad conversion (source=$source): unsupported tables type=${tablesRaw.runtimeType}');
    }
    return result;
  }

  List<Map<String, dynamic>> _coerceRows(dynamic rowsRaw) {
    if (rowsRaw is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final r in rowsRaw) {
      if (r is Map) {
        out.add(Map<String, dynamic>.from(r));
      }
    }
    return out;
  }

  List<String> _findTableCandidates(Map<String, List<Map<String, dynamic>>> tables, List<String> keywords) {
    final names = tables.keys.toList()..sort();
    final lowerKeywords = keywords.map((k) => k.toLowerCase()).toList();
    return names.where((name) {
      final lower = name.toLowerCase();
      return lowerKeywords.any(lower.contains);
    }).toList();
  }

  String? _pickBestNotesTable(Map<String, List<Map<String, dynamic>>> tables) {
    String? best;
    int bestScore = -1;

    for (final entry in tables.entries) {
      final name = entry.key;
      final rows = entry.value;
      if (rows.isEmpty) continue;

      final keys = rows.first.keys.map((k) => k.toLowerCase()).toSet();

      int score = 0;
      final lowerName = name.toLowerCase();
      if (lowerName.contains('note')) score += 5;
      if (lowerName.contains('notes')) score += 5;
      if (lowerName.contains('document')) score += 3;
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

    if (bestScore < 4) return null;
    return best;
  }

  String _resolveFolderIdForNote(
    Map<String, dynamic> row, {
    required Map<String, Map<String, dynamic>> folderRowsById,
    required Map<String, String> folderIdByName,
  }) {
    final rawFolderId =
        row['folder_id'] ??
        row['folderId'] ??
        row['category_id'] ??
        row['categoryId'] ??
        row['notebook_id'] ??
        row['notebookId'];
    final folderIdValue = StorypadValueParsers.stringify(rawFolderId);
    if (folderIdValue.isNotEmpty && folderRowsById.containsKey(folderIdValue)) {
      return 'storypad_folder_$folderIdValue';
    }

    final folderName = StorypadValueParsers.stringify(
      row['folder_name'] ??
          row['folderName'] ??
          row['category_name'] ??
          row['categoryName'] ??
          row['notebook_name'] ??
          row['notebookName'],
    );
    if (folderName.isNotEmpty) {
      final mapped = folderIdByName[folderName.toLowerCase()];
      if (mapped != null) return mapped;
      return 'storypad_${StorypadValueParsers.slugify(folderName)}';
    }

    return 'default';
  }
}
