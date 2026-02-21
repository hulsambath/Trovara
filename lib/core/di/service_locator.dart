import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/implementations/objectbox_custom_tag_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_folder_repository.dart';
import 'package:trovara/core/repository/implementations/objectbox_note_repository.dart';
import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/core/services/google_drive_service.dart';
import 'package:trovara/core/services/google_drive_sync_service.dart';
import 'package:trovara/core/services/note_service.dart';

/// Service Locator for dependency injection
/// Follows Dependency Inversion Principle - provides abstractions, not concrete implementations
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Lazy initialization of services
  INoteRepository? _noteRepository;
  IFolderRepository? _folderRepository;
  ICustomTagRepository? _customTagRepository;
  NoteService? _noteService;
  CustomTagService? _customTagService;
  GoogleDriveService? _googleDriveService;
  GoogleDriveSyncService? _googleDriveSyncService;

  /// Get the note repository instance
  INoteRepository get noteRepository {
    _noteRepository ??= ObjectBoxNoteRepository();
    return _noteRepository!;
  }

  /// Get the folder repository instance
  IFolderRepository get folderRepository {
    _folderRepository ??= ObjectBoxFolderRepository();
    return _folderRepository!;
  }

  /// Get the custom tag repository instance
  ICustomTagRepository get customTagRepository {
    _customTagRepository ??= ObjectBoxCustomTagRepository();
    return _customTagRepository!;
  }

  /// Get the note service instance
  NoteService get noteService {
    _noteService ??= NoteService(
      noteRepository: noteRepository,
      folderRepository: folderRepository,
      driveService: googleDriveService,
    );
    return _noteService!;
  }

  /// Get the custom tag service instance
  CustomTagService get customTagService {
    _customTagService ??= CustomTagService(customTagRepository: customTagRepository);
    return _customTagService!;
  }

  GoogleDriveService get googleDriveService {
    _googleDriveService ??= GoogleDriveService();
    return _googleDriveService!;
  }

  /// Get the Google Drive sync service instance
  GoogleDriveSyncService get googleDriveSyncService {
    _googleDriveSyncService ??= GoogleDriveSyncService();
    return _googleDriveSyncService!;
  }

  /// Initialize all services
  Future<void> initialize() async {
    await noteService.initialize();
    await customTagService.initialize();
  }

  /// Dispose all services
  void dispose() {
    _noteService?.dispose();
    _noteRepository?.dispose();
    _folderRepository?.dispose();
    _googleDriveService = null;
    _googleDriveSyncService = null;

    // Close the shared ObjectBox Store
    ObjectBoxStoreManager().close();

    _noteService = null;
    _noteRepository = null;
    _folderRepository = null;
  }
}
