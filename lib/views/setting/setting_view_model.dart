import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:notemyminds/core/base/base_view_model.dart';
import 'package:notemyminds/core/di/service_locator.dart';
import 'package:notemyminds/core/services/google_drive_service.dart';
import 'package:notemyminds/core/services/google_drive_sync_service.dart';
import 'package:notemyminds/core/services/note_service.dart';
import 'package:notemyminds/core/storage/google_drive_auth_storage.dart';
import 'package:notemyminds/views/trash/trash_view.dart';
import 'package:notemyminds/widgets/nm_loading_overlay.dart';
import 'package:notemyminds/widgets/nm_toast.dart';
import 'package:path_provider/path_provider.dart';

class SettingViewModel extends BaseViewModel {
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final NoteService _noteService = ServiceLocator().noteService;
  final GoogleDriveSyncService _syncService = ServiceLocator().googleDriveSyncService;

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
    // Try to get from current user first, then fallback to stored values
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

  Future<void> signInGoogle(BuildContext context) async {
    try {
      await _driveService.signIn();
      NmToast.success(context, 'Google sign-in complete');
      await _refreshAccount();
      // Automatically sync data after successful sign-in
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

  /// Automatically sync data after successful sign-in
  Future<void> _autoSyncAfterSignIn(BuildContext context) async {
    try {
      // Step 1: Pull data from Google Drive
      final driveData = await _driveService.downloadJsonFromAppData('notemyminds_backup.json');

      // Step 2: Merge local and remote data
      Map<String, dynamic> mergedData;
      if (driveData != null) {
        // Merge local and remote data
        mergedData = await _noteService.mergeWithRemoteData(driveData);

        // Apply the merged data locally
        await _noteService.importAllFromJson(mergedData);

        // Step 3: Push merged data to Google Drive
        await _driveService.uploadJsonToAppData(fileName: 'notemyminds_backup.json', json: mergedData);

        NmToast.success(context, 'Data automatically synced from Google Drive');
      } else {
        // No remote data exists, backup local data
        final localData = _noteService.exportAllToJson();
        await _driveService.uploadJsonToAppData(fileName: 'notemyminds_backup.json', json: localData);

        NmToast.success(context, 'Local data backed up to Google Drive');
      }
    } catch (e) {
      // Log the error but don't show to user for auto-sync failures
      if (kDebugMode) print('Auto-sync after sign-in failed: $e');
      // Don't show error toast for auto-sync failures to avoid overwhelming the user
    }
  }

  Future<void> syncWithGoogleDrive(BuildContext context) async {
    // Use the dedicated sync service with loading overlay and toast
    final result = await _syncService.syncWithLoadingOverlay(context);

    // Refresh account info after sync
    await _refreshAccount();

    // Show result toast
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

  Future<void> exportToFile(BuildContext context) async {
    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.showProcessing(context, () async {
      try {
        String? targetPath;
        // Prefer native save dialog on desktop/web
        try {
          final saveLocation = await getSaveLocation(suggestedName: 'notemyminds_export.json');
          if (saveLocation != null) targetPath = saveLocation.path;
        } catch (_) {}

        // On mobile let user pick a folder via FilePicker if available
        if (targetPath == null) {
          try {
            final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to save export');
            if (dir != null) targetPath = '$dir/notemyminds_export.json';
          } catch (_) {}
        }

        // Fallback to app documents if user cancels
        targetPath ??= '${(await getApplicationDocumentsDirectory()).path}/notemyminds_export.json';

        final jsonMap = _noteService.exportAllToJson();
        final data = utf8.encode(jsonEncode(jsonMap));
        final file = XFile.fromData(data, name: 'notemyminds_export.json', mimeType: 'application/json');
        await file.saveTo(targetPath);
        successMessage = 'Exported to $targetPath';
      } catch (e) {
        errorMessage = 'Export failed: $e';
      }
    });

    // Show toast after loading dialog is dismissed
    if (successMessage != null) {
      NmToast.success(context, successMessage!);
    } else if (errorMessage != null) {
      NmToast.error(context, errorMessage!);
    }
  }

  Future<void> importFromFile(BuildContext context) async {
    String? successMessage;
    String? errorMessage;

    await NmLoadingOverlay.showProcessing(context, () async {
      try {
        String? path;
        try {
          final typeGroup = const XTypeGroup(label: 'json', extensions: ['json']);
          final picked = await openFile(acceptedTypeGroups: [typeGroup]);
          path = picked?.path;
        } catch (_) {}

        if (path == null) {
          try {
            final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
            path = result?.files.single.path;
          } catch (_) {}
        }

        path ??= '${(await getApplicationDocumentsDirectory()).path}/notemyminds_export.json';

        final text = await XFile(path).readAsString();
        final jsonMap = jsonDecode(text) as Map<String, dynamic>;
        await _noteService.importAllFromJson(jsonMap);
        successMessage = 'Import complete';
      } catch (e) {
        errorMessage = 'Import failed: $e';
      }
    });

    // Show toast after loading dialog is dismissed
    if (successMessage != null) {
      NmToast.success(context, successMessage!);
    } else if (errorMessage != null) {
      NmToast.error(context, errorMessage!);
    }
  }

  /// Open the Recently Deleted notes screen.
  void openRecentlyDeleted(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashView()));
  }
}
