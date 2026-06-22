import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/notes/custom_tag_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/views/notes/note/note_document_codec.dart';
import 'package:trovara/views/notes/note/note_editor_key_handler.dart';
import 'package:trovara/widgets/nm_toast.dart';

class NoteViewModel extends BaseViewModel {
  final String? title;
  final int? noteId;
  final NoteService _noteService = ServiceLocator().noteService;
  final CustomTagService _customTagService = ServiceLocator().customTagService;
  final GoogleDriveService _driveService = ServiceLocator().googleDriveService;
  final Logger _logger = Logger();

  late QuillController quillController;
  late ScrollController scrollController;
  late FocusNode focusNode;
  late TextEditingController titleController;
  late NoteEditorKeyHandler _keyHandler;

  Note? _currentNote;
  bool _isNewNote = true;
  bool _hasUnsavedChanges = false;
  Timer? _autoSaveTimer;
  bool _isReadOnly = false;

  Note? get currentNote => _currentNote;
  bool get isNewNote => _isNewNote;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isReadOnly => _isReadOnly;

  NoteViewModel({this.title, this.noteId, bool isReadOnly = false}) {
    _isReadOnly = isReadOnly;
    _initializeControllers();
    _initializeNote();
    _startAutoSaveTimer();
    _logger.d('Note detail init (title="${title ?? ''}")');
  }

  void _startAutoSaveTimer() {
    _logger.d('Note detail action: start auto-save timer');
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        autoSave();
      }
    });
  }

  void _initializeControllers() {
    final document = Document()..insert(0, '\n');
    quillController = QuillController(document: document, selection: const TextSelection.collapsed(offset: 0));
    quillController.readOnly = _isReadOnly;

    scrollController = ScrollController();
    focusNode = FocusNode();
    titleController = TextEditingController();
    _keyHandler = NoteEditorKeyHandler(quillController);

    titleController.addListener(_onTitleChanged);
    quillController.addListener(_onContentChanged);
    focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => _keyHandler.onFocusChanged(focusNode.hasFocus);

  Future<void> _initializeNote() async {
    _logger.d('Note detail action: initialize note (title="${title ?? ''}", noteId=$noteId)');
    if (noteId != null) {
      final byId = _noteService.getNote(noteId!);
      if (byId != null) {
        _currentNote = byId;
        _isNewNote = false;
        _logger.d('Note detail action: loaded existing note id=${_currentNote!.id}');
        _loadNoteContent();
        return;
      }
      _logger.d('Note detail action: noteId $noteId not found');
    }

    if (title != null && title!.isNotEmpty) {
      final existingNotes = _noteService.searchNotes(title!);
      if (existingNotes.isNotEmpty) {
        _currentNote = existingNotes.first;
        _isNewNote = false;
        _logger.d('Note detail action: loaded existing note id=${_currentNote!.id}');
        _loadNoteContent();
      } else {
        _logger.d('Note detail action: no note found for title, creating new');
        _createNewNote();
      }
    } else {
      _logger.d('Note detail action: no title provided, creating new note');
      _createNewNote();
    }
  }

  void _createNewNote() {
    _currentNote = Note(title: 'Untitled', contentJson: '[{"insert":"\\n"}]');
    _isNewNote = true;
    _logger.d('Note detail action: create new note (temp id=${_currentNote!.id})');
    _loadNoteContent();
  }

  void _loadNoteContent() {
    if (_currentNote == null) return;
    _logger.d('Note detail action: load note content id=${_currentNote!.id} title="${_currentNote!.title}"');
    titleController.text = _currentNote!.title;
    quillController.document = NoteDocumentCodec.parse(_currentNote!.contentJson);
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void _onTitleChanged() {
    if (_currentNote != null && titleController.text != _currentNote!.title) {
      _hasUnsavedChanges = true;
      _currentNote!.updateTitle(titleController.text);
      _logger.d('Note detail action: title changed id=${_currentNote!.id} title="${_currentNote!.title}"');
      notifyListeners();
    }
  }

  void _onContentChanged() {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;
      _currentNote!.updateContent(jsonEncode(quillController.document.toDelta().toJson()));
      _logger.d(
        'Note detail action: content changed id=${_currentNote!.id} length=${_currentNote!.contentJson.length}',
      );
      notifyListeners();
    }
  }

  void updateMoodTags(List<String> moodTagIds) =>
      _applyTagChange('mood', moodTagIds, () => _currentNote!.setMoodTags(moodTagIds));

  void updateActivityTags(List<String> activityTagIds) =>
      _applyTagChange('activity', activityTagIds, () => _currentNote!.setActivityTags(activityTagIds));

  void updateTimeTags(List<String> timeTagIds) =>
      _applyTagChange('time', timeTagIds, () => _currentNote!.setTimeTags(timeTagIds));

  void updatePersonalGrowthTags(List<String> personalGrowthTagIds) =>
      _applyTagChange('growth', personalGrowthTagIds, () => _currentNote!.setPersonalGrowthTags(personalGrowthTagIds));

  void _applyTagChange(String kind, List<String> ids, VoidCallback mutate) {
    if (_currentNote == null) return;
    _hasUnsavedChanges = true;
    mutate();
    _logger.d('Note detail action: update $kind tags id=${_currentNote!.id} tags=$ids');
    notifyListeners();
  }

  Future<void> updateCustomTags(List<String> customTags, BuildContext context) async {
    if (_currentNote == null) return;
    _hasUnsavedChanges = true;
    _logger.d('Note detail action: update custom tags id=${_currentNote!.id} tags=$customTags');

    final customTagIds = <int>[];
    for (final tagName in customTags) {
      try {
        final customTag = await _customTagService.createOrGetCustomTag(tagName);
        customTagIds.add(customTag.id);
      } catch (e) {
        _logger.e('Note detail action: failed to create custom tag "$tagName" error=$e');
        if (context.mounted) {
          NmToast.error(context, 'Failed to create tag "$tagName"');
        }
      }
    }

    _currentNote!.setCustomTags(customTagIds);
    _logger.d('Note detail action: set custom tag ids id=${_currentNote!.id} tags=$customTagIds');
    notifyListeners();
  }

  Future<void> saveNote() async {
    if (_currentNote == null) return;
    _logger.d('Note detail action: save note id=${_currentNote!.id} isNew=$_isNewNote');
    try {
      if (_isNewNote) {
        _currentNote = await _noteService.createNote(
          title: titleController.text,
          contentJson: jsonEncode(quillController.document.toDelta().toJson()),
          folderId: _currentNote!.folderId,
          customTagIds: _currentNote!.customTagIds,
          userId: _driveService.currentUser?.id,
        );
        // Persist all tag types (mood/activity/time/growth) on the saved note.
        await _noteService.updateNote(_currentNote!);
        _isNewNote = false;
      } else {
        await _noteService.updateNote(_currentNote!);
      }

      _hasUnsavedChanges = false;
      _logger.d('Note detail action: save complete id=${_currentNote!.id}');
      notifyListeners();
    } catch (e) {
      _logger.e('Note detail action: save failed id=${_currentNote?.id} error=$e');
    }
  }

  Future<void> autoSave() async {
    if (_hasUnsavedChanges && !_isReadOnly) {
      _logger.d('Note detail action: auto-save triggered id=${_currentNote?.id}');
      await saveNote();
    }
  }

  void enableEditing() {
    if (!_isReadOnly) return;
    _isReadOnly = false;
    quillController.readOnly = false;
    _logger.d('Note detail action: enable editing id=${_currentNote?.id}');
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _keyHandler.detach();
    focusNode.removeListener(_onFocusChanged);

    // Save any pending changes unless we're already tearing down.
    if (_hasUnsavedChanges && !disposed) {
      Future.microtask(() => autoSave());
    }

    quillController.removeListener(_onContentChanged);
    titleController.removeListener(_onTitleChanged);

    quillController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    titleController.dispose();
    super.dispose();
  }
}
