import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/core/base/base_view_model.dart';
import 'package:noteminds/core/di/service_locator.dart';
import 'package:noteminds/core/services/google_drive_service.dart';
import 'package:noteminds/core/services/note_service.dart';
import 'package:noteminds/core/storage/google_drive_auth_storage.dart';
import 'package:path_provider/path_provider.dart';

class SettingViewModel extends BaseViewModel {
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final NoteService _noteService = ServiceLocator().noteService;

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
      _toast(context, 'Google sign-in complete', false);
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

      _toast(context, errorMessage, true);
    }
  }

  /// Automatically sync data after successful sign-in
  Future<void> _autoSyncAfterSignIn(BuildContext context) async {
    try {
      // Step 1: Pull data from Google Drive
      final driveData = await _driveService.downloadJsonFromAppData('noteminds_backup.json');

      // Step 2: Merge local and remote data
      Map<String, dynamic> mergedData;
      if (driveData != null) {
        // Merge local and remote data
        mergedData = await _noteService.mergeWithRemoteData(driveData);

        // Apply the merged data locally
        await _noteService.importAllFromJson(mergedData);

        // Step 3: Push merged data to Google Drive
        await _driveService.uploadJsonToAppData(fileName: 'noteminds_backup.json', json: mergedData);

        _toast(context, 'Data automatically synced from Google Drive', false);
      } else {
        // No remote data exists, backup local data
        final localData = _noteService.exportAllToJson();
        await _driveService.uploadJsonToAppData(fileName: 'noteminds_backup.json', json: localData);

        _toast(context, 'Local data backed up to Google Drive', false);
      }
    } catch (e) {
      // Log the error but don't show to user for auto-sync failures
      if (kDebugMode) print('Auto-sync after sign-in failed: $e');
      // Don't show error toast for auto-sync failures to avoid overwhelming the user
    }
  }

  Future<void> syncWithGoogleDrive(BuildContext context) async {
    await _withLoading(context, () async {
      try {
        // Handle authentication - sign in if not signed in, or re-authenticate if needed
        if (!isSignedIn) {
          await _driveService.signIn();
          await _refreshAccount();
        }

        // Step 1: Pull data from Google Drive
        final driveData = await _driveService.downloadJsonFromAppData('noteminds_backup.json');

        // Step 2: Merge local and remote data
        Map<String, dynamic> mergedData;
        if (driveData != null) {
          // Merge local and remote data
          mergedData = await _noteService.mergeWithRemoteData(driveData);

          // Apply the merged data locally
          await _noteService.importAllFromJson(mergedData);
        } else {
          // No remote data exists, use local data
          mergedData = _noteService.exportAllToJson();
        }

        // Step 3: Push merged data to Google Drive
        await _driveService.uploadJsonToAppData(fileName: 'noteminds_backup.json', json: mergedData);

        // Step 4: Provide user feedback
        if (driveData != null) {
          _toast(context, 'Synced with Google Drive (data merged and synchronized)', false);
        } else {
          _toast(context, 'Synced with Google Drive (data backed up to cloud)', false);
        }
      } catch (e) {
        String errorMessage = 'Sync failed';

        // Handle different types of errors with more specific messages
        if (e.toString().contains('401') || e.toString().contains('authentication')) {
          errorMessage = 'Authentication failed. Please try signing in again.';
        } else if (e.toString().contains('403') || e.toString().contains('permission')) {
          errorMessage = 'Access denied. Please check your Google Drive permissions.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection') ||
            e.toString().contains('timeout')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('cancelled') || e.toString().contains('user_cancelled')) {
          errorMessage = 'Sync was cancelled.';
        } else if (e.toString().contains('quota') || e.toString().contains('storage')) {
          errorMessage = 'Google Drive storage quota exceeded. Please free up space.';
        } else {
          // Extract the most relevant part of the error message
          final errorParts = e.toString().split(':');
          final lastPart = errorParts.last.trim();
          errorMessage = 'Sync failed: ${lastPart.length > 50 ? '${lastPart.substring(0, 50)}...' : lastPart}';
        }

        _toast(context, errorMessage, true);
      }
    });
  }

  Future<void> signOutGoogle(BuildContext context) async {
    try {
      await _driveService.signOut();
      _toast(context, 'Signed out', false);
      await _refreshAccount();
    } catch (e) {
      _toast(context, 'Sign out failed: $e', true);
    }
  }

  Future<void> exportToFile(BuildContext context) async {
    await _withLoading(context, () async {
      try {
        String? targetPath;
        // Prefer native save dialog on desktop/web
        try {
          final saveLocation = await getSaveLocation(suggestedName: 'noteminds_export.json');
          if (saveLocation != null) targetPath = saveLocation.path;
        } catch (_) {}

        // On mobile let user pick a folder via FilePicker if available
        if (targetPath == null) {
          try {
            final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to save export');
            if (dir != null) targetPath = '$dir/noteminds_export.json';
          } catch (_) {}
        }

        // Fallback to app documents if user cancels
        targetPath ??= '${(await getApplicationDocumentsDirectory()).path}/noteminds_export.json';

        final jsonMap = _noteService.exportAllToJson();
        final data = utf8.encode(jsonEncode(jsonMap));
        final file = XFile.fromData(data, name: 'noteminds_export.json', mimeType: 'application/json');
        await file.saveTo(targetPath);
        _toast(context, 'Exported to $targetPath', false);
      } catch (e) {
        _toast(context, 'Export failed: $e', true);
      }
    });
  }

  Future<void> importFromFile(BuildContext context) async {
    await _withLoading(context, () async {
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

        path ??= '${(await getApplicationDocumentsDirectory()).path}/noteminds_export.json';

        final text = await XFile(path).readAsString();
        final jsonMap = jsonDecode(text) as Map<String, dynamic>;
        await _noteService.importAllFromJson(jsonMap);
        _toast(context, 'Import complete', false);
      } catch (e) {
        _toast(context, 'Import failed: $e', true);
      }
    });
  }

  Future<void> _withLoading(BuildContext context, Future<void> Function() action) async {
    // Show blocking loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
    } finally {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _toast(BuildContext context, String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: !isError ? Colors.white : Theme.of(context).colorScheme.onError),
        ),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        action: SnackBarAction(
          label: 'Close',
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
          },
        ),
      ),
    );
  }
}
