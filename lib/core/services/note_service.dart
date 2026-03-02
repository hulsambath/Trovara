import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';

/// Service layer for note operations.
///
/// Follows Single Responsibility Principle - coordinates between repositories
/// and encapsulates business rules (soft-delete, folder counts, sync merge).
///
/// Follows Dependency Inversion Principle - depends on abstractions
/// ([INoteRepository], [IFolderRepository]).
///
/// Also handles Google Drive trash synchronization to keep local state
/// in sync with Google Drive trash operations.
class NoteService {
  final INoteRepository _noteRepository;
  final IFolderRepository _folderRepository;
  final GoogleDriveService? _driveService;
  final EmbeddingService? _embeddingService;
  final Logger _logger = Logger();

  NoteService({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    GoogleDriveService? driveService,
    EmbeddingService? embeddingService,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _driveService = driveService,
       _embeddingService = embeddingService;

  /// Initialize both repositories
  Future<void> initialize() async {
    await _noteRepository.initialize();
    await _folderRepository.initialize();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Export / Import / Sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Export notes and folders to a JSON map for Drive backup.
  ///
  /// Includes:
  /// - All active notes
  /// - Soft-deleted notes (in Recently Deleted, not permanently deleted)
  ///
  /// Excludes:
  /// - Permanently deleted notes (not in local DB)
  ///
  /// This ensures permanently deleted notes stay deleted after sync.
  Map<String, dynamic> exportAllToJson() {
    // Use getAllNotes which includes soft-deleted but NOT permanently deleted
    // Permanently deleted notes are NOT in the DB at all
    final notes = _noteRepository.getAllNotes().map((n) => n.toJson()).toList();
    final folders = _folderRepository.getAllFolders().map((f) => f.toJson()).toList();
    return {'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'notes': notes, 'folders': folders};
  }

  /// Import notes and folders from a JSON map. This performs an upsert.
  Future<void> importAllFromJson(Map<String, dynamic> json, {String source = 'unknown', bool verbose = false}) async {
    Map<String, dynamic> workingJson = json;

    // Storypad exports don't match Trovara's {folders, notes} schema.
    // Detect and convert them into Trovara import format.
    if (_looksLikeStorypadBackup(workingJson)) {
      try {
        _logger.i('Storypad backup detected (source=$source). Converting to Trovara import schema...');
        workingJson = _convertStorypadBackupToTrovaraJson(workingJson, source: source, verbose: verbose);
      } catch (e, st) {
        _logger.e('Storypad conversion failed (source=$source): $e', error: e, stackTrace: st);
        // Fall through to normal import so we still get the usual diagnostics.
      }
    }

    final stopwatch = Stopwatch()..start();

    final keys = workingJson.keys.toList()..sort();
    final version = workingJson['version'];
    final exportedAt = workingJson['exportedAt'];

    final foldersRaw = workingJson['folders'];
    final notesRaw = workingJson['notes'];

    final folders = (foldersRaw is List) ? foldersRaw : const <dynamic>[];
    final notes = (notesRaw is List) ? notesRaw : const <dynamic>[];

    _logger.i(
      'Import start (source=$source, verbose=$verbose) '
      'keys=$keys version=$version exportedAt=$exportedAt '
      'folders=${folders.length} notes=${notes.length}',
    );

    if (foldersRaw != null && foldersRaw is! List) {
      _logger.w('Import warning (source=$source): "folders" is not a List (type=${foldersRaw.runtimeType})');
    }
    if (notesRaw != null && notesRaw is! List) {
      _logger.w('Import warning (source=$source): "notes" is not a List (type=${notesRaw.runtimeType})');
    }

    int foldersCreated = 0;
    int foldersUpdated = 0;
    int folderErrors = 0;

    for (int i = 0; i < folders.length; i++) {
      try {
        final f = folders[i];
        final importFolder = Folder.fromJson(Map<String, dynamic>.from(f as Map));
        final existing = _folderRepository.getFolderById(importFolder.folderId);

        if (existing == null) {
          await createFolderWithTimestamps(
            folderId: importFolder.folderId,
            name: importFolder.name,
            description: importFolder.description,
            color: importFolder.color,
            createdAt: importFolder.createdAt,
            updatedAt: importFolder.updatedAt,
            isDefault: importFolder.isDefault,
            noteCount: importFolder.noteCount,
          );
          foldersCreated++;
          if (verbose) {
            _logger.d(
              'Import folder created (source=$source): folderId=${importFolder.folderId} name=${importFolder.name}',
            );
          }
        } else {
          existing
            ..name = importFolder.name
            ..description = importFolder.description
            ..color = importFolder.color
            ..isDefault = importFolder.isDefault
            ..noteCount = importFolder.noteCount
            ..updatedAt = importFolder.updatedAt;
          await _folderRepository.updateFolder(existing);
          foldersUpdated++;
          if (verbose) {
            _logger.d(
              'Import folder updated (source=$source): folderId=${importFolder.folderId} name=${importFolder.name}',
            );
          }
        }
      } catch (e, st) {
        folderErrors++;
        _logger.e('Import folder failed (source=$source) index=$i error=$e', error: e, stackTrace: st);
      }
    }

    int notesCreated = 0;
    int notesUpdated = 0;
    int notesSkippedPermanentlyDeleted = 0;
    int noteErrors = 0;

    for (int i = 0; i < notes.length; i++) {
      try {
        final n = notes[i];
        final importNote = Note.fromJson(Map<String, dynamic>.from(n as Map));

        if (importNote.id != 0) {
          final existing = _noteRepository.getNoteById(importNote.id);
          if (existing != null) {
            // CRITICAL: Don't re-import permanently deleted notes.
            // Only update if it still exists locally.
            await _noteRepository.updateNote(importNote);
            notesUpdated++;
            if (verbose) {
              _logger.d(
                'Import note updated (source=$source): '
                'id=${importNote.id} title=${importNote.title} updatedAt=${importNote.updatedAt.toIso8601String()} '
                'deleted=${importNote.isDeleted}',
              );
            }
            continue;
          }

          // Note doesn't exist locally -> it was permanently deleted locally; keep it deleted.
          notesSkippedPermanentlyDeleted++;
          if (verbose) {
            _logger.d(
              'Import note skipped (permanently deleted locally, source=$source): id=${importNote.id} title=${importNote.title}',
            );
          } else {
            _logger.i('Skipping import of permanently deleted note ${importNote.id} (source=$source)');
          }
          continue;
        }

        await createNoteWithTimestamps(
          title: importNote.title,
          contentJson: importNote.contentJson,
          folderId: importNote.folderId,
          customTagIds: importNote.customTagIds,
          createdAt: importNote.createdAt,
          updatedAt: importNote.updatedAt,
          isFavorite: importNote.isFavorite,
          isArchived: importNote.isArchived,
          isDeleted: importNote.isDeleted,
          deletedAt: importNote.deletedAt,
        );
        notesCreated++;
        if (verbose) {
          _logger.d(
            'Import note created (source=$source): '
            'title=${importNote.title} createdAt=${importNote.createdAt.toIso8601String()} '
            'folderId=${importNote.folderId} contentChars=${importNote.contentJson.length}',
          );
        }
      } catch (e, st) {
        noteErrors++;
        _logger.e('Import note failed (source=$source) index=$i error=$e', error: e, stackTrace: st);
      }
    }

    // Re-embed any notes that are new or changed after import.
    final activeNotes = _noteRepository.getActiveNotes();
    _logger.i(
      'Import upsert complete (source=$source) '
      'folders: +$foldersCreated/~$foldersUpdated/err=$folderErrors '
      'notes: +$notesCreated/~$notesUpdated/skippedDeleted=$notesSkippedPermanentlyDeleted/err=$noteErrors '
      'activeNotes=${activeNotes.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );

    try {
      await _embeddingService?.reembedStaleNotes(activeNotes);
    } catch (e, st) {
      _logger.e('Import embedding refresh failed (source=$source): $e', error: e, stackTrace: st);
    }
  }

  bool _looksLikeStorypadBackup(Map<String, dynamic> json) {
    if (json.containsKey('notes') || json.containsKey('folders')) return false;
    if (!json.containsKey('tables')) return false;

    // Observed Storypad keyset: {meta_data, tables, version}
    final hasMeta = json.containsKey('meta_data') || json.containsKey('metaData');
    final hasVersion = json.containsKey('version');
    return hasMeta || hasVersion;
  }

  Map<String, dynamic> _convertStorypadBackupToTrovaraJson(
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

    // Always ensure a default folder exists.
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

    // Try to find a folder/category table.
    final folderTableCandidates = _findTableCandidates(tables, const ['folder', 'category', 'notebook', 'collection']);
    for (final tableName in folderTableCandidates) {
      final rows = tables[tableName] ?? const <Map<String, dynamic>>[];
      for (final row in rows) {
        final rawId = row['id'] ?? row['folder_id'] ?? row['folderId'] ?? row['category_id'] ?? row['categoryId'];
        final id = _stringify(rawId);
        if (id.isEmpty) continue;

        final name = _stringify(
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

        final createdAt = _parseDate(row['created_at'] ?? row['createdAt']) ?? DateTime.now();
        final updatedAt = _parseDate(row['updated_at'] ?? row['updatedAt']) ?? createdAt;

        foldersOut.add({
          'id': 0,
          'folderId': folderId,
          'name': name.isNotEmpty ? name : 'Storypad $id',
          'description': _stringify(row['description'] ?? row['desc']).isEmpty
              ? null
              : _stringify(row['description'] ?? row['desc']),
          'color': _stringify(row['color']).isEmpty ? null : _stringify(row['color']),
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'isDefault': false,
          'noteCount': 0,
        });
      }
    }

    // Identify the notes table by heuristic scoring.
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
        final title = _stringify(row['title'] ?? row['name'] ?? row['subject']).trim();
        final rawContent =
            row['content'] ?? row['body'] ?? row['text'] ?? row['delta'] ?? row['content_json'] ?? row['contentJson'];
        final contentJson = _ensureQuillContentJson(rawContent);

        final createdAt = _parseDate(row['created_at'] ?? row['createdAt'] ?? row['created']) ?? DateTime.now();
        final updatedAt = _parseDate(row['updated_at'] ?? row['updatedAt'] ?? row['updated']) ?? createdAt;
        final deletedAt = _parseDate(row['deleted_at'] ?? row['deletedAt']);

        final isFavorite = _parseBool(row['is_favorite'] ?? row['isFavorite'] ?? row['favorite']);
        final isArchived = _parseBool(row['is_archived'] ?? row['isArchived'] ?? row['archived']);
        final isDeleted = deletedAt != null || _parseBool(row['is_deleted'] ?? row['isDeleted'] ?? row['deleted']);

        final folderId = _resolveFolderIdForNote(row, folderRowsById: folderRowsById, folderIdByName: folderIdByName);

        notesOut.add({
          // Force create-on-import semantics: Trovara treats id!=0 specially and may skip.
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
        final name = _stringify(entry.key);
        final value = entry.value;
        final rows = _coerceRows(value);
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
        final name = _stringify(map['name'] ?? map['table'] ?? map['table_name'] ?? map['tableName']);
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
    final names = tables.keys.toList();
    names.sort();
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
      if (rows.isEmpty) {
        continue;
      }

      final keys = rows.first.keys.map((k) => k.toLowerCase()).toSet();

      int score = 0;
      final lowerName = name.toLowerCase();
      if (lowerName.contains('note')) {
        score += 5;
      }
      if (lowerName.contains('notes')) {
        score += 5;
      }
      if (lowerName.contains('document')) {
        score += 3;
      }
      if (keys.contains('title') || keys.contains('name') || keys.contains('subject')) {
        score += 3;
      }
      if (keys.contains('content') || keys.contains('body') || keys.contains('text') || keys.contains('delta')) {
        score += 4;
      }
      if (keys.contains('created_at') || keys.contains('createdat')) {
        score += 1;
      }
      if (keys.contains('updated_at') || keys.contains('updatedat')) {
        score += 1;
      }

      // Penalize tables that clearly don't look like notes.
      if (keys.contains('password') || keys.contains('token')) {
        score -= 5;
      }

      if (score > bestScore) {
        bestScore = score;
        best = name;
      }
    }

    // Require at least a minimal signal.
    if (bestScore < 4) {
      return null;
    }
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
    final folderIdValue = _stringify(rawFolderId);
    if (folderIdValue.isNotEmpty && folderRowsById.containsKey(folderIdValue)) {
      return 'storypad_folder_$folderIdValue';
    }

    final folderName = _stringify(
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

      // If we got a name but no folder table, synthesize a stable-ish folderId.
      return 'storypad_${_slugify(folderName)}';
    }

    return 'default';
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  DateTime? _parseDate(dynamic value) {
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

  String _ensureQuillContentJson(dynamic content) {
    final raw = content == null ? '' : content.toString();
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return jsonEncode({
        'ops': [
          {'insert': '\n'},
        ],
      });
    }

    // If it already looks like Quill JSON, keep it.
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

  String _slugify(String input) {
    final lower = input.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  /// Merge local and remote data intelligently (Git-like merge behaviour).
  Future<Map<String, dynamic>> mergeWithRemoteData(Map<String, dynamic> remoteData) async {
    final localData = exportAllToJson();

    final mergedData = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': <Map<String, dynamic>>[],
      'folders': <Map<String, dynamic>>[],
    };

    // ── Merge folders ──
    final localFolders = Map<String, Map<String, dynamic>>.fromEntries(
      (localData['folders'] as List<dynamic>).map((f) => MapEntry(f['folderId'] as String, f as Map<String, dynamic>)),
    );
    final remoteFolders = Map<String, Map<String, dynamic>>.fromEntries(
      (remoteData['folders'] as List<dynamic>).map((f) => MapEntry(f['folderId'] as String, f as Map<String, dynamic>)),
    );

    final allFolderIds = <String>{...localFolders.keys, ...remoteFolders.keys};
    int foldersAdded = 0;
    int foldersMerged = 0;
    for (final folderId in allFolderIds) {
      final localFolder = localFolders[folderId];
      final remoteFolder = remoteFolders[folderId];

      if (localFolder == null) {
        mergedData['folders'].add(remoteFolder!);
        foldersAdded++;
      } else if (remoteFolder == null) {
        mergedData['folders'].add(localFolder);
        foldersAdded++;
      } else {
        final localUpdatedAt = DateTime.parse(localFolder['updatedAt'] as String);
        final remoteUpdatedAt = DateTime.parse(remoteFolder['updatedAt'] as String);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          mergedData['folders'].add(remoteFolder);
        } else {
          mergedData['folders'].add(localFolder);
        }
        foldersMerged++;
      }
    }
    if (kDebugMode) {
      print(
        'Folder merge complete - Added: $foldersAdded, '
        'Merged: $foldersMerged, Total: ${mergedData['folders'].length}',
      );
    }

    // ── Merge notes ──
    final localNotes = (localData['notes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final remoteNotes = (remoteData['notes'] as List<dynamic>).cast<Map<String, dynamic>>();

    final localNotesMap = <String, Map<String, dynamic>>{};
    final remoteNotesMap = <String, Map<String, dynamic>>{};

    for (final note in localNotes) {
      final key = '${note['title']}_${note['createdAt']}';
      localNotesMap[key] = note;
    }
    for (final note in remoteNotes) {
      final key = '${note['title']}_${note['createdAt']}';
      remoteNotesMap[key] = note;
    }

    final allNoteKeys = <String>{...localNotesMap.keys, ...remoteNotesMap.keys};
    int notesAdded = 0;
    int notesMerged = 0;
    for (final noteKey in allNoteKeys) {
      final localNote = localNotesMap[noteKey];
      final remoteNote = remoteNotesMap[noteKey];

      if (localNote == null) {
        mergedData['notes'].add(remoteNote!);
        notesAdded++;
      } else if (remoteNote == null) {
        mergedData['notes'].add(localNote);
        notesAdded++;
      } else {
        final localUpdatedAt = DateTime.parse(localNote['updatedAt'] as String);
        final remoteUpdatedAt = DateTime.parse(remoteNote['updatedAt'] as String);

        // For trash operations, also consider deletedAt timestamp
        final localIsDeleted = localNote['isDeleted'] as bool? ?? false;
        final remoteIsDeleted = remoteNote['isDeleted'] as bool? ?? false;

        Map<String, dynamic> mergedNote;

        if (localIsDeleted != remoteIsDeleted) {
          // Trash state differs: use the one with more recent deletion/restoration time
          DateTime? localDeletedAt;
          DateTime? remoteDeletedAt;

          if (localIsDeleted && localNote['deletedAt'] != null) {
            final deletedAtStr = localNote['deletedAt'] as String?;
            if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
              localDeletedAt = DateTime.tryParse(deletedAtStr);
            }
          }

          if (remoteIsDeleted && remoteNote['deletedAt'] != null) {
            final deletedAtStr = remoteNote['deletedAt'] as String?;
            if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
              remoteDeletedAt = DateTime.tryParse(deletedAtStr);
            }
          }

          // Compare based on most recent action (deletion or restoration)
          if (localDeletedAt != null && remoteDeletedAt != null) {
            // Both are deleted: use the one with more recent deletion
            mergedNote = remoteDeletedAt.isAfter(localDeletedAt) ? remoteNote : localNote;
          } else if (localDeletedAt != null) {
            // Local is deleted, remote is active: compare deletion time vs update time
            mergedNote = localDeletedAt.isAfter(remoteUpdatedAt) ? localNote : remoteNote;
          } else if (remoteDeletedAt != null) {
            // Remote is deleted, local is active: compare deletion time vs update time
            mergedNote = remoteDeletedAt.isAfter(localUpdatedAt) ? remoteNote : localNote;
          } else {
            // Neither has clear deletion time: use updatedAt
            mergedNote = remoteUpdatedAt.isAfter(localUpdatedAt) ? remoteNote : localNote;
          }
        } else {
          // Same trash state: use standard updatedAt comparison
          if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
            mergedNote = remoteNote;
          } else if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
            mergedNote = localNote;
          } else {
            mergedNote = localNote;
          }
        }

        mergedData['notes'].add(mergedNote);
        notesMerged++;
      }
    }
    if (kDebugMode) {
      print(
        'Note merge complete - Added: $notesAdded, '
        'Merged: $notesMerged, Total: ${mergedData['notes'].length}',
      );
    }

    return mergedData;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CRUD – active notes
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
  }) async {
    final note = await _noteRepository.createNote(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      customTagIds: customTagIds,
    );

    final folder = _folderRepository.getFolderById(folderId ?? 'default');
    if (folder != null) {
      folder.incrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }

    // Generate embedding asynchronously (non-blocking)
    _embeddingService?.embedNote(note);

    return note;
  }

  /// Create a note with preserved timestamps (for import / sync operations).
  Future<Note> createNoteWithTimestamps({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    bool isArchived = false,
    bool isDeleted = false,
    DateTime? deletedAt,
  }) async {
    final note = await _noteRepository.createNoteWithTimestamps(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      customTagIds: customTagIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite,
      isArchived: isArchived,
      isDeleted: isDeleted,
      deletedAt: deletedAt,
    );

    // Only bump folder count for active notes.
    if (!isDeleted) {
      final folder = _folderRepository.getFolderById(folderId ?? 'default');
      if (folder != null) {
        folder.incrementNoteCount();
        await _folderRepository.updateFolder(folder);
      }
    }

    return note;
  }

  Future<void> updateNote(Note note) async {
    await _noteRepository.updateNote(note);
    // Re-embed asynchronously (non-blocking)
    _embeddingService?.embedNote(note);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Soft-delete (trash / recently deleted)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Soft-delete a note: mark [isDeleted] = true and record [deletedAt].
  ///
  /// The note stays in the database and can be restored via
  /// [restoreNoteFromTrash] until it is purged.
  Future<void> softDeleteNote(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || note.isDeleted) return;

    // Decrement folder count – note is no longer "active".
    final folder = _folderRepository.getFolderById(note.folderId);
    if (folder != null) {
      folder.decrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }

    note.softDelete();
    await _noteRepository.updateNote(note);
  }

  /// Restore a note from the trash back to the active list.
  Future<void> restoreNoteFromTrash(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || !note.isDeleted) return;

    note.restoreFromTrash();
    await _noteRepository.updateNote(note);

    final folder = _folderRepository.getFolderById(note.folderId);
    if (folder != null) {
      folder.incrementNoteCount();
      await _folderRepository.updateFolder(folder);
    }
  }

  /// Permanently remove a note from the database.
  Future<void> permanentDeleteNote(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Only touch folder count if the note is still "active".
    if (!note.isDeleted) {
      final folder = _folderRepository.getFolderById(note.folderId);
      if (folder != null) {
        folder.decrementNoteCount();
        await _folderRepository.updateFolder(folder);
      }
    }

    // Delete embeddings before removing the note
    await _embeddingService?.deleteEmbeddingsForNote(noteId);

    await _noteRepository.deleteNote(noteId);
  }

  /// Remove all notes that have been in the trash longer than [maxAge].
  ///
  /// Call at app startup or when opening the Recently Deleted screen.
  Future<void> purgeExpiredDeletedNotes({Duration maxAge = const Duration(days: 30)}) async {
    final now = DateTime.now();
    final expired = deletedNotes.where(
      (note) => note.deletedAt != null && now.difference(note.deletedAt!).inDays >= maxAge.inDays,
    );

    for (final note in expired.toList()) {
      await _embeddingService?.deleteEmbeddingsForNote(note.id);
      await _noteRepository.deleteNote(note.id);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Google Drive Trash Synchronization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Move a note to trash on Google Drive and sync locally.
  ///
  /// **CRITICAL ORDER:**
  /// 1. Call Google Drive API to move file to trash
  /// 2. ONLY IF Drive succeeds → update local DB
  /// 3. Throw exception if Drive operation fails
  ///
  /// This ensures Google Drive is always the source of truth.
  Future<void> softDeleteNoteWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || note.isDeleted) return;

    // Only attempt Drive sync if we have a driveFileId and GoogleDriveService available
    if (note.driveFileId != null && _driveService != null && _driveService.isSignedIn) {
      try {
        // Step 1: Move file to trash on Google Drive FIRST
        await _driveService.moveFileToTrash(note.driveFileId!);
        _logger.i('Successfully moved note ${note.id} (${note.driveFileId}) to trash on Google Drive');
      } catch (e) {
        // If Drive operation fails, do NOT update local DB
        _logger.e('Failed to move note to trash on Google Drive: $e');
        rethrow;
      }
    }

    // Step 2: Update local DB (only after Drive succeeds or if no Drive sync needed)
    await softDeleteNote(noteId);
  }

  /// Restore a note from trash on Google Drive and sync locally.
  ///
  /// **CRITICAL ORDER:**
  /// 1. Call Google Drive API to restore file from trash
  /// 2. ONLY IF Drive succeeds → update local DB
  /// 3. Throw exception if Drive operation fails
  Future<void> restoreNoteFromTrashWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null || !note.isDeleted) return;

    // Only attempt Drive sync if we have a driveFileId and GoogleDriveService available
    if (note.driveFileId != null && _driveService != null && _driveService.isSignedIn) {
      try {
        // Step 1: Restore file on Google Drive FIRST
        await _driveService.restoreFileFromTrash(note.driveFileId!);
        _logger.i('Successfully restored note ${note.id} (${note.driveFileId}) from trash on Google Drive');
      } catch (e) {
        // If Drive operation fails, do NOT update local DB
        _logger.e('Failed to restore note from trash on Google Drive: $e');
        rethrow;
      }
    }

    // Step 2: Update local DB (only after Drive succeeds or if no Drive sync needed)
    await restoreNoteFromTrash(noteId);
  }

  /// Permanently delete a note from Google Drive and local DB.
  ///
  /// **CRITICAL ORDER:**
  /// 1. Call Google Drive API to permanently delete file
  /// 2. ONLY IF Drive succeeds → delete from local DB
  /// 3. Throw exception if Drive operation fails
  /// 4. This action is IRREVERSIBLE
  Future<void> permanentDeleteNoteWithDriveSync(int noteId) async {
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Only attempt Drive sync if we have a driveFileId and GoogleDriveService available
    if (note.driveFileId != null && _driveService != null && _driveService.isSignedIn) {
      try {
        // Step 1: Delete file from Google Drive FIRST
        await _driveService.permanentlyDeleteFile(note.driveFileId!);
        _logger.i('Successfully permanently deleted note ${note.id} (${note.driveFileId}) from Google Drive');
      } catch (e) {
        // If Drive operation fails, do NOT delete from local DB
        _logger.e('Failed to permanently delete note from Google Drive: $e');
        rethrow;
      }
    }

    // Step 2: Delete from local DB (only after Drive succeeds or if no Drive sync needed)
    await permanentDeleteNote(noteId);
  }

  /// Permanently delete a note from Google Drive by driveFileId.
  ///
  /// This is used during sync when a note was deleted locally but still exists on Drive.
  /// If the local deletion is more recent (based on latest deletedAt),
  /// the Drive file should be deleted to maintain consistency.
  ///
  /// Called from: GoogleDriveSyncService._handlePermanentlyDeletedNotes()
  Future<void> permanentlyDeleteNoteOnDrive(String driveFileId) async {
    final driveService = _driveService;
    if (driveService == null || !driveService.isSignedIn) {
      _logger.w('Cannot delete note from Drive: not signed in or Drive service unavailable');
      return;
    }

    try {
      await driveService.permanentlyDeleteFile(driveFileId);
      _logger.i('Successfully permanently deleted file $driveFileId from Google Drive during sync');
    } catch (e) {
      _logger.e('Failed to permanently delete file $driveFileId from Google Drive: $e');
      rethrow;
    }
  }

  /// Reconcile local trash state with Google Drive during sync.
  ///
  /// This is called during the sync process to ensure:
  /// - If Drive says a note is trashed, mark it as trashed locally
  /// - If Drive says a note is not trashed (and previously was), restore it
  /// - If Drive says a note is deleted (removed=true), delete it locally
  /// - Drive state ALWAYS overrides local state (latest timestamp wins)
  ///
  /// This ensures consistency after offline changes or Drive external changes.
  /// Uses timestamps to determine which state is more recent when there's conflict.
  Future<void> reconcileTrashStateWithDrive(Map<String, dynamic> driveNoteJson) async {
    if (driveNoteJson['id'] == null) return;

    final noteId = driveNoteJson['id'] as int;
    final note = _noteRepository.getNoteById(noteId);
    if (note == null) return;

    // Check Drive trash state and timestamps
    final isTrashedOnDrive = driveNoteJson['isDeleted'] as bool? ?? false;
    final isLocallyTrashed = note.isDeleted;

    // Parse timestamps from Drive
    DateTime? driveDeletedAt;
    if (isTrashedOnDrive && driveNoteJson['deletedAt'] != null) {
      final deletedAtStr = driveNoteJson['deletedAt'] as String?;
      if (deletedAtStr != null && deletedAtStr.isNotEmpty) {
        driveDeletedAt = DateTime.tryParse(deletedAtStr);
      }
    }

    // Resolve trash state based on latest timestamp
    bool shouldBeTrashed = isTrashedOnDrive;

    if (isTrashedOnDrive && isLocallyTrashed && driveDeletedAt != null && note.deletedAt != null) {
      // Both trashed: use the latest deletion timestamp
      final driveIsNewer = driveDeletedAt.isAfter(note.deletedAt!);
      shouldBeTrashed = true; // Both are trashed, so definitely trash
      if (driveIsNewer) {
        _logger.i(
          'Drive deletion is newer ($driveDeletedAt vs ${note.deletedAt}), '
          'updating local deletedAt timestamp for note $noteId',
        );
        note.deletedAt = driveDeletedAt;
      }
    } else if (isTrashedOnDrive != isLocallyTrashed) {
      // Different trash states: Drive is source of truth
      shouldBeTrashed = isTrashedOnDrive;
    }

    // Apply the resolved trash state
    if (shouldBeTrashed && !isLocallyTrashed) {
      _logger.i('Drive reports note $noteId is trashed, marking as deleted locally');
      note.softDelete();
      // Use Drive's deletedAt if provided
      if (driveDeletedAt != null) {
        note.deletedAt = driveDeletedAt;
      }
      await _noteRepository.updateNote(note);
    } else if (!shouldBeTrashed && isLocallyTrashed) {
      _logger.i('Drive reports note $noteId is active, restoring locally');
      note.restoreFromTrash();
      await _noteRepository.updateNote(note);
    } else if (shouldBeTrashed && isLocallyTrashed && driveDeletedAt != null) {
      // Both trashed but Drive has newer timestamp: update local
      if (driveDeletedAt.isAfter(note.deletedAt ?? DateTime.now())) {
        _logger.i('Updating deletedAt timestamp from Drive for note $noteId');
        note.deletedAt = driveDeletedAt;
        await _noteRepository.updateNote(note);
      }
    }

    // Update driveFileId if present
    if (driveNoteJson['driveFileId'] != null) {
      note.driveFileId = driveNoteJson['driveFileId'] as String;
      await _noteRepository.updateNote(note);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Hard-delete (legacy – use permanentDeleteNote for new code)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete a folder and move its notes to the default folder.
  Future<void> deleteFolder(String folderId) async {
    final defaultFolder = _folderRepository.getDefaultFolder();
    if (defaultFolder != null) {
      final notesToMove = _noteRepository.getNotesByFolder(folderId);
      for (final note in notesToMove) {
        note.moveToFolder(defaultFolder.folderId);
        await _noteRepository.updateNote(note);
      }
    }

    await _folderRepository.deleteFolder(folderId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Read-only delegates (repository handles filtering)
  // ═══════════════════════════════════════════════════════════════════════════

  /// All active (non-deleted) notes.
  List<Note> get notes => _noteRepository.getActiveNotes();

  /// All soft-deleted notes.
  List<Note> get deletedNotes => _noteRepository.getDeletedNotes();

  List<Note> get favoriteNotes => _noteRepository.getFavoriteNotes();
  List<Note> get archivedNotes => _noteRepository.getArchivedNotes();
  List<String> get allTags => _noteRepository.getAllTags();
  int get totalNotes => _noteRepository.totalNotes;
  int get totalWords => _noteRepository.totalWords;
  int get totalCharacters => _noteRepository.totalCharacters;

  Note? getNote(int noteId) => _noteRepository.getNoteById(noteId);
  List<Note> searchNotes(String query) => _noteRepository.searchNotes(query);
  List<Note> getNotesByFolder(String folderId) => _noteRepository.getNotesByFolder(folderId);
  List<Note> getNotesByTag(String tag) => _noteRepository.getNotesByTag(tag);

  Future<Folder> createFolder({required String name, String? description, String? color}) =>
      _folderRepository.createFolder(name: name, description: description, color: color);
  Future<Folder> createFolderWithTimestamps({
    required String folderId,
    required String name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDefault = false,
    int noteCount = 0,
  }) => _folderRepository.createFolderWithTimestamps(
    folderId: folderId,
    name: name,
    description: description,
    color: color,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isDefault: isDefault,
    noteCount: noteCount,
  );
  Future<void> updateFolder(Folder folder) => _folderRepository.updateFolder(folder);

  List<Folder> get folders => _folderRepository.getAllFolders();
  Folder? getFolder(String folderId) => _folderRepository.getFolderById(folderId);
  Folder? get defaultFolder => _folderRepository.getDefaultFolder();

  void addListener(Function() listener) {
    _noteRepository.addListener(listener);
    _folderRepository.addListener(listener);
  }

  void removeListener(Function() listener) {
    _noteRepository.removeListener(listener);
    _folderRepository.removeListener(listener);
  }

  void dispose() {
    _noteRepository.dispose();
    _folderRepository.dispose();
  }
}
