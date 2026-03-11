import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/widgets/nm_loading_overlay.dart';
import 'package:trovara/widgets/nm_toast.dart';

/// Service for handling Google Drive synchronization operations
class GoogleDriveSyncService {
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final NoteService _noteService = ServiceLocator().noteService;
  final Logger _logger = Logger();

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
          .downloadJsonFromAppData('trovara_backup.json')
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
            .importAllFromJson(mergedData, source: 'google-drive-sync', verbose: false)
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw Exception('Data import timeout - data might be too large');
              },
            );

        // Step 2b: Reconcile trash state with Drive
        // Ensure local trash state matches Drive (Drive is source of truth)
        await _reconcileTrashState(mergedData);

        // Step 2c: Handle permanently deleted notes
        // If a note exists on Drive but was permanently deleted locally,
        // delete it from Drive if local deletion is more recent
        await _handlePermanentlyDeletedNotes(driveData);
      } else {
        // No remote data exists, use local data
        mergedData = _noteService.exportAllToJson();
      }

      // Step 3: Push merged data to Google Drive (with timeout)
      await _driveService
          .uploadJsonToAppData(fileName: 'trovara_backup.json', json: mergedData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout - please check your internet connection');
            },
          );

      // Step 4: Sync chat history (non-blocking; errors logged but don't fail the overall sync)
      try {
        await ServiceLocator().chatDriveSyncService.syncChatWithGoogleDrive();
        _logger.i('Chat history sync completed as part of Drive sync');
      } catch (e) {
        _logger.w('Chat history sync failed (non-fatal): $e');
      }

      // Step 5: Return success result
      if (driveData != null) {
        return SyncResult.success('Synced notes and chat with Google Drive');
      } else {
        return SyncResult.success('Backed up notes and chat to Google Drive');
      }
    } catch (e) {
      // Handle different types of errors with more specific messages
      String errorMessage = _getErrorMessage(e);
      return SyncResult.error(errorMessage);
    }
  }

  /// Handles authentication and syncs data with Google Drive
  ///
  /// This method ensures the user is signed in before attempting to sync.
  /// After successful sign-in, assigns the Google account ID to all notes
  /// that don't yet have a userId (anonymous notes become owned).
  Future<SyncResult> syncWithAuthentication() async {
    try {
      // Handle authentication - sign in if not signed in, or re-authenticate if needed
      if (!_driveService.isSignedIn) {
        await _driveService.signIn();
      }

      // Assign userId to anonymous notes (userId == null) now that we have a Google account
      final currentUser = _driveService.currentUser;
      if (currentUser != null) {
        await _assignUserIdToAnonymousNotes(currentUser.id);
      }

      return await syncWithGoogleDrive();
    } catch (e) {
      String errorMessage = _getErrorMessage(e);
      return SyncResult.error(errorMessage);
    }
  }

  /// Assigns the Google account ID to all notes that have no userId.
  ///
  /// When a user first syncs with Google Drive, their existing local notes
  /// (created anonymously) are claimed by setting userId to the Google
  /// account `sub` identifier.
  Future<void> _assignUserIdToAnonymousNotes(String googleAccountId) async {
    try {
      final allNotes = _noteService.notes + _noteService.deletedNotes;
      int assigned = 0;
      for (final note in allNotes) {
        if (note.userId == null) {
          note.userId = googleAccountId;
          await _noteService.updateNote(note, skipEmbeddingRefresh: true);
          assigned++;
        }
      }
      if (assigned > 0) {
        _logger.i('Assigned userId ($googleAccountId) to $assigned anonymous notes');
      }
    } catch (e) {
      _logger.w('Error assigning userId to anonymous notes: $e');
    }
  }

  /// Reconcile local trash state with Drive state during sync.
  ///
  /// This ensures that Drive's trash state (isDeleted, deletedAt) is reflected
  /// locally after sync. Drive is always the source of truth.
  Future<void> _reconcileTrashState(Map<String, dynamic> mergedData) async {
    try {
      final notes = mergedData['notes'] as List<dynamic>? ?? [];
      for (final noteJson in notes) {
        final noteData = noteJson as Map<String, dynamic>;
        await _noteService.reconcileTrashStateWithDrive(noteData);
      }
      _logger.i('Trash state reconciliation complete');
    } catch (e) {
      _logger.w('Error during trash state reconciliation: $e');
      // Don't throw - this is optional reconciliation
    }
  }

  /// Handle notes that were permanently deleted (tombstoned) on any device.
  ///
  /// Uses [deletedSyncIds] (tombstones) from the local export. For each note on
  /// Drive, resolves its [syncId]; if that syncId is in the tombstone set, the
  /// note was permanently deleted and we delete the file from Drive so other
  /// devices don't re-import it. Keyed by syncId so behaviour is correct across
  /// devices (integer id is device-local and must not be used).
  Future<void> _handlePermanentlyDeletedNotes(Map<String, dynamic> driveData) async {
    try {
      final localExport = _noteService.exportAllToJson();
      final deletedSyncIds = Set<String>.from((localExport['deletedSyncIds'] as List<dynamic>?)?.cast<String>() ?? []);
      if (deletedSyncIds.isEmpty) return;

      final driveNotes = driveData['notes'] as List<dynamic>? ?? [];
      for (final noteJson in driveNotes) {
        final noteData = noteJson as Map<String, dynamic>;
        final syncId = _noteService.getSyncIdFromNoteJson(noteData);
        final driveFileId = noteData['driveFileId'] as String?;

        if (driveFileId == null) continue;
        if (!deletedSyncIds.contains(syncId)) continue;

        _logger.i('Note syncId=$syncId was permanently deleted (tombstone), deleting from Drive');
        try {
          await _noteService.permanentlyDeleteNoteOnDrive(driveFileId);
          _logger.i('Successfully deleted note syncId=$syncId from Drive');
        } catch (e) {
          _logger.w('Failed to delete note syncId=$syncId from Drive: $e');
        }
      }

      _logger.i('Permanently deleted notes handling complete');
    } catch (e) {
      _logger.w('Error during permanently deleted notes handling: $e');
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
