import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:trovara/core/storage/google_drive_auth_storage.dart';

/// Handles Google authentication and Drive AppData backup/restore.
class GoogleDriveService {
  final Logger _logger = Logger();

  late final GoogleSignIn _googleSignIn;
  drive.DriveApi? _driveApi;
  bool _isInitialized = false;

  GoogleDriveService() {
    _googleSignIn = GoogleSignIn(
      scopes: <String>[
        drive.DriveApi.driveAppdataScope, // Access to AppData folder
        'email',
        'profile',
      ],
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    final wasSignedIn = await GoogleDriveSignedInStorage().read() ?? false;
    if (wasSignedIn) {
      try {
        await _googleSignIn.signInSilently();
        if (_googleSignIn.currentUser != null) {
          await _ensureDriveApi();
        } else {
          await GoogleDriveSignedInStorage().write(false);
        }
      } catch (_) {
        await GoogleDriveSignedInStorage().write(false);
      }
    }
    _isInitialized = true;
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account != null) {
        await _ensureDriveApi();
        await GoogleDriveSignedInStorage().write(true);
        await GoogleDriveAccountEmailStorage().write(account.email);
        await GoogleDriveAccountIdStorage().write(account.id);
        await GoogleDriveAccountNameStorage().write(account.displayName);
        await GoogleDriveAccountPhotoUrlStorage().write(account.photoUrl);
      }
      return account;
    } catch (e) {
      _logger.e('Google sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
      _driveApi = null;
      // Clear persisted
      await GoogleDriveSignedInStorage().write(false);
      await GoogleDriveAccountEmailStorage().write(null);
      await GoogleDriveAccountIdStorage().write(null);
      await GoogleDriveAccountNameStorage().write(null);
      await GoogleDriveAccountPhotoUrlStorage().write(null);
    } catch (e) {
      _logger.w('Google sign-out error: $e');
    }
  }

  bool get isSignedIn => _googleSignIn.currentUser != null;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<void> _ensureDriveApi() async {
    if (_driveApi != null) return;
    final authHeaders = await _googleSignIn.currentUser?.authHeaders;
    if (authHeaders == null) throw StateError('No auth headers, user not signed in');

    final client = _GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(client);
  }

  /// Ensure Drive API is available, with authentication refresh if needed
  Future<void> ensureAuthenticatedDriveApi() async {
    try {
      await _ensureDriveApi();
    } catch (e) {
      // If authentication fails, try to re-authenticate
      _logger.w('Drive API authentication failed, attempting re-authentication: $e');
      await signIn();
      await _ensureDriveApi();
    }
  }

  /// Uploads JSON content to Drive AppData with a fixed filename.
  Future<void> uploadJsonToAppData({required String fileName, required Map<String, dynamic> json}) async {
    await ensureAuthenticatedDriveApi();
    final driveApi = _driveApi!;

    // Check if file exists
    final existing = await driveApi.files.list(
      q: "name = '$fileName' and 'appDataFolder' in parents and trashed = false",
      spaces: 'appDataFolder',
    );
    final content = utf8.encode(jsonEncode(json));
    final media = drive.Media(
      Stream<List<int>>.fromIterable(<List<int>>[content]),
      content.length,
      contentType: 'application/json',
    );

    if (existing.files?.isNotEmpty == true) {
      final id = existing.files!.first.id!;
      await driveApi.files.update(drive.File(), id, uploadMedia: media);
    } else {
      final file = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];
      await driveApi.files.create(file, uploadMedia: media);
    }
  }

  /// Downloads JSON content from Drive AppData. Returns null if file absent.
  Future<Map<String, dynamic>?> downloadJsonFromAppData(String fileName) async {
    await ensureAuthenticatedDriveApi();
    final driveApi = _driveApi!;

    final result = await driveApi.files.list(
      q: "name = '$fileName' and 'appDataFolder' in parents and trashed = false",
      spaces: 'appDataFolder',
    );
    if (result.files?.isEmpty != false) return null;
    final id = result.files!.first.id!;

    final media = await driveApi.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = await media.stream.expand((c) => c).toList();
    final text = utf8.decode(bytes);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Google Drive Trash Operations (Move to Bin, Restore, Permanent Delete)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Move a file to trash on Google Drive.
  ///
  /// This sets the `trashed` flag on the Drive file to true,
  /// mimicking Google Drive's "Move to Trash" behavior.
  ///
  /// Throws an exception if the Drive API call fails.
  /// Returns the updated Drive file.
  Future<drive.File> moveFileToTrash(String driveFileId) async {
    await ensureAuthenticatedDriveApi();
    final driveApi = _driveApi!;

    _logger.i('Moving file $driveFileId to trash');
    final file = drive.File()..trashed = true;
    return await driveApi.files.update(file, driveFileId);
  }

  /// Restore a file from trash on Google Drive.
  ///
  /// This sets the `trashed` flag on the Drive file to false,
  /// restoring it from trash.
  ///
  /// Throws an exception if the Drive API call fails.
  /// Returns the updated Drive file.
  Future<drive.File> restoreFileFromTrash(String driveFileId) async {
    await ensureAuthenticatedDriveApi();
    final driveApi = _driveApi!;

    _logger.i('Restoring file $driveFileId from trash');
    final file = drive.File()..trashed = false;
    return await driveApi.files.update(file, driveFileId);
  }

  /// Permanently delete a file from Google Drive.
  ///
  /// This completely removes the file from Drive.
  /// This action is irreversible.
  ///
  /// Throws an exception if the Drive API call fails.
  Future<void> permanentlyDeleteFile(String driveFileId) async {
    await ensureAuthenticatedDriveApi();
    final driveApi = _driveApi!;

    _logger.i('Permanently deleting file $driveFileId');
    await driveApi.files.delete(driveFileId);
  }

  /// Get a file's trash state from Google Drive.
  ///
  /// Returns true if the file is trashed, false otherwise.
  /// Returns null if the file doesn't exist or cannot be accessed.
  Future<bool?> isFileTrashed(String driveFileId) async {
    try {
      await ensureAuthenticatedDriveApi();
      final driveApi = _driveApi!;

      // Get file metadata with trashed field
      final response = await driveApi.files.get(driveFileId) as drive.File?;
      if (response == null) return null;

      return response.trashed ?? false;
    } catch (e) {
      _logger.w('Failed to check trash status for file $driveFileId: $e');
      return null;
    }
  }
}

/// Simple auth client that injects GoogleSignIn auth headers into requests.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
