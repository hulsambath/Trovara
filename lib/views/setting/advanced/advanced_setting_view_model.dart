import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/export/exporters/markdown_exporter.dart';
import 'package:trovara/core/import/adapters/notion_adapter.dart';
import 'package:trovara/core/import/adapters/obsidian_adapter.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/widgets/nm_loading_overlay.dart';
import 'package:trovara/widgets/nm_toast.dart';

class AdvancedSettingViewModel extends BaseViewModel {
  final NoteService _noteService = ServiceLocator().noteService;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Markdown Export
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
            acceptedTypeGroups: [const XTypeGroup(label: 'Markdown', extensions: ['md'])],
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
  //  AI Search
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
  //  Private helpers
  // ═══════════════════════════════════════════════════════════════════════════

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
      if (rel.startsWith('..')) return fallbackName;
      return rel.replaceAll('\\', '/');
    } catch (_) {
      return fallbackName;
    }
  }
}
