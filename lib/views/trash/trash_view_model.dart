import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/models/note.dart';

class TrashViewModel extends BaseViewModel {
  final NoteService _noteService = ServiceLocator().noteService;
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final Logger _logger = Logger();

  List<Note> _deletedNotes = [];
  bool _isLoading = true;
  bool _isDisposed = false;

  List<Note> get deletedNotes => _deletedNotes;
  bool get isLoading => _isLoading;

  TrashViewModel() {
    Future.microtask(() => _initialize());
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Ensure expired notes are purged before showing the list.
      await _noteService.purgeExpiredDeletedNotes();

      _noteService.addListener(_onDataChanged);
      _loadDeletedNotes();
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _onDataChanged() {
    if (_isDisposed) return;
    _loadDeletedNotes();
  }

  String? get _currentUserId => _driveService.currentUser?.id;

  void _loadDeletedNotes() {
    if (_isDisposed) return;

    // When signed out, show all deleted notes; when signed in, scope by user.
    final userId = _currentUserId;
    _deletedNotes = (userId == null ? _noteService.deletedNotes : _noteService.deletedNotesForUser(userId))
      ..sort((a, b) {
        final aDate = a.deletedAt ?? a.updatedAt;
        final bDate = b.deletedAt ?? b.updatedAt;
        return bDate.compareTo(aDate);
      });
    notifyListeners();
  }

  Future<void> restoreNote(Note note) async {
    try {
      if (note.driveFileId != null && _driveService.isSignedIn) {
        // If we have a Drive file ID and signed in, use Drive-integrated method
        await _noteService.restoreNoteFromTrashWithDriveSync(note.id);
      } else {
        // Otherwise, just restore locally
        await _noteService.restoreNoteFromTrash(note.id);
      }
    } catch (e) {
      _logger.e('Failed to restore note: $e');
      rethrow;
    }
  }

  Future<void> deleteNoteForever(Note note) async {
    try {
      if (note.driveFileId != null && _driveService.isSignedIn) {
        // If we have a Drive file ID and signed in, use Drive-integrated method
        await _noteService.permanentDeleteNoteWithDriveSync(note.id);
      } else {
        // Otherwise, just delete locally
        await _noteService.permanentDeleteNote(note.id);
      }
    } catch (e) {
      _logger.e('Failed to permanently delete note: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _noteService.removeListener(_onDataChanged);
    super.dispose();
  }
}
