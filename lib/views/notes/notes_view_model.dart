import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/google_drive_sync_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/models/note.dart';

class NotesViewModel extends BaseViewModel {
  static NotesViewModel? _instance;
  static NotesViewModel? get instance => _instance;

  final NoteService _noteService = ServiceLocator().noteService;
  final GoogleDriveSyncService _syncService = ServiceLocator().googleDriveSyncService;
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final Logger _logger = Logger();

  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isDisposed = false;
  late ScrollController _scrollController;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  ScrollController get scrollController => _scrollController;

  NotesViewModel() {
    _instance = this;
    _scrollController = ScrollController();
    Future.microtask(() => _initialize());
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Clean up any notes that have been in the trash longer than 30 days.
      await _noteService.purgeExpiredDeletedNotes();

      // Add listener for automatic refresh
      _noteService.addListener(_onDataChanged);

      _loadNotes();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  String? get _currentUserId => _driveService.currentUser?.id;

  void _loadNotes() {
    if (_isDisposed) return;

    // When signed out, show all local notes; when signed in, scope by user.
    final userId = _currentUserId;
    _notes = userId == null ? _noteService.notes : _noteService.notesForUser(userId);
    _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _isLoading = false;
    notifyListeners();
  }

  void _onDataChanged() {
    // Only refresh if not disposed
    if (!_isDisposed) {
      _loadNotes();
    }
  }

  Future<void> refreshNotes() async {
    if (_isDisposed) return;

    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _loadNotes();
  }

  void createNewNote(BuildContext context) {
    context.push('/note').then((_) {
      // Refresh notes when returning from creating a new note
      _loadNotes();
    });
  }

  void openNote(BuildContext context, Note note) {
    context.push('/note?title=${Uri.encodeComponent(note.title)}').then((_) {
      // Refresh notes when returning from editing a note
      _loadNotes();
    });
  }

  void showNoteOptions(BuildContext context, Note note) {
    showModalBottomSheet(context: context, builder: (context) => _buildNoteOptionsSheet(context, note));
  }

  Widget _buildNoteOptionsSheet(BuildContext context, Note note) => Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            note.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: note.isFavorite ? Colors.red : null,
          ),
          title: Text(note.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
          onTap: () {
            Navigator.pop(context);
            toggleFavorite(note);
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit'),
          onTap: () {
            Navigator.pop(context);
            openNote(context, note);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Delete', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _deleteNote(context, note);
          },
        ),
      ],
    ),
  );

  Future<void> toggleFavorite(Note note) async {
    note.toggleFavorite();
    await _noteService.updateNote(note);
    // No need to manually refresh - listener will handle it
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (note.driveFileId != null && _driveService.isSignedIn) {
          // If we have a Drive file ID and signed in, use Drive-integrated method
          await _noteService.softDeleteNoteWithDriveSync(note.id);
        } else {
          // Otherwise, just delete locally
          await _noteService.softDeleteNote(note.id);
        }
        // No need to manually refresh - listener will handle it
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note moved to Recently Deleted. It will be permanently removed after 30 days.'),
            ),
          );
        }
      } catch (e) {
        _logger.e('Failed to delete note: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// Syncs data with Google Drive
  Future<void> syncWithGoogleDrive(BuildContext context) async {
    // Use the dedicated sync service with loading overlay and toast
    final result = await _syncService.syncWithLoadingOverlay(context);

    // Show result toast
    _syncService.showSyncResultToast(context, result);

    // Refresh notes after sync to show any changes
    if (result.isSuccess) {
      await refreshNotes();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _noteService.removeListener(_onDataChanged);
    _scrollController.dispose();
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }
}
