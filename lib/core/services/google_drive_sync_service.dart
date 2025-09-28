import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noteminds/core/di/service_locator.dart';
import 'package:noteminds/core/services/google_drive_service.dart';
import 'package:noteminds/core/services/note_service.dart';
import 'package:noteminds/widgets/nm_loading_overlay.dart';
import 'package:noteminds/widgets/nm_toast.dart';

/// Service for handling Google Drive synchronization operations
class GoogleDriveSyncService {
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final NoteService _noteService = ServiceLocator().noteService;

  /// Syncs data with Google Drive
  ///
  /// This method handles the complete sync process:
  /// 1. Downloads data from Google Drive
  /// 2. Merges local and remote data
  /// 3. Applies merged data locally
  /// 4. Uploads merged data back to Google Drive
  ///
  /// Returns a [SyncResult] containing the result and any messages
  Future<SyncResult> syncWithGoogleDrive() async {
    try {
      // Step 1: Pull data from Google Drive (with timeout)
      final driveData = await _driveService
          .downloadJsonFromAppData('noteminds_backup.json')
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Download timeout - please check your internet connection');
            },
          );

      // Step 2: Merge local and remote data
      Map<String, dynamic> mergedData;
      if (driveData != null) {
        // Merge local and remote data (with timeout)
        mergedData = await _noteService
            .mergeWithRemoteData(driveData)
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw Exception('Data merge timeout - data might be too large');
              },
            );

        // Apply the merged data locally (with timeout)
        await _noteService
            .importAllFromJson(mergedData)
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw Exception('Data import timeout - data might be too large');
              },
            );
      } else {
        // No remote data exists, use local data
        mergedData = _noteService.exportAllToJson();
      }

      // Step 3: Push merged data to Google Drive (with timeout)
      await _driveService
          .uploadJsonToAppData(fileName: 'noteminds_backup.json', json: mergedData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout - please check your internet connection');
            },
          );

      // Step 4: Return success result
      if (driveData != null) {
        return SyncResult.success('Synced with Google Drive (data merged and synchronized)');
      } else {
        return SyncResult.success('Synced with Google Drive (data backed up to cloud)');
      }
    } catch (e) {
      // Handle different types of errors with more specific messages
      String errorMessage = _getErrorMessage(e);
      return SyncResult.error(errorMessage);
    }
  }

  /// Handles authentication and syncs data with Google Drive
  ///
  /// This method ensures the user is signed in before attempting to sync
  Future<SyncResult> syncWithAuthentication() async {
    try {
      // Handle authentication - sign in if not signed in, or re-authenticate if needed
      if (!_driveService.isSignedIn) {
        await _driveService.signIn();
      }

      return await syncWithGoogleDrive();
    } catch (e) {
      String errorMessage = _getErrorMessage(e);
      return SyncResult.error(errorMessage);
    }
  }

  /// Gets a user-friendly error message from an exception
  String _getErrorMessage(dynamic e) {
    if (e.toString().contains('401') || e.toString().contains('authentication')) {
      return 'Authentication failed. Please try signing in again.';
    } else if (e.toString().contains('403') || e.toString().contains('permission')) {
      return 'Access denied. Please check your Google Drive permissions.';
    } else if (e.toString().contains('network') ||
        e.toString().contains('connection') ||
        e.toString().contains('timeout')) {
      return 'Network error. Please check your internet connection.';
    } else if (e.toString().contains('cancelled') || e.toString().contains('user_cancelled')) {
      return 'Sync was cancelled.';
    } else if (e.toString().contains('quota') || e.toString().contains('storage')) {
      return 'Google Drive storage quota exceeded. Please free up space.';
    } else {
      // Extract the most relevant part of the error message
      final errorParts = e.toString().split(':');
      final lastPart = errorParts.last.trim();
      return 'Sync failed: ${lastPart.length > 50 ? '${lastPart.substring(0, 50)}...' : lastPart}';
    }
  }

  /// Shows a loading overlay while executing a sync operation
  ///
  /// This method provides a consistent UI experience for sync operations
  Future<SyncResult> syncWithLoadingOverlay(BuildContext context) async =>
      await NmLoadingOverlay.showSync(context, () async => await syncWithAuthentication());

  /// Shows a toast message based on sync result
  void showSyncResultToast(BuildContext context, SyncResult result) {
    if (result.isSuccess) {
      NmToast.success(context, result.message);
    } else {
      NmToast.error(context, result.message);
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final bool isSuccess;
  final String message;

  const SyncResult._(this.isSuccess, this.message);

  /// Creates a successful sync result
  factory SyncResult.success(String message) => SyncResult._(true, message);

  /// Creates an error sync result
  factory SyncResult.error(String message) => SyncResult._(false, message);
}
