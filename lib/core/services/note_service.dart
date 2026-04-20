import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/import/adapters/storypad_adapter.dart';
import 'package:trovara/core/import/converters/markdown_to_quill.dart';
import 'package:trovara/core/import/import_adapter.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/core/services/embedding_service.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:uuid/uuid.dart';

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
  final CustomTagService? _customTagService;
  final Logger _logger = Logger();

  NoteService({
    required INoteRepository noteRepository,
    required IFolderRepository folderRepository,
    GoogleDriveService? driveService,
    EmbeddingService? embeddingService,
    CustomTagService? customTagService,
  }) : _noteRepository = noteRepository,
       _folderRepository = folderRepository,
       _driveService = driveService,
       _embeddingService = embeddingService,
       _customTagService = customTagService;

  /// Initialize both repositories
  Future<void> initialize() async {
    await _noteRepository.initialize();
    await _folderRepository.initialize();
    // Load the permanent-delete tombstone set from disk so it's available
    // synchronously for all subsequent import/export operations.
    await loadTombstonesFromDisk();
    // One-time migration: assign and persist syncIds for notes that have none
    // (e.g. created before syncId existed or ObjectBox default empty). Ensures
    // merge/import lookups by syncId find local notes instead of creating duplicates.
    await _backfillSyncIdsIfNeeded();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Export / Import / Sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Export notes and folders to a JSON map for Drive backup.
  ///
  /// Includes:
  /// - All active notes (with their syncId UUIDs)
  /// - Soft-deleted notes (in Recently Deleted, not permanently deleted)
  /// - [deletedSyncIds]: UUIDs of permanently deleted notes (tombstones)
  ///
  /// Excludes:
  /// - Permanently deleted notes (not in local DB, only their UUIDs are kept)
  Map<String, dynamic> exportAllToJson() {
    final notes = _noteRepository.getAllNotes().map((n) => n.toJson()).toList();
    final folders = _folderRepository.getAllFolders().map((f) => f.toJson()).toList();
    // Include tombstones so other devices know what was permanently deleted
    final deletedSyncIds = _loadDeletedSyncIds().toList();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes,
      'folders': folders,
      'deletedSyncIds': deletedSyncIds,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Adapter-based import (Obsidian / Notion / Storypad / …)
  // ─────────────────────────────────────────────────────────────────────────

  /// Import notes from any platform using the adapter pattern.
  ///
  /// Pipeline:
  /// 1. [adapter.parse] → `List<ImportedNote>` (Markdown content)
  /// 2. [MarkdownToQuillConverter.convert] → Quill Delta JSON
  /// 3. Upsert into ObjectBox (syncId-based merge: local-wins or newer-wins)
  /// 4. [EmbeddingService.reembedStaleNotes] (hash-gated, no wasted API calls)
  ///
  /// Returns an [ImportResult] with counts of created, updated, and skipped notes.
  Future<ImportResult> importFromAdapter(
    NoteImportAdapter adapter,
    dynamic rawInput, {
    String? targetFolderId,
    bool verbose = false,
  }) async {
    _logger.i('importFromAdapter: adapter=${adapter.sourceName}');
    final stopwatch = Stopwatch()..start();

    final List<ImportedNote> importedNotes;
    try {
      importedNotes = await adapter.parse(rawInput);
    } catch (e, st) {
      _logger.e('importFromAdapter: parse failed adapter=${adapter.sourceName}: $e', error: e, stackTrace: st);
      return const ImportResult(created: 0, updated: 0, skipped: 0, errors: ['Parse failed']);
    }

    _logger.i('importFromAdapter: parsed ${importedNotes.length} note(s) from ${adapter.sourceName}');

    int created = 0, updated = 0, skipped = 0;
    final errors = <String>[];
    final deletedSyncIds = _loadDeletedSyncIds();

    for (int i = 0; i < importedNotes.length; i++) {
      final imported = importedNotes[i];
      try {
        // Convert Markdown → Quill Delta (internal format)
        final contentJson = MarkdownToQuillConverter.convert(imported.markdownContent);

        // Resolve ImportedNote.tags to persisted CustomTag IDs (if tag service available).
        final importedCustomTagIds = await _resolveImportedCustomTagIds(imported.tags);

        // Derive a stable syncId from the title + createdAt so re-imports
        // don't create duplicates even for notes without an explicit id.
        final stableCreatedAt = imported.createdAt ?? _syntheticCreatedAtForImport(imported);
        final syncId = _deterministicSyncId(imported.title, stableCreatedAt);

        // Tombstone check
        if (deletedSyncIds.contains(syncId)) {
          skipped++;
          if (verbose) _logger.d('importFromAdapter: skipped (tombstone) title=${imported.title}');
          continue;
        }

        final existing = _noteRepository.getNoteBySync(syncId);

        if (existing != null) {
          // Always merge imported tags into the existing note, even when we skip
          // content updates due to timestamps. This keeps the UI promise that
          // tags are preserved on re-import, without making the note look newer.
          final mergedCustomTagIds = {...existing.customTagIds, ...importedCustomTagIds}.toList();
          final tagsChanged = mergedCustomTagIds.length != existing.customTagIds.length;

          // If the source doesn't provide updatedAt (common for plain Markdown),
          // treat it as "no known modification time" rather than "updated now"
          // so repeated imports don't clobber local edits.
          final incomingUpdated = imported.updatedAt ?? imported.createdAt ?? stableCreatedAt;
          if (incomingUpdated.isAfter(existing.updatedAt)) {
            existing
              ..title = imported.title
              ..contentJson = contentJson
              ..folderId = targetFolderId ?? imported.folderId ?? existing.folderId
              ..source = adapter.sourceName
              ..internalLinks = imported.internalLinks
              ..customTagIds = mergedCustomTagIds
              ..updatedAt = incomingUpdated;
            await _noteRepository.updateNote(existing, preserveTimestamps: true);
            updated++;
            if (verbose) _logger.d('importFromAdapter: updated syncId=$syncId title=${imported.title}');
          } else {
            if (tagsChanged) {
              existing.customTagIds = mergedCustomTagIds;
              // Tag-only change: preserve timestamps and skip embedding refresh.
              await updateNote(existing, skipEmbeddingRefresh: true, preserveTimestamps: true);
            }
            skipped++;
            if (verbose) _logger.d('importFromAdapter: skipped (local newer) title=${imported.title}');
          }
        } else {
          await createNoteWithTimestamps(
            syncId: syncId,
            title: imported.title,
            contentJson: contentJson,
            folderId: targetFolderId ?? imported.folderId ?? 'default',
            customTagIds: importedCustomTagIds,
            createdAt: stableCreatedAt,
            updatedAt: imported.updatedAt ?? imported.createdAt ?? stableCreatedAt,
            source: adapter.sourceName,
            internalLinks: imported.internalLinks,
          );
          created++;
          if (verbose) _logger.d('importFromAdapter: created syncId=$syncId title=${imported.title}');
        }
      } catch (e, st) {
        errors.add('note[$i] title="${imported.title}": $e');
        _logger.e('importFromAdapter: note failed index=$i title=${imported.title}: $e', error: e, stackTrace: st);
      }
    }

    _logger.i(
      'importFromAdapter complete adapter=${adapter.sourceName} '
      'created=$created updated=$updated skipped=$skipped errors=${errors.length} '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
    );

    // Hash-gated re-embed: only notes whose content actually changed are re-sent
    try {
      await _embeddingService?.reembedStaleNotes(_noteRepository.getActiveNotes());
    } catch (e, st) {
      _logger.e('importFromAdapter: post-import embedding failed: $e', error: e, stackTrace: st);
    }

    return ImportResult(created: created, updated: updated, skipped: skipped, errors: errors);
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

    // ── Merge incoming deletedSyncIds tombstones into local registry ──
    final incomingSyncIds = (workingJson['deletedSyncIds'] as List?)?.cast<String>() ?? [];
    if (incomingSyncIds.isNotEmpty) {
      await _addDeletedSyncIds(incomingSyncIds);
    }
    final deletedSyncIds = _loadDeletedSyncIds();

    for (int i = 0; i < notes.length; i++) {
      try {
        final n = notes[i];
        final noteMap = Map<String, dynamic>.from(n as Map);

        // Read raw syncId from JSON before constructing Note. Note.fromJson passes
        // syncId into the constructor, which auto-generates a UUID when null, so
        // legacy records would otherwise always get a new ID and duplicate on re-import.
        final rawSyncId = noteMap['syncId'];
        final syncIdFromJson = (rawSyncId is String && rawSyncId.trim().isNotEmpty) ? rawSyncId.trim() : null;

        final importNote = Note.fromJson(noteMap);

        // Use JSON syncId when present; otherwise assign deterministic ID for legacy backups.
        final syncId = syncIdFromJson ?? _deterministicSyncId(importNote.title, importNote.createdAt);

        // Tombstone check: skip notes that were permanently deleted on any device.
        if (deletedSyncIds.contains(syncId)) {
          notesSkippedPermanentlyDeleted++;
          if (verbose) {
            _logger.d('Import note skipped (tombstone, source=$source): syncId=$syncId title=${importNote.title}');
          }
          continue;
        }

        // Look up the note by its stable UUID (NOT by integer id).
        final existing = _noteRepository.getNoteBySync(syncId);

        if (existing != null) {
          // Note exists locally: update only fields that are potentially newer.
          // Respect updatedAt so we don't regress to older data.
          final incomingUpdatedAt = importNote.updatedAt;
          if (incomingUpdatedAt.isAfter(existing.updatedAt) || source == 'google-drive-sync') {
            // Apply all fields from the merged/winner note.
            // Preserve the local ObjectBox id and the stable syncId.
            existing
              ..title = importNote.title
              ..contentJson = importNote.contentJson
              ..folderId = importNote.folderId
              ..customTagIds = importNote.customTagIds
              ..moodTags = importNote.moodTags
              ..activityTags = importNote.activityTags
              ..timeTags = importNote.timeTags
              ..personalGrowthTags = importNote.personalGrowthTags
              ..isFavorite = importNote.isFavorite
              ..isArchived = importNote.isArchived
              ..isDeleted = importNote.isDeleted
              ..deletedAt = importNote.deletedAt
              ..driveFileId = importNote.driveFileId
              ..userId = importNote.userId
              ..updatedAt = importNote.updatedAt;
            await _noteRepository.updateNote(existing, preserveTimestamps: true);
            notesUpdated++;
            if (verbose) {
              _logger.d('Import note updated (source=$source): syncId=$syncId title=${importNote.title}');
            }
          } else {
            // Local is newer — no update needed (local wins).
            if (verbose) {
              _logger.d(
                'Import note skipped (local is newer, source=$source): syncId=$syncId title=${importNote.title}',
              );
            }
          }
          continue;
        }

        // Note does not exist locally → create it with the original syncId preserved.
        await createNoteWithTimestamps(
          syncId: syncId,
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
          userId: importNote.userId,
          moodTags: importNote.moodTags,
          activityTags: importNote.activityTags,
          timeTags: importNote.timeTags,
          personalGrowthTags: importNote.personalGrowthTags,
        );
        notesCreated++;
        if (verbose) {
          _logger.d('Import note created (source=$source): syncId=$syncId title=${importNote.title}');
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

  bool _looksLikeStorypadBackup(Map<String, dynamic> json) => _storypadAdapter.canHandle(json);

  final StorypadAdapter _storypadAdapter = StorypadAdapter();

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

    _logger.i('Sync merge started. Local notes: ${localNotes.length}, Remote notes: ${remoteNotes.length}');

    // ── Build maps keyed by syncId ──
    // If a note has no syncId (legacy backup), generate one from title+createdAt.
    final localNotesMap = <String, Map<String, dynamic>>{};
    final remoteNotesMap = <String, Map<String, dynamic>>{};

    for (final note in localNotes) {
      final rawSyncId = note['syncId'] as String?;
      final key = (rawSyncId != null && rawSyncId.isNotEmpty)
          ? rawSyncId
          : _deterministicSyncId(note['title'] as String? ?? '', _parseCreatedAtStable(note));
      note['syncId'] = key;
      localNotesMap[key] = note;
    }
    for (final note in remoteNotes) {
      final rawSyncId = note['syncId'] as String?;
      final key = (rawSyncId != null && rawSyncId.isNotEmpty)
          ? rawSyncId
          : _deterministicSyncId(note['title'] as String? ?? '', _parseCreatedAtStable(note));
      note['syncId'] = key;
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

    _logger.i('Sync merge done. Added: $notesAdded, Merged: $notesMerged, Total: ${mergedData['notes'].length}');

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
    String? userId,
  }) async {
    final note = await _noteRepository.createNote(
      title: title,
      contentJson: contentJson,
      folderId: folderId,
      customTagIds: customTagIds,
      userId: userId,
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
    String? syncId,
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
    String? userId,
    List<String>? moodTags,
    List<String>? activityTags,
    List<String>? timeTags,
    List<String>? personalGrowthTags,
    String source = 'trovara',
    List<String>? internalLinks,
  }) async {
    final note = await _noteRepository.createNoteWithTimestamps(
      syncId: syncId,
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
      userId: userId,
      moodTags: moodTags,
      activityTags: activityTags,
      timeTags: timeTags,
      personalGrowthTags: personalGrowthTags,
    );

    // Apply new fields that the repository interface doesn't expose yet.
    // This is intentionally a lightweight update (no embedding refresh,
    // no timestamp change) — just persisting source + link metadata.
    if (source != 'trovara' || (internalLinks != null && internalLinks.isNotEmpty)) {
      note
        ..source = source
        ..internalLinks = internalLinks ?? [];
      await _noteRepository.updateNote(note, preserveTimestamps: true);
    }

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

  /// Updates a note in the repository.
  ///
  /// When [skipEmbeddingRefresh] is true, re-embedding is skipped. Use for
  /// metadata-only updates (e.g. assigning userId) to avoid unnecessary
  /// embedding work and API usage.
  ///
  /// When [preserveTimestamps] is true, [note.updatedAt] is not overwritten
  /// (e.g. for syncId backfill or import/sync so merges don't lose remote wins).
  Future<void> updateNote(Note note, {bool skipEmbeddingRefresh = false, bool preserveTimestamps = false}) async {
    await _noteRepository.updateNote(note, preserveTimestamps: preserveTimestamps);
    if (!skipEmbeddingRefresh) {
      _embeddingService?.embedNote(note);
    }
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

    // Register the syncId as permanently deleted BEFORE removing the record.
    // This ensures all future syncs know this note was intentionally removed.
    await registerPermanentlyDeletedSyncId(note.syncId);

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
  /// Looks up the local note by [syncId] (from the note JSON, or deterministic
  /// for legacy). Ensures Drive's trash state is reflected locally. Drive is
  /// the source of truth; timestamps resolve conflicts.
  Future<void> reconcileTrashStateWithDrive(Map<String, dynamic> driveNoteJson) async {
    final syncId = getSyncIdFromNoteJson(driveNoteJson);
    final note = _noteRepository.getNoteBySync(syncId);
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
      final driveIsNewer = driveDeletedAt.isAfter(note.deletedAt!);
      shouldBeTrashed = true;
      if (driveIsNewer) {
        _logger.i(
          'Drive deletion is newer ($driveDeletedAt vs ${note.deletedAt}), '
          'updating local deletedAt for note syncId=$syncId',
        );
        note.deletedAt = driveDeletedAt;
      }
    } else if (isTrashedOnDrive != isLocallyTrashed) {
      shouldBeTrashed = isTrashedOnDrive;
    }

    if (shouldBeTrashed && !isLocallyTrashed) {
      _logger.i('Drive reports note syncId=$syncId is trashed, marking as deleted locally');
      note.softDelete();
      if (driveDeletedAt != null) {
        note.deletedAt = driveDeletedAt;
      }
      await _noteRepository.updateNote(note);
    } else if (!shouldBeTrashed && isLocallyTrashed) {
      _logger.i('Drive reports note syncId=$syncId is active, restoring locally');
      note.restoreFromTrash();
      await _noteRepository.updateNote(note);
    } else if (shouldBeTrashed && isLocallyTrashed && driveDeletedAt != null) {
      if (driveDeletedAt.isAfter(note.deletedAt ?? DateTime.now())) {
        _logger.i('Updating deletedAt from Drive for note syncId=$syncId');
        note.deletedAt = driveDeletedAt;
        await _noteRepository.updateNote(note);
      }
    }

    if (driveNoteJson['driveFileId'] != null) {
      note.driveFileId = driveNoteJson['driveFileId'] as String;
      await _noteRepository.updateNote(note);
    }
  }

  /// Returns the stable syncId for a note from its JSON. Uses [syncId] if
  /// present and non-empty; otherwise a deterministic id from title+createdAt.
  /// Used by sync/merge to key notes consistently across devices.
  String getSyncIdFromNoteJson(Map<String, dynamic> noteJson) {
    final raw = noteJson['syncId'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    final title = noteJson['title'] as String? ?? '';
    final createdAt = _parseCreatedAtStable(noteJson);
    return _deterministicSyncId(title, createdAt);
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

  /// Active notes owned by [userId] (includes anonymous notes).
  List<Note> notesForUser(String? userId) => _noteRepository.getActiveNotesForUser(userId);

  /// All soft-deleted notes.
  List<Note> get deletedNotes => _noteRepository.getDeletedNotes();

  /// Soft-deleted notes owned by [userId] (includes anonymous notes).
  List<Note> deletedNotesForUser(String? userId) => _noteRepository.getDeletedNotesForUser(userId);

  List<Note> get favoriteNotes => _noteRepository.getFavoriteNotes();
  List<Note> favoriteNotesForUser(String? userId) => _noteRepository.getFavoriteNotesForUser(userId);
  List<Note> get archivedNotes => _noteRepository.getArchivedNotes();
  List<Note> archivedNotesForUser(String? userId) => _noteRepository.getArchivedNotesForUser(userId);
  List<String> get allTags => _noteRepository.getAllTags();
  int get totalNotes => _noteRepository.totalNotes;
  int get totalWords => _noteRepository.totalWords;
  int get totalCharacters => _noteRepository.totalCharacters;

  Note? getNote(int noteId) => _noteRepository.getNoteById(noteId);
  List<Note> searchNotes(String query) => _noteRepository.searchNotes(query);
  List<Note> searchNotesForUser(String? userId, String query) => _noteRepository.searchNotesForUser(userId, query);
  List<Note> getNotesByFolder(String folderId) => _noteRepository.getNotesByFolder(folderId);
  List<Note> getNotesByFolderForUser(String? userId, String folderId) =>
      _noteRepository.getNotesByFolderForUser(userId, folderId);
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  Private sync helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static const _kDeletedSyncIdsKey = 'permanentlyDeletedSyncIds';

  /// Generates a deterministic UUID-v5-like string from a note's title and
  /// createdAt timestamp. Used to assign stable identities to legacy backups
  /// that were created before the [syncId] field existed.
  ///
  /// This is NOT cryptographically strong — it's just a stable fingerprint.
  String _deterministicSyncId(String title, DateTime createdAt) {
    // Namespace UUID for Trovara deterministic IDs (randomly chosen constant).
    const ns = Namespace.url;
    final name = '${title.trim()}|${createdAt.toUtc().toIso8601String()}';
    return const Uuid().v5(ns.value, name);
  }

  /// Parses [createdAt] from a note map for deterministic syncId generation.
  /// Uses a fixed epoch when missing or invalid so the same note yields the same
  /// syncId across devices/runs (avoids DateTime.now() which would break matching).
  DateTime _parseCreatedAtStable(Map<String, dynamic> note) {
    final raw = note['createdAt'] as String? ?? '';
    return DateTime.tryParse(raw) ?? DateTime.utc(1970, 1, 1);
  }

  /// When adapter imports omit timestamps (common for plain Markdown),
  /// we still need a deterministic createdAt to build a stable syncId.
  /// This must never depend on wall-clock time.
  DateTime _syntheticCreatedAtForImport(ImportedNote imported) {
    // Include title + body so two untimestamped notes with the same title
    // don't automatically collide.
    final seed = '${imported.title.trim()}\n${imported.markdownContent}';
    final seconds = _stableHash32(seed);
    return DateTime.utc(1970, 1, 1).add(Duration(seconds: seconds));
  }

  /// Simple deterministic non-crypto 32-bit hash (FNV-1a).
  int _stableHash32(String input) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // Keep in signed int range but deterministic.
    return hash & 0x7FFFFFFF;
  }

  Future<List<int>> _resolveImportedCustomTagIds(List<String> rawTags) async {
    if (rawTags.isEmpty) return const [];
    final svc = _customTagService;
    if (svc == null) return const [];

    final normalized = rawTags.map((t) => t.replaceAll('#', '').trim()).where((t) => t.isNotEmpty).toSet().toList();

    if (normalized.isEmpty) return const [];

    final ids = <int>[];
    for (final name in normalized) {
      final tag = await svc.createOrGetCustomTag(name);
      ids.add(tag.id);
    }
    return ids;
  }

  /// One-time migration: assign and persist a deterministic syncId for any note
  /// that has none (empty or null). Notes created before syncId existed or with
  /// ObjectBox default empty syncId would otherwise be missed by merge/import
  /// lookups (getNoteBySync), causing duplicates on first sync.
  Future<void> _backfillSyncIdsIfNeeded() async {
    final allNotes = _noteRepository.getAllNotes();
    for (final note in allNotes) {
      if (note.syncId.isEmpty) {
        note.syncId = _deterministicSyncId(note.title, note.createdAt);
        await updateNote(note, skipEmbeddingRefresh: true, preserveTimestamps: true);
        _logger.d('Backfilled syncId for note id=${note.id} title=${note.title}');
      }
    }
  }

  /// Load the set of permanently-deleted note syncIds from local storage.
  /// Returns an empty set if nothing has been stored yet.
  Set<String> _loadDeletedSyncIds() =>
      // SharedPreferences is not async-friendly in a synchronous context,
      // so we keep a lazy in-memory cache that is populated on first access.
      _deletedSyncIdsCache;

  /// Merge [newIds] into the persistent tombstone registry and persist to disk.
  /// Awaited so tombstones are durable before the caller continues (e.g. before
  /// deleting the note record), avoiding loss if the app terminates soon after.
  Future<void> _addDeletedSyncIds(Iterable<String> newIds) async {
    _deletedSyncIdsCache.addAll(newIds);
    await _persistDeletedSyncIds();
  }

  /// Register [syncId] as permanently deleted so it is excluded by all future imports.
  /// Awaits persistence so the tombstone is durable before returning.
  Future<void> registerPermanentlyDeletedSyncId(String syncId) async {
    await _addDeletedSyncIds([syncId]);
  }

  // In-memory cache so we don't need async SharedPreferences in sync code.
  final Set<String> _deletedSyncIdsCache = {};
  bool _tombstonesLoaded = false;

  /// Call once (or lazily) to populate the cache from SharedPreferences.
  Future<void> loadTombstonesFromDisk() async {
    if (_tombstonesLoaded) return;
    _tombstonesLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDeletedSyncIdsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<String>();
        _deletedSyncIdsCache.addAll(list);
      }
    } catch (e) {
      _logger.w('Failed to load tombstones from disk: $e');
    }
  }

  Future<void> _persistDeletedSyncIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_deletedSyncIdsCache.toList());
      await prefs.setString(_kDeletedSyncIdsKey, encoded);
    } catch (e) {
      _logger.w('Failed to persist tombstones: $e');
    }
  }
}
