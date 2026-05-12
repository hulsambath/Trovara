import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/services/notes/note_sync_id.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Pure-function Git-like merge of folders + notes between local and remote
/// snapshots. Resolves conflicts by `updatedAt` (most recent wins) and special-
/// cases trash-state divergence using `deletedAt`.
class NoteMergeEngine {
  const NoteMergeEngine._();

  /// Merge two export-shape maps (`{folders: [...], notes: [...]}`) into one.
  ///
  /// Rules:
  /// - Folders: union by `folderId`; on conflict the higher `updatedAt` wins.
  /// - Notes: union by `syncId` (deterministic fallback for legacy records);
  ///   on conflict the higher `updatedAt` wins, except when trash state
  ///   differs — then the latest `deletedAt`/`updatedAt` action wins.
  static Map<String, dynamic> merge(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData, {
    required Logger logger,
  }) {
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

    logger.i('Sync merge started. Local notes: ${localNotes.length}, Remote notes: ${remoteNotes.length}');

    final localNotesMap = _keyNotesBySyncId(localNotes);
    final remoteNotesMap = _keyNotesBySyncId(remoteNotes);

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
        mergedData['notes'].add(_mergeNotePair(localNote, remoteNote));
        notesMerged++;
      }
    }
    if (kDebugMode) {
      print(
        'Note merge complete - Added: $notesAdded, '
        'Merged: $notesMerged, Total: ${mergedData['notes'].length}',
      );
    }

    logger.i('Sync merge done. Added: $notesAdded, Merged: $notesMerged, Total: ${mergedData['notes'].length}');

    return mergedData;
  }

  static Map<String, Map<String, dynamic>> _keyNotesBySyncId(List<Map<String, dynamic>> notes) {
    final out = <String, Map<String, dynamic>>{};
    for (final note in notes) {
      final rawSyncId = note['syncId'] as String?;
      final key = (rawSyncId != null && rawSyncId.isNotEmpty)
          ? rawSyncId
          : NoteSyncId.deterministic(note['title'] as String? ?? '', NoteSyncId.parseCreatedAtStable(note));
      note['syncId'] = key;
      out[key] = note;
    }
    return out;
  }

  static Map<String, dynamic> _mergeNotePair(Map<String, dynamic> localNote, Map<String, dynamic> remoteNote) {
    final localUpdatedAt = DateTime.parse(localNote['updatedAt'] as String);
    final remoteUpdatedAt = DateTime.parse(remoteNote['updatedAt'] as String);

    final localIsDeleted = localNote['isDeleted'] as bool? ?? false;
    final remoteIsDeleted = remoteNote['isDeleted'] as bool? ?? false;

    if (localIsDeleted == remoteIsDeleted) {
      // Same trash state: standard updatedAt comparison.
      if (remoteUpdatedAt.isAfter(localUpdatedAt)) return remoteNote;
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) return localNote;
      return localNote;
    }

    // Trash state differs: use the side with the more recent action
    // (deletion for the deleted side, updatedAt for the active side).
    final localDeletedAt = _parseDeletedAt(localNote);
    final remoteDeletedAt = _parseDeletedAt(remoteNote);

    if (localDeletedAt != null && remoteDeletedAt != null) {
      return remoteDeletedAt.isAfter(localDeletedAt) ? remoteNote : localNote;
    }
    if (localDeletedAt != null) {
      return localDeletedAt.isAfter(remoteUpdatedAt) ? localNote : remoteNote;
    }
    if (remoteDeletedAt != null) {
      return remoteDeletedAt.isAfter(localUpdatedAt) ? remoteNote : localNote;
    }
    // Neither has clear deletion time: fall back to updatedAt.
    return remoteUpdatedAt.isAfter(localUpdatedAt) ? remoteNote : localNote;
  }

  static DateTime? _parseDeletedAt(Map<String, dynamic> note) {
    final isDeleted = note['isDeleted'] as bool? ?? false;
    if (!isDeleted) return null;
    final raw = note['deletedAt'];
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
