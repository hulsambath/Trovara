import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/core/services/sync/google_drive_sync_service.dart';
import 'package:trovara/core/storage/google_drive_auth_storage.dart';
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
  //  Backup (JSON export / import)
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
            final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to save backup');
            if (dir != null) targetPath = '$dir/trovara_export.json';
          } catch (_) {}
        }

        targetPath ??= '${(await getApplicationDocumentsDirectory()).path}/trovara_export.json';

        final jsonMap = _noteService.exportAllToJson();
        final data = utf8.encode(jsonEncode(jsonMap));
        final file = XFile.fromData(data, name: 'trovara_export.json', mimeType: 'application/json');
        await file.saveTo(targetPath);
        successMessage = 'Backup saved to $targetPath';
      } catch (e) {
        errorMessage = 'Backup failed: $e';
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
          const typeGroup = XTypeGroup(
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

        if (jsonText == null) return;

        _logger.i('Restore file selected: path=$pickedPath chars=${jsonText.length}');

        final decoded = jsonDecode(jsonText);
        if (decoded is! Map<String, dynamic>) {
          throw FormatException('Expected top-level JSON object, got ${decoded.runtimeType}');
        }

        final jsonMap = decoded;
        final keys = jsonMap.keys.toList()..sort();
        final foldersCount = (jsonMap['folders'] is List) ? (jsonMap['folders'] as List).length : null;
        final notesCount = (jsonMap['notes'] is List) ? (jsonMap['notes'] as List).length : null;
        _logger.i('Restore JSON summary: keys=$keys folders=$foldersCount notes=$notesCount');

        await _noteService.importAllFromJson(jsonMap, source: 'file-import', verbose: kDebugMode);
        successMessage = 'Restore complete';
      } catch (e) {
        errorMessage = 'Restore failed: $e';
      }
    });

    if (successMessage != null) NmToast.success(context, successMessage!);
    if (errorMessage != null) NmToast.error(context, errorMessage!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Navigation
  // ═══════════════════════════════════════════════════════════════════════════

  void openRecentlyDeleted(BuildContext context) {
    context.push('/trash');
  }

  void openAdvancedSettings(BuildContext context) {
    context.push('/settings/advanced');
  }
}
