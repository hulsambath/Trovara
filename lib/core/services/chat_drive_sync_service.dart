import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/chat_service.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/widgets/nm_loading_overlay.dart';
import 'package:trovara/widgets/nm_toast.dart';

/// Backup filename for chat history in Google Drive AppData.
///
/// Stored separately from the notes backup (`trovara_backup.json`)
/// so that the two data sets can evolve independently.
const String _chatBackupFileName = 'trovara_chat_backup.json';

/// Service for synchronizing chat history with Google Drive AppData.
///
/// Follows the same pattern as [GoogleDriveSyncService] (for notes)
/// but operates on [ChatService] data and a separate Drive file.
class ChatDriveSyncService {
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final ChatService _chatService = ServiceLocator().chatService;

  /// Full sync: download, merge, apply locally, then upload merged data.
  Future<ChatSyncResult> syncChatWithGoogleDrive() async {
    try {
      final driveData = await _driveService
          .downloadJsonFromAppData(_chatBackupFileName)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Download timeout - please check your internet connection');
            },
          );

      Map<String, dynamic> mergedData;

      if (driveData != null) {
        mergedData = _chatService.mergeWithRemoteData(driveData);

        await _chatService
            .importAllFromJson(mergedData)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Import timeout - data might be too large');
              },
            );
      } else {
        mergedData = _chatService.exportAllToJson();
      }

      await _driveService
          .uploadJsonToAppData(fileName: _chatBackupFileName, json: mergedData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout - please check your internet connection');
            },
          );

      if (driveData != null) {
        return ChatSyncResult.success('Chat history synced with Google Drive');
      } else {
        return ChatSyncResult.success('Chat history backed up to Google Drive');
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e);
      return ChatSyncResult.error(errorMessage);
    }
  }

  /// Sign in if needed, then sync.
  Future<ChatSyncResult> syncWithAuthentication() async {
    try {
      if (!_driveService.isSignedIn) {
        await _driveService.signIn();
      }
      return await syncChatWithGoogleDrive();
    } catch (e) {
      return ChatSyncResult.error(_getErrorMessage(e));
    }
  }

  String _getErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('authentication')) {
      return 'Authentication failed. Please try signing in again.';
    } else if (msg.contains('403') || msg.contains('permission')) {
      return 'Access denied. Please check your Google Drive permissions.';
    } else if (msg.contains('network') || msg.contains('connection') || msg.contains('timeout')) {
      return 'Network error. Please check your internet connection.';
    } else if (msg.contains('cancelled') || msg.contains('user_cancelled')) {
      return 'Chat sync was cancelled.';
    } else if (msg.contains('quota') || msg.contains('storage')) {
      return 'Google Drive storage quota exceeded.';
    }

    final parts = msg.split(':');
    final last = parts.last.trim();
    return 'Chat sync failed: ${last.length > 50 ? '${last.substring(0, 50)}...' : last}';
  }

  Future<ChatSyncResult> syncWithLoadingOverlay(BuildContext context) async =>
      await NmLoadingOverlay.showSync(context, () async => await syncWithAuthentication());

  void showSyncResultToast(BuildContext context, ChatSyncResult result) {
    if (result.isSuccess) {
      NmToast.success(context, result.message);
    } else {
      NmToast.error(context, result.message);
    }
  }
}

/// Result of a chat sync operation.
class ChatSyncResult {
  final bool isSuccess;
  final String message;

  const ChatSyncResult._(this.isSuccess, this.message);

  factory ChatSyncResult.success(String message) => ChatSyncResult._(true, message);
  factory ChatSyncResult.error(String message) => ChatSyncResult._(false, message);
}
