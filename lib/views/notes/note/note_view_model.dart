import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/notes/custom_tag_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/note.dart';
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

  Note? _currentNote;
  bool _isNewNote = true;
  bool _hasUnsavedChanges = false;
  Timer? _autoSaveTimer;
  bool _isHandlingKeyEvent = false;
  bool _isReadOnly = false;

  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  bool isBulletList = false;
  bool isNumberedList = false;
  bool isQuote = false;
  bool isCodeBlock = false;

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
    // Create a custom document with proper formatting inheritance
    final document = Document()..insert(0, '\n');

    quillController = QuillController(document: document, selection: const TextSelection.collapsed(offset: 0));
    quillController.readOnly = _isReadOnly;

    scrollController = ScrollController();
    focusNode = FocusNode();
    titleController = TextEditingController();

    // Add listeners
    quillController.addListener(_updateToolbarState);
    titleController.addListener(_onTitleChanged);
    quillController.addListener(_onContentChanged);

    // Add keyboard listener for formatting inheritance
    focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (focusNode.hasFocus) {
      // Set up keyboard listener when editor gains focus
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    } else {
      // Remove keyboard listener when editor loses focus
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_isHandlingKeyEvent) return false;

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      _isHandlingKeyEvent = true;

      // Use a microtask to handle the event after the current frame
      Future.microtask(() {
        _handleEnterKey();
        _isHandlingKeyEvent = false;
      });

      return false; // Don't consume the event
    }

    return false;
  }

  void _handleEnterKey() {
    final selection = quillController.selection;
    if (!selection.isValid) return;

    final index = selection.baseOffset;

    // Get the current line's formatting
    final currentLine = _getCurrentLine(index);
    if (currentLine == null) return;

    final currentAttributes = currentLine.style.attributes;

    // Check if we're in a list
    final isInList =
        currentAttributes.containsKey(Attribute.ul.key) ||
        currentAttributes.containsKey(Attribute.ol.key) ||
        currentAttributes.containsKey(Attribute.checked.key);

    if (isInList) {
      // If in a list, let Quill handle it naturally
      return;
    } else {
      // If not in a list, handle formatting inheritance
      _handleFormattingInheritance(index, currentAttributes);
    }
  }

  Node? _getCurrentLine(int index) {
    try {
      final document = quillController.document;
      final lines = document.root.children;

      int currentOffset = 0;
      for (final line in lines) {
        final lineLength = line.length;
        if (currentOffset <= index && index <= currentOffset + lineLength) {
          return line;
        }
        currentOffset += lineLength;
      }
    } catch (e) {
      // Handle any errors gracefully
    }
    return null;
  }

  void _handleFormattingInheritance(int index, Map<String, Attribute> currentAttributes) {
    // Create a map of text-level formatting to inherit
    final textFormatting = <String, Attribute>{};

    // Only inherit text-level formatting, not block-level
    if (currentAttributes.containsKey(Attribute.bold.key)) {
      textFormatting[Attribute.bold.key] = Attribute.bold;
    }
    if (currentAttributes.containsKey(Attribute.italic.key)) {
      textFormatting[Attribute.italic.key] = Attribute.italic;
    }
    if (currentAttributes.containsKey(Attribute.underline.key)) {
      textFormatting[Attribute.underline.key] = Attribute.underline;
    }
    if (currentAttributes.containsKey(Attribute.strikeThrough.key)) {
      textFormatting[Attribute.strikeThrough.key] = Attribute.strikeThrough;
    }
    if (currentAttributes.containsKey(Attribute.color.key)) {
      textFormatting[Attribute.color.key] = currentAttributes[Attribute.color.key]!;
    }
    if (currentAttributes.containsKey(Attribute.background.key)) {
      textFormatting[Attribute.background.key] = currentAttributes[Attribute.background.key]!;
    }

    // Insert newline and let Quill handle the rest naturally
    quillController.document.insert(index, '\n');

    // Apply inherited formatting if any
    if (textFormatting.isNotEmpty) {
      // Apply the formatting attributes to the new line
      for (final attribute in textFormatting.values) {
        quillController.formatSelection(attribute);
      }
    }
  }

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
    if (_currentNote != null) {
      _logger.d('Note detail action: load note content id=${_currentNote!.id} title="${_currentNote!.title}"');
      titleController.text = _currentNote!.title;

      try {
        final jsonData = jsonDecode(_currentNote!.contentJson);
        List<dynamic> ops;
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('ops')) {
          ops = jsonData['ops'] as List<dynamic>;
        } else if (jsonData is List<dynamic>) {
          ops = jsonData;
        } else {
          throw Exception('Invalid document format');
        }
        final document = Document.fromJson(ops);
        quillController.document = document;
      } catch (e) {
        _logger.e('Note detail action: failed to parse note content id=${_currentNote!.id} error=$e');
        final emptyDoc = jsonDecode('[{"insert":"\\n"}]');
        quillController.document = Document.fromJson(emptyDoc);
      }

      _hasUnsavedChanges = false;
      notifyListeners();
    }
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

  void updateMoodTags(List<String> moodTagIds) {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;
      _currentNote!.setMoodTags(moodTagIds);
      _logger.d('Note detail action: update mood tags id=${_currentNote!.id} tags=$moodTagIds');
      notifyListeners();
    }
  }

  void updateActivityTags(List<String> activityTagIds) {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;
      _currentNote!.setActivityTags(activityTagIds);
      _logger.d('Note detail action: update activity tags id=${_currentNote!.id} tags=$activityTagIds');
      notifyListeners();
    }
  }

  void updateTimeTags(List<String> timeTagIds) {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;
      _currentNote!.setTimeTags(timeTagIds);
      _logger.d('Note detail action: update time tags id=${_currentNote!.id} tags=$timeTagIds');
      notifyListeners();
    }
  }

  void updatePersonalGrowthTags(List<String> personalGrowthTagIds) {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;
      _currentNote!.setPersonalGrowthTags(personalGrowthTagIds);
      _logger.d('Note detail action: update growth tags id=${_currentNote!.id} tags=$personalGrowthTagIds');
      notifyListeners();
    }
  }

  Future<void> updateCustomTags(List<String> customTags, BuildContext context) async {
    if (_currentNote != null) {
      _hasUnsavedChanges = true;
      _logger.d('Note detail action: update custom tags id=${_currentNote!.id} tags=$customTags');

      // Create or get custom tags and collect their IDs
      final List<int> customTagIds = [];

      for (final tagName in customTags) {
        try {
          // Create or get the custom tag
          final customTag = await _customTagService.createOrGetCustomTag(tagName);
          customTagIds.add(customTag.id);
        } catch (e) {
          _logger.e('Note detail action: failed to create custom tag "$tagName" error=$e');
          if (context.mounted) {
            NmToast.error(context, 'Failed to create tag "$tagName"');
          }
        }
      }

      // Update the note with the custom tag IDs
      _currentNote!.setCustomTags(customTagIds);
      _logger.d('Note detail action: set custom tag ids id=${_currentNote!.id} tags=$customTagIds');
      notifyListeners();
    }
  }

  Future<void> saveNote() async {
    if (_currentNote != null) {
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

          // Now update the note with all tag information (moodTags, activityTags, timeTags, personalGrowthTags)
          // This ensures all tag types are properly saved
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
        // Handle error silently or show user feedback
      }
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

  void _updateToolbarState() {
    final selection = quillController.selection;
    if (selection.isValid) {
      try {
        final document = quillController.document;
        if (document.root.children.isNotEmpty) {
          final line = document.root.children.first;
          final attributes = line.style.attributes;

          isBold = attributes.containsKey(Attribute.bold.key);
          isItalic = attributes.containsKey(Attribute.italic.key);
          isUnderline = attributes.containsKey(Attribute.underline.key);
          isBulletList = attributes.containsKey(Attribute.ul.key);
          isNumberedList = attributes.containsKey(Attribute.ol.key);
          isQuote = attributes.containsKey(Attribute.blockQuote.key);
          isCodeBlock = attributes.containsKey(Attribute.codeBlock.key);

          notifyListeners();
        }
      } catch (e) {
        _resetAllFormattingStates();
      }
    }
  }

  void _resetAllFormattingStates() {
    isBold = false;
    isItalic = false;
    isUnderline = false;
    isBulletList = false;
    isNumberedList = false;
    isQuote = false;
    isCodeBlock = false;
    notifyListeners();
  }

  void toggleBold() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.bold);
      _updateToolbarState();
    }
    isBold = selection.isValid;
  }

  void toggleItalic() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.italic);
      _updateToolbarState();
    }
  }

  void toggleUnderline() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.underline);
      _updateToolbarState();
    }
  }

  void toggleBulletList() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.ul);
      _updateToolbarState();
    }
  }

  void toggleNumberedList() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.ol);
      _updateToolbarState();
    }
  }

  void toggleQuote() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.blockQuote);
      _updateToolbarState();
    }
  }

  void toggleCodeBlock() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.codeBlock);
      _updateToolbarState();
    }
  }

  void clearAllFormatting() {
    final selection = quillController.selection;
    if (selection.isValid) {
      quillController.formatSelection(Attribute.clone(Attribute.background, null));
      quillController.formatSelection(Attribute.clone(Attribute.color, null));
      quillController.formatSelection(Attribute.clone(Attribute.font, null));
      quillController.formatSelection(Attribute.clone(Attribute.size, null));
      quillController.formatSelection(Attribute.clone(Attribute.bold, null));
      quillController.formatSelection(Attribute.clone(Attribute.italic, null));
      quillController.formatSelection(Attribute.clone(Attribute.underline, null));
      quillController.formatSelection(Attribute.clone(Attribute.strikeThrough, null));
      quillController.formatSelection(Attribute.clone(Attribute.link, null));
      quillController.formatSelection(Attribute.clone(Attribute.blockQuote, null));
      quillController.formatSelection(Attribute.clone(Attribute.codeBlock, null));
      quillController.formatSelection(Attribute.clone(Attribute.list, null));
      quillController.formatSelection(Attribute.clone(Attribute.align, null));
      quillController.formatSelection(Attribute.clone(Attribute.direction, null));
      quillController.formatSelection(Attribute.clone(Attribute.indent, null));
      quillController.formatSelection(Attribute.clone(Attribute.header, null));

      _resetAllFormattingStates();
    }
  }

  @override
  void dispose() {
    // Cancel auto-save timer first
    _autoSaveTimer?.cancel();

    // Remove keyboard listener
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    focusNode.removeListener(_onFocusChanged);

    // Only save if there are unsaved changes and we're not disposing
    if (_hasUnsavedChanges && !disposed) {
      // Use a microtask to avoid calling during disposal
      Future.microtask(() => autoSave());
    }

    quillController.removeListener(_updateToolbarState);
    quillController.removeListener(_onContentChanged);
    titleController.removeListener(_onTitleChanged);

    quillController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    titleController.dispose();
    super.dispose();
  }
}
