import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/analytics_repository.dart';
import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/models/note.dart';

class _FakeNoteRepository implements INoteRepository {
  _FakeNoteRepository(this._notes);

  final List<Note> _notes;

  @override
  List<Note> getAllNotes() => List<Note>.from(_notes);

  @override
  Future<void> initialize() async {}

  @override
  List<Note> getActiveNotes() => _notes.where((n) => !n.isDeleted).toList();

  @override
  List<Note> getActiveNotesForUser(String? userId) => getActiveNotes();

  @override
  Note? getNoteById(int id) {
    for (final note in _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Note? getNoteBySync(String syncId) => null;

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
  List<Note> getDeletedNotes() => _notes.where((n) => n.isDeleted).toList();

  @override
  List<Note> getDeletedNotesForUser(String? userId) => getDeletedNotes();

  @override
  Future<Note> createNote({
    String? title,
    String? contentJson,
    String? folderId,
    List<int> customTagIds = const [],
    String? userId,
  }) async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

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

Note _note({
  required int id,
  required DateTime createdAt,
  List<String> moodTags = const [],
  List<String> activityTags = const [],
  List<String> timeTags = const [],
  List<String> personalGrowthTags = const [],
}) {
  final note = Note(
    title: 'n$id',
    contentJson: '{"ops":[{"insert":"body\\n"}]}',
    createdAt: createdAt,
    updatedAt: createdAt,
    moodTags: moodTags,
    activityTags: activityTags,
    timeTags: timeTags,
    personalGrowthTags: personalGrowthTags,
  );
  note.id = id;
  return note;
}

void main() {
  group('AnalyticsRepository', () {
    test('getEntriesPerDay aggregates counts by date', () {
      final repo = AnalyticsRepository(
        noteRepository: _FakeNoteRepository([
          _note(id: 1, createdAt: DateTime(2026, 4, 1, 8)),
          _note(id: 2, createdAt: DateTime(2026, 4, 1, 22)),
          _note(id: 3, createdAt: DateTime(2026, 4, 2, 9)),
        ]),
      );

      final perDay = repo.getEntriesPerDay();
      expect(perDay[DateTime(2026, 4, 1)], 2);
      expect(perDay[DateTime(2026, 4, 2)], 1);
    });

    test('getAverageSentimentPerDay averages only known mood tags', () {
      final repo = AnalyticsRepository(
        noteRepository: _FakeNoteRepository([
          _note(id: 1, createdAt: DateTime(2026, 4, 1), moodTags: const ['happy']),
          _note(id: 2, createdAt: DateTime(2026, 4, 1), moodTags: const ['sad', 'unknown']),
          _note(id: 3, createdAt: DateTime(2026, 4, 2), moodTags: const ['unknown']),
        ]),
      );

      final sentiment = repo.getAverageSentimentPerDay();
      expect(sentiment.length, 1);
      expect(sentiment[DateTime(2026, 4, 1)], closeTo(0.0, 0.000001));
      expect(sentiment.containsKey(DateTime(2026, 4, 2)), isFalse);
    });

    test('getTagFrequency counts every tag category', () {
      final repo = AnalyticsRepository(
        noteRepository: _FakeNoteRepository([
          _note(
            id: 1,
            createdAt: DateTime(2026, 4, 1),
            moodTags: const ['happy'],
            activityTags: const ['work'],
            timeTags: const ['morning'],
            personalGrowthTags: const ['learning'],
          ),
          _note(
            id: 2,
            createdAt: DateTime(2026, 4, 2),
            moodTags: const ['happy'],
            activityTags: const ['work'],
            timeTags: const ['night'],
            personalGrowthTags: const ['goals'],
          ),
        ]),
      );

      final freq = repo.getTagFrequency();
      expect(freq['happy'], 2);
      expect(freq['work'], 2);
      expect(freq['morning'], 1);
      expect(freq['night'], 1);
      expect(freq['learning'], 1);
      expect(freq['goals'], 1);
    });
  });
}
