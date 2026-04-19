import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/core/repository/interfaces/folder_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/core/services/note_service.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/folder.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/views/search/search_view_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Stubs
// ═══════════════════════════════════════════════════════════════════════════

String _quill(String plain) => '{"ops":[{"insert":"${plain.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}\\n"}]}';

class _SearchTestNoteRepo implements INoteRepository {
  _SearchTestNoteRepo(List<Note> notes) : _notes = List<Note>.from(notes);

  final List<Note> _notes;

  @override
  List<Note> getActiveNotes() => _notes.where((n) => !n.isDeleted).toList();

  @override
  List<Note> getActiveNotesForUser(String? userId) {
    if (userId == null) return getActiveNotes();
    return getActiveNotes().where((n) => n.userId == null || n.userId == userId).toList();
  }

  @override
  Future<void> initialize() async {}

  @override
  List<Note> getAllNotes() => _notes.toList();

  @override
  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Note? getNoteBySync(String syncId) {
    for (final n in _notes) {
      if (n.syncId == syncId) return n;
    }
    return null;
  }

  @override
  List<Note> searchNotes(String query) => [];

  @override
  List<Note> searchNotesForUser(String? userId, String query) => [];

  @override
  List<Note> getNotesByFolder(String folderId) => [];

  @override
  List<Note> getNotesByFolderForUser(String? userId, String folderId) => [];

  @override
  List<Note> getFavoriteNotes() => [];

  @override
  List<Note> getFavoriteNotesForUser(String? userId) => [];

  @override
  List<Note> getArchivedNotes() => [];

  @override
  List<Note> getArchivedNotesForUser(String? userId) => [];

  @override
  List<Note> getNotesByTag(String tag) => [];

  @override
  List<String> getAllTags() => [];

  @override
  List<Note> getDeletedNotes() => [];

  @override
  List<Note> getDeletedNotesForUser(String? userId) => [];

  @override
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) async => throw UnimplementedError();

  @override
  Future<Note> createNoteWithTimestamps({
    String? syncId,
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isFavorite = false,
    bool isArchived = false,
    bool isDeleted = false,
    DateTime? deletedAt,
    String? userId,
    List<String>? moodTags,
    List<String>? activityTags,
    List<String>? timeTags,
    List<String>? personalGrowthTags,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateNote(Note note, {bool preserveTimestamps = false}) async {}

  @override
  Future<void> deleteNote(int id) async {}

  @override
  int get totalNotes => _notes.length;

  @override
  int get totalWords => 0;

  @override
  int get totalCharacters => 0;

  @override
  void addListener(Function() listener) {}

  @override
  void removeListener(Function() listener) {}

  @override
  void dispose() {}
}

class _SearchTestFolderRepo implements IFolderRepository {
  @override
  Future<void> initialize() async {}

  @override
  List<Folder> getAllFolders() => [];

  @override
  Folder? getFolderById(String folderId) => null;

  @override
  Future<Folder> createFolder({required String name, String? description, String? color}) async =>
      throw UnimplementedError();

  @override
  Future<Folder> createFolderWithTimestamps({
    required String folderId,
    required String name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDefault = false,
    int noteCount = 0,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateFolder(Folder folder) async {}

  @override
  Future<void> deleteFolder(String folderId) async {}

  @override
  Folder? getDefaultFolder() => null;

  @override
  void addListener(Function() listener) {}

  @override
  void removeListener(Function() listener) {}

  @override
  void dispose() {}
}

class _SearchTestCustomTagRepo implements ICustomTagRepository {
  @override
  Future<void> initialize() async {}

  @override
  Future<CustomTag> createCustomTag(String name, {String? color}) async => throw UnimplementedError();

  @override
  CustomTag? getCustomTagById(int id) => null;

  @override
  CustomTag? getCustomTagByName(String name) => null;

  @override
  List<CustomTag> getAllCustomTags() => [];

  @override
  List<CustomTag> getMostUsedCustomTags() => [];

  @override
  List<CustomTag> getCustomTagsSortedByName() => [];

  @override
  List<CustomTag> getNewestCustomTags() => [];

  @override
  List<CustomTag> searchCustomTags(String query) => [];

  @override
  List<CustomTag> getUnusedCustomTags() => [];

  @override
  List<CustomTag> getCustomTagsInUse() => [];

  @override
  Future<void> updateCustomTag(CustomTag customTag) async {}

  @override
  Future<void> deleteCustomTag(int id) async {}

  @override
  Future<void> deleteUnusedCustomTags() async {}

  @override
  Map<String, int> getCustomTagStatistics() => {};

  @override
  bool customTagExists(String name) => false;

  @override
  bool customTagExistsById(int id) => false;

  @override
  List<CustomTag> getCustomTagsByIds(List<int> ids) => [];

  @override
  void addListener(Function() listener) {}

  @override
  void removeListener(Function() listener) {}
}

Note _note({
  required int id,
  String title = 'Note',
  String body = 'body',
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isFavorite = false,
  String? userId,
  List<String> moodTags = const [],
  List<String> activityTags = const [],
  List<String> timeTags = const [],
  List<String> personalGrowthTags = const [],
  List<int> customTagIds = const [],
}) {
  final n = Note(
    title: title,
    contentJson: _quill(body),
    isFavorite: isFavorite,
    userId: userId,
    moodTags: moodTags,
    activityTags: activityTags,
    timeTags: timeTags,
    personalGrowthTags: personalGrowthTags,
    customTagIds: customTagIds,
    createdAt: createdAt ?? DateTime(2024, 1, id),
    updatedAt: updatedAt ?? DateTime(2024, 2, id),
  );
  n.id = id;
  return n;
}

SearchViewModel _vm(_SearchTestNoteRepo repo, {String? Function()? currentUserIdForTest}) => SearchViewModel(
  noteService: NoteService(noteRepository: repo, folderRepository: _SearchTestFolderRepo()),
  customTagService: CustomTagService(customTagRepository: _SearchTestCustomTagRepo()),
  currentUserIdForTest: currentUserIdForTest,
);

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchViewModel text query', () {
    test('matches title case-insensitively', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'Alpha Project', body: 'x'),
        _note(id: 2, title: 'Beta', body: 'y'),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setQuery('  alpha ');
      expect(vm.filteredNotes.map((n) => n.id), [1]);
    });

    test('matches plain text parsed from Quill body', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'T', body: 'hidden treasure here'),
        _note(id: 2, title: 'Other', body: 'nothing'),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setQuery('treasure');
      expect(vm.filteredNotes.map((n) => n.id), [1]);
    });

    test('matches text spanning Quill line breaks', () {
      final noteWithLineBreak = Note(
        title: 'Line break note',
        contentJson: '{"ops":[{"insert":"hello"},{"insert":"\\n"},{"insert":"world"},{"insert":"\\n"}]}',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      )..id = 1;
      final repo = _SearchTestNoteRepo([
        noteWithLineBreak,
        _note(id: 2, title: 'Other', body: 'hello everyone'),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setQuery('hello world');
      expect(vm.filteredNotes.map((n) => n.id), [1]);
    });

    test('empty and whitespace-only query does not filter by text', () {
      final repo = _SearchTestNoteRepo([_note(id: 1), _note(id: 2)]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setQuery('   ');
      expect(vm.filteredNotes.length, 2);
    });
  });

  group('SearchViewModel clear filters', () {
    test('clearAllFilters clears query, tag selections, and favorites', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'x', moodTags: const ['happy']),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..setQuery('x')
        ..toggleMoodTag('happy')
        ..toggleFavoritesOnly();
      expect(vm.hasActiveFilters, isTrue);
      vm.clearAllFilters();
      expect(vm.query, isEmpty);
      expect(vm.showFavoritesOnly, isFalse);
      expect(vm.selectedMoodIds, isEmpty);
      expect(vm.hasActiveFilters, isFalse);
      expect(vm.filteredNotes.length, 1);
    });

    test('clearQuery clears only search text', () {
      final repo = _SearchTestNoteRepo([_note(id: 1)]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..setQuery('nope')
        ..toggleMoodTag('happy');
      vm.clearQuery();
      expect(vm.query, isEmpty);
      expect(vm.selectedMoodIds, contains('happy'));
      expect(vm.hasActiveFilters, isTrue);
    });
  });

  group('SearchViewModel tag filters', () {
    test('OR within mood category: note matches if it has any selected mood', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, moodTags: const ['happy']),
        _note(id: 2, moodTags: const ['sad']),
        _note(id: 3, moodTags: const ['angry']),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..toggleMoodTag('happy')
        ..toggleMoodTag('sad');
      expect(vm.filteredNotes.map((n) => n.id).toSet(), {1, 2});
    });

    test('AND across categories: note must satisfy mood and activity selections', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, moodTags: const ['happy'], activityTags: const ['run']),
        _note(id: 2, moodTags: const ['happy'], activityTags: const ['read']),
        _note(id: 3, moodTags: const ['sad'], activityTags: const ['run']),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..toggleMoodTag('happy')
        ..toggleActivityTag('run');
      expect(vm.filteredNotes.map((n) => n.id), [1]);
    });

    test('AND includes time and personal growth when multiple categories active', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, moodTags: const ['calm'], timeTags: const ['morning'], personalGrowthTags: const ['goal']),
        _note(id: 2, moodTags: const ['calm'], timeTags: const ['evening'], personalGrowthTags: const ['goal']),
        _note(id: 3, moodTags: const ['calm'], timeTags: const ['morning'], personalGrowthTags: const ['habit']),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..toggleMoodTag('calm')
        ..toggleTimeTag('morning')
        ..toggleGrowthTag('goal');
      expect(vm.filteredNotes.map((n) => n.id), [1]);
    });

    test('custom tag ids use OR within the custom-tag category', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, customTagIds: const [10]),
        _note(id: 2, customTagIds: const [20]),
        _note(id: 3, customTagIds: const [99]),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..toggleCustomTag(10)
        ..toggleCustomTag(20);
      expect(vm.filteredNotes.map((n) => n.id).toSet(), {1, 2});
    });
  });

  group('SearchViewModel favorites', () {
    test('showFavoritesOnly keeps only favourited notes', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, isFavorite: true),
        _note(id: 2, isFavorite: false),
        _note(id: 3, isFavorite: true),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..toggleFavoritesOnly();
      // Order follows default newestFirst (createdAt uses id in _note helper).
      expect(vm.filteredNotes.map((n) => n.id).toSet(), {1, 3});
    });
  });

  group('SearchViewModel sort order', () {
    test('newestFirst sorts by createdAt descending', () {
      final t1 = DateTime(2020, 1, 1);
      final t2 = DateTime(2021, 1, 1);
      final t3 = DateTime(2019, 1, 1);
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'a', createdAt: t1, updatedAt: t1),
        _note(id: 2, title: 'b', createdAt: t2, updatedAt: t2),
        _note(id: 3, title: 'c', createdAt: t3, updatedAt: t3),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setSortOrder(SearchSortOrder.newestFirst);
      expect(vm.filteredNotes.map((n) => n.id), [2, 1, 3]);
    });

    test('oldestFirst sorts by createdAt ascending', () {
      final t1 = DateTime(2020, 1, 1);
      final t2 = DateTime(2021, 1, 1);
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'a', createdAt: t2, updatedAt: t2),
        _note(id: 2, title: 'b', createdAt: t1, updatedAt: t1),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setSortOrder(SearchSortOrder.oldestFirst);
      expect(vm.filteredNotes.map((n) => n.id), [2, 1]);
    });

    test('alphabetical is case-insensitive on title', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'banana'),
        _note(id: 2, title: 'Apple'),
        _note(id: 3, title: 'citrus'),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setSortOrder(SearchSortOrder.alphabetical);
      expect(vm.filteredNotes.map((n) => n.title), ['Apple', 'banana', 'citrus']);
    });

    test('recentlyUpdated sorts by updatedAt descending', () {
      final u1 = DateTime(2024, 6, 1);
      final u2 = DateTime(2024, 8, 1);
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'a', createdAt: DateTime(2020), updatedAt: u1),
        _note(id: 2, title: 'b', createdAt: DateTime(2020), updatedAt: u2),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setSortOrder(SearchSortOrder.recentlyUpdated);
      expect(vm.filteredNotes.map((n) => n.id), [2, 1]);
    });
  });

  group('SearchViewModel source notes scope', () {
    test('uses notesForUser when a signed-in user id is resolved', () {
      final repo = _SearchTestNoteRepo([
        _note(id: 1, title: 'mine', userId: 'u1'),
        _note(id: 2, title: 'other', userId: 'u2'),
        // Anonymous note still in scope for u1; title must match query "e".
        _note(id: 3, title: 'extra', userId: null),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => 'u1')..setQuery('e');
      final ids = vm.filteredNotes.map((n) => n.id).toSet();
      expect(ids.contains(2), false);
      expect(ids, containsAll([1, 3]));
    });
  });

  group('SearchViewModel buildHighlightSpans', () {
    test('returns a single span when query is empty', () {
      final repo = _SearchTestNoteRepo([_note(id: 1)]);
      final vm = _vm(repo, currentUserIdForTest: () => null);
      const base = TextStyle(color: Color(0xff000000));
      const hi = TextStyle(fontWeight: FontWeight.bold);
      final spans = vm.buildHighlightSpans('Hello world', base, hi);
      expect(spans.length, 1);
      expect(spans[0].text, 'Hello world');
    });

    test('wraps case-insensitive matches in highlight style', () {
      final repo = _SearchTestNoteRepo([_note(id: 1)]);
      final vm = _vm(repo, currentUserIdForTest: () => null)..setQuery('Lo Wo');
      const base = TextStyle();
      const hi = TextStyle(fontWeight: FontWeight.bold);
      final spans = vm.buildHighlightSpans('Hello World', base, hi);
      expect(spans.length, 3);
      expect(spans[0].text, 'Hel');
      expect(spans[1].text, 'lo Wo');
      expect(spans[1].style, hi);
      expect(spans[2].text, 'rld');
    });
  });

  group('SearchViewModel combined filters', () {
    test('applies text, tag AND, favorites, then sort', () {
      final repo = _SearchTestNoteRepo([
        _note(
          id: 1,
          title: 'Plan alpha',
          body: 'alpha details',
          moodTags: const ['happy'],
          activityTags: const ['run'],
          isFavorite: true,
          createdAt: DateTime(2022, 1, 1),
          updatedAt: DateTime(2022, 1, 1),
        ),
        _note(
          id: 2,
          title: 'Alpha draft',
          body: 'beta',
          moodTags: const ['happy'],
          activityTags: const ['run'],
          isFavorite: false,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 1),
        ),
        _note(
          id: 3,
          title: 'Alpha old',
          body: 'gamma',
          moodTags: const ['sad'],
          activityTags: const ['run'],
          isFavorite: true,
          createdAt: DateTime(2021, 1, 1),
          updatedAt: DateTime(2021, 1, 1),
        ),
      ]);
      final vm = _vm(repo, currentUserIdForTest: () => null)
        ..setQuery('alpha')
        ..toggleMoodTag('happy')
        ..toggleActivityTag('run')
        ..toggleFavoritesOnly()
        ..setSortOrder(SearchSortOrder.newestFirst);
      expect(vm.filteredNotes.map((n) => n.id), [1]);
    });
  });
}
