import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noteminds/core/base/base_view_model.dart';
import 'package:noteminds/core/di/service_locator.dart';
import 'package:noteminds/core/services/note_service.dart';
import 'package:noteminds/models/note.dart';

class NotesViewModel extends BaseViewModel {
  static NotesViewModel? _instance;
  static NotesViewModel? get instance => _instance;

  final NoteService _noteService = ServiceLocator().noteService;
  // Google Drive actions moved to Setting screen

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

  void _loadNotes() {
    if (_isDisposed) return;

    _notes = _noteService.notes;
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
      refreshNotes();
    });
  }

  void openNote(BuildContext context, Note note) {
    context.push('/note?title=${Uri.encodeComponent(note.title)}').then((_) {
      // Refresh notes when returning from editing a note
      refreshNotes();
    });
  }

  void showSearch(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search coming soon!')));
  }

  void showMenu(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Settings for backup/restore')));
  }

  void openSettings(BuildContext context) {
    context.push('/setting');
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
      await _noteService.deleteNote(note.id);
      // No need to manually refresh - listener will handle it
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
