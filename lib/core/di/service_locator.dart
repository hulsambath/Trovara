import 'package:noteminds/core/repository/base/objectbox_store_manager.dart';
import 'package:noteminds/core/repository/implementations/objectbox_folder_repository.dart';
import 'package:noteminds/core/repository/implementations/objectbox_note_repository.dart';
import 'package:noteminds/core/repository/interfaces/folder_repository.dart';
import 'package:noteminds/core/repository/interfaces/note_repository.dart';
import 'package:noteminds/core/services/google_drive_service.dart';
import 'package:noteminds/core/services/note_service.dart';

/// Service Locator for dependency injection
/// Follows Dependency Inversion Principle - provides abstractions, not concrete implementations
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Lazy initialization of services
  INoteRepository? _noteRepository;
  IFolderRepository? _folderRepository;
  NoteService? _noteService;
  GoogleDriveService? _googleDriveService;

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

  /// Get the note service instance
  NoteService get noteService {
    _noteService ??= NoteService(noteRepository: noteRepository, folderRepository: folderRepository);
    return _noteService!;
  }

  GoogleDriveService get googleDriveService {
    _googleDriveService ??= GoogleDriveService();
    return _googleDriveService!;
  }

  /// Initialize all services
  Future<void> initialize() async {
    await noteService.initialize();
  }

  /// Dispose all services
  void dispose() {
    _noteService?.dispose();
    _noteRepository?.dispose();
    _folderRepository?.dispose();
    _googleDriveService = null;

    // Close the shared ObjectBox Store
    ObjectBoxStoreManager().close();

    _noteService = null;
    _noteRepository = null;
    _folderRepository = null;
  }
}
