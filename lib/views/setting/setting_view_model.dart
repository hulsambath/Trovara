import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/export/exporters/markdown_exporter.dart';
import 'package:trovara/core/import/adapters/notion_adapter.dart';
import 'package:trovara/core/import/adapters/obsidian_adapter.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/google_drive_sync_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/core/storage/google_drive_auth_storage.dart';
import 'package:trovara/views/trash/trash_view.dart';
import 'package:trovara/widgets/nm_loading_overlay.dart';
import 'package:trovara/widgets/nm_toast.dart';

class SettingViewModel extends BaseViewModel {
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final NoteService _noteService = ServiceLocator().noteService;
  final GoogleDriveSyncService _syncService = ServiceLocator().googleDriveSyncService;
  final Logger _logger = Logger();

  bool get isSignedIn => _driveService.isSignedIn;
  String? _accountName;
  String? _accountEmail;
  String? _accountPhotoUrl;
  String? get accountName => _accountName;
  String? get accountEmail => _accountEmail;
  String? get accountPhotoUrl => _accountPhotoUrl;

  SettingViewModel() {
    Future.microtask(() => _refreshAccount());
  }

  Future<void> _refreshAccount() async {
    final currentUser = _driveService.currentUser;
    if (currentUser != null) {
      _accountName = currentUser.displayName;
      _accountEmail = currentUser.email;
      _accountPhotoUrl = currentUser.photoUrl;
    } else {
      _accountName = await GoogleDriveAccountNameStorage().read();
      _accountEmail = await GoogleDriveAccountEmailStorage().read();
      _accountPhotoUrl = await GoogleDriveAccountPhotoUrlStorage().read();
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Google account
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> signInGoogle(BuildContext context) async {
    try {
      await _driveService.signIn();
      NmToast.success(context, 'Google sign-in complete');
      await _refreshAccount();
      await _autoSyncAfterSignIn(context);
    } catch (e) {
      String errorMessage = 'Google sign-in failed';
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Sign-in was cancelled.';
      } else {
        errorMessage = 'Sign-in failed: ${e.toString().split(':').last.trim()}';
      }
      NmToast.error(context, errorMessage);
    }
  }

  Future<void> _autoSyncAfterSignIn(BuildContext context) async {
    try {
      final driveData = await _driveService.downloadJsonFromAppData('trovara_backup.json');
      Map<String, dynamic> mergedData;
      if (driveData != null) {
        mergedData = await _noteService.mergeWithRemoteData(driveData);
        await _noteService.importAllFromJson(mergedData, source: 'google-drive-auto-sync', verbose: false);
        await _driveService.uploadJsonToAppData(fileName: 'trovara_backup.json', json: mergedData);
        NmToast.success(context, 'Data automatically synced from Google Drive');
      } else {
        final localData = _noteService.exportAllToJson();
        await _driveService.uploadJsonToAppData(fileName: 'trovara_backup.json', json: localData);
        NmToast.success(context, 'Local data backed up to Google Drive');
      }
    } catch (e) {
      if (kDebugMode) print('Auto-sync after sign-in failed: $e');
    }
  }

  Future<void> syncWithGoogleDrive(BuildContext context) async {
    final result = await _syncService.syncWithLoadingOverlay(context);
    await _refreshAccount();
    _syncService.showSyncResultToast(context, result);
  }

  Future<void> signOutGoogle(BuildContext context) async {
    try {
      await _driveService.signOut();
      NmToast.success(context, 'Signed out');
      await _refreshAccount();
    } catch (e) {
      NmToast.error(context, 'Sign out failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  JSON Export / Import (original Trovara format)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportToFile(BuildContext context) async {
    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.showProcessing(context, () async {
      try {
        String? targetPath;
        try {
          final saveLocation = await getSaveLocation(suggestedName: 'trovara_export.json');
          if (saveLocation != null) targetPath = saveLocation.path;
        } catch (_) {}

        if (targetPath == null) {
          try {
            final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to save export');
            if (dir != null) targetPath = '$dir/trovara_export.json';
          } catch (_) {}
        }

        targetPath ??= '${(await getApplicationDocumentsDirectory()).path}/trovara_export.json';

        final jsonMap = _noteService.exportAllToJson();
        final data = utf8.encode(jsonEncode(jsonMap));
        final file = XFile.fromData(data, name: 'trovara_export.json', mimeType: 'application/json');
        await file.saveTo(targetPath);
        successMessage = 'Exported to $targetPath';
      } catch (e) {
        errorMessage = 'Export failed: $e';
      }
    });

    if (successMessage != null) NmToast.success(context, successMessage!);
    if (errorMessage != null) NmToast.error(context, errorMessage!);
  }

  Future<void> importFromFile(BuildContext context) async {
    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.showProcessing(context, () async {
      try {
        String? jsonText;
        String? pickedPath;

        try {
          final typeGroup = const XTypeGroup(
            label: 'JSON',
            extensions: ['json', 'JSON'],
            mimeTypes: ['application/json', 'text/json'],
            uniformTypeIdentifiers: ['public.json'],
          );
          final picked = await openFile(acceptedTypeGroups: [typeGroup]);
          if (picked != null) {
            pickedPath = picked.path;
            jsonText = await picked.readAsString();
          }
        } catch (_) {}

        if (jsonText == null) {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['json', 'JSON'],
              withData: true,
            );
            if (result != null && result.files.isNotEmpty) {
              final f = result.files.single;
              pickedPath = f.path;
              if (f.bytes != null) {
                jsonText = utf8.decode(f.bytes!);
              } else if (f.path != null) {
                jsonText = await XFile(f.path!).readAsString();
              }
            }
          } catch (_) {}
        }

        if (jsonText == null) {
          return;
        }

        _logger.i('Import file selected: path=$pickedPath chars=${jsonText.length}');

        final decoded = jsonDecode(jsonText);
        if (decoded is! Map<String, dynamic>) {
          throw FormatException('Expected top-level JSON object, got ${decoded.runtimeType}');
        }

        final jsonMap = decoded;
        final keys = jsonMap.keys.toList()..sort();
        final foldersCount = (jsonMap['folders'] is List) ? (jsonMap['folders'] as List).length : null;
        final notesCount = (jsonMap['notes'] is List) ? (jsonMap['notes'] as List).length : null;
        _logger.i('Import JSON summary: keys=$keys folders=$foldersCount notes=$notesCount');

        await _noteService.importAllFromJson(jsonMap, source: 'file-import', verbose: kDebugMode);
        successMessage = 'Import complete';
      } catch (e) {
        errorMessage = 'Import failed: $e';
      }
    });

    if (successMessage != null) NmToast.success(context, successMessage!);
    if (errorMessage != null) NmToast.error(context, errorMessage!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Markdown Export (Obsidian-compatible)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportAsMarkdown(BuildContext context) async {
    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.show(context, () async {
      try {
        String? targetPath;
        try {
          final saveLocation = await getSaveLocation(
            suggestedName: 'trovara_notes.md',
            acceptedTypeGroups: [
              const XTypeGroup(label: 'Markdown', extensions: ['md']),
            ],
          );
          if (saveLocation != null) targetPath = saveLocation.path;
        } catch (_) {}

        if (targetPath == null) {
          try {
            final dir = await FilePicker.platform.getDirectoryPath(
              dialogTitle: 'Choose folder to save Markdown export',
            );
            if (dir != null) targetPath = '$dir/trovara_notes.md';
          } catch (_) {}
        }

        targetPath ??= '${(await getApplicationDocumentsDirectory()).path}/trovara_notes.md';

        final notes = _noteService.notes.where((n) => !n.isDeleted).toList();
        final markdown = MarkdownExporter.exportNotes(notes);
        final data = utf8.encode(markdown);
        final file = XFile.fromData(data, name: 'trovara_notes.md', mimeType: 'text/markdown');
        await file.saveTo(targetPath);
        successMessage = 'Exported ${notes.length} note(s) to $targetPath';
      } catch (e) {
        errorMessage = 'Markdown export failed: $e';
      }
    }, message: 'Exporting…');

    if (successMessage != null && context.mounted) NmToast.success(context, successMessage!);
    if (errorMessage != null && context.mounted) NmToast.error(context, errorMessage!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Obsidian Import
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> importFromObsidian(BuildContext context) async {
    // Pick multiple .md files (simulates vault folder selection)
    List<PlatformFile>? pickedFiles;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md'],
        allowMultiple: true,
        dialogTitle: 'Select Obsidian vault Markdown files',
      );
      pickedFiles = result?.files;
    } catch (e) {
      NmToast.error(context, 'Could not open file picker: $e');
      return;
    }

    if (pickedFiles == null || pickedFiles.isEmpty) return;
    final picked = pickedFiles;

    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.show(context, () async {
      try {
        // Build the {path, content} list the adapter expects
        final files = <Map<String, dynamic>>[];
        final baseDir = _commonBaseDir(picked.map((pf) => pf.path).whereType<String>().toList());
        for (final pf in picked) {
          final absPath = pf.path;
          if (absPath == null) continue;
          final content = await File(absPath).readAsString();
          files.add({'path': _relativePickedPath(absPath, baseDir, fallbackName: pf.name), 'content': content});
        }

        final adapter = ObsidianAdapter();
        final result = await _noteService.importFromAdapter(adapter, files, verbose: kDebugMode);
        successMessage =
            'Obsidian import complete — '
            '${result.created} created, ${result.updated} updated, ${result.skipped} skipped'
            '${result.errors.isNotEmpty ? ', ${result.errors.length} error(s)' : ''}';
      } catch (e) {
        errorMessage = 'Obsidian import failed: $e';
      }
    }, message: 'Importing Obsidian vault…');

    if (successMessage != null && context.mounted) NmToast.success(context, successMessage!);
    if (errorMessage != null && context.mounted) NmToast.error(context, errorMessage!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Notion Import
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> importFromNotion(BuildContext context) async {
    // Pick .md files from a Notion export
    List<PlatformFile>? pickedFiles;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'csv'],
        allowMultiple: true,
        dialogTitle: 'Select Notion export files (.md and .csv)',
      );
      pickedFiles = result?.files;
    } catch (e) {
      NmToast.error(context, 'Could not open file picker: $e');
      return;
    }

    if (pickedFiles == null || pickedFiles.isEmpty) return;
    final picked = pickedFiles;

    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.show(context, () async {
      try {
        final files = <Map<String, dynamic>>[];
        final baseDir = _commonBaseDir(picked.map((pf) => pf.path).whereType<String>().toList());
        for (final pf in picked) {
          final absPath = pf.path;
          if (absPath == null) continue;
          final content = await File(absPath).readAsString();
          files.add({'path': _relativePickedPath(absPath, baseDir, fallbackName: pf.name), 'content': content});
        }

        final adapter = NotionAdapter();
        final result = await _noteService.importFromAdapter(adapter, files, verbose: kDebugMode);
        successMessage =
            'Notion import complete — '
            '${result.created} created, ${result.updated} updated, ${result.skipped} skipped'
            '${result.errors.isNotEmpty ? ', ${result.errors.length} error(s)' : ''}';
      } catch (e) {
        errorMessage = 'Notion import failed: $e';
      }
    }, message: 'Importing Notion export…');

    if (successMessage != null && context.mounted) NmToast.success(context, successMessage!);
    if (errorMessage != null && context.mounted) NmToast.error(context, errorMessage!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Search index
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> reembedAllNotes(BuildContext context) async {
    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.showProcessing(context, () async {
      try {
        final embeddingService = ServiceLocator().embeddingService;
        if (!embeddingService.isAvailable) {
          errorMessage = 'Embeddings are not configured. Please set up an embeddings API key before re-indexing notes.';
          return;
        }
        final notes = _noteService.notes;
        await embeddingService.reembedAll(notes);
        successMessage = 'Successfully re-indexed ${notes.length} notes';
      } catch (e) {
        errorMessage = 'Failed to re-index notes: $e';
      }
    });

    if (successMessage != null && context.mounted) NmToast.success(context, successMessage!);
    if (errorMessage != null && context.mounted) NmToast.error(context, errorMessage!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Navigation
  // ═══════════════════════════════════════════════════════════════════════════

  void openRecentlyDeleted(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashView()));
  }

  /// Compute a stable base directory shared by all picked files so we can
  /// pass adapters a relative path that preserves subfolder structure.
  String? _commonBaseDir(List<String> absolutePaths) {
    if (absolutePaths.isEmpty) return null;
    final dirParts = absolutePaths.map((fp) => p.split(p.normalize(p.dirname(fp)))).toList();
    if (dirParts.isEmpty) return null;

    final first = dirParts.first;
    int commonLen = first.length;
    for (final parts in dirParts.skip(1)) {
      commonLen = commonLen < parts.length ? commonLen : parts.length;
      for (int i = 0; i < commonLen; i++) {
        if (parts[i] != first[i]) {
          commonLen = i;
          break;
        }
      }
      if (commonLen == 0) break;
    }

    if (commonLen == 0) return null;
    return p.joinAll(first.take(commonLen));
  }

  String _relativePickedPath(String absolutePath, String? baseDir, {required String fallbackName}) {
    if (baseDir == null || baseDir.isEmpty) return fallbackName;
    try {
      final rel = p.relative(p.normalize(absolutePath), from: p.normalize(baseDir));
      // If relative path escapes the base dir, fall back to filename.
      if (rel.startsWith('..')) return fallbackName;
      // Normalize to forward slashes for adapter regexes and portability.
      return rel.replaceAll('\\', '/');
    } catch (_) {
      return fallbackName;
    }
  }
}
