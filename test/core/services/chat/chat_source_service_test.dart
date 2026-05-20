import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/chat/chat_source_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/note.dart';

void main() {
  group('ChatSourceService', () {
    late ChatSourceService service;
    late _MockNoteService mockNoteService;

    setUp(() {
      mockNoteService = _MockNoteService();
      service = ChatSourceService(noteService: mockNoteService);
    });

    group('isValidSource', () {
      test('returns true for valid note (not deleted, not archived, has valid id)', () {
        final note = Note(id: 1, title: 'Test', contentJson: '');
        expect(service.isValidSource(note), isTrue);
      });

      test('returns false for deleted note', () {
        final note = Note(id: 1, title: 'Test', contentJson: '', isDeleted: true);
        expect(service.isValidSource(note), isFalse);
      });

      test('returns false for archived note', () {
        final note = Note(id: 1, title: 'Test', contentJson: '', isArchived: true);
        expect(service.isValidSource(note), isFalse);
      });

      test('returns false for note with id=0', () {
        final note = Note(id: 0, title: 'Test', contentJson: '');
        expect(service.isValidSource(note), isFalse);
      });
    });

    group('buildSourceNotes', () {
      test('returns empty list when input is empty', () {
        expect(service.buildSourceNotes([], null), isEmpty);
      });

      test('filters out deleted and archived notes', () {
        final notes = [
          Note(id: 1, title: 'Valid', contentJson: ''),
          Note(id: 2, title: 'Deleted', contentJson: '', isDeleted: true),
          Note(id: 3, title: 'Archived', contentJson: '', isArchived: true),
        ];
        final sources = service.buildSourceNotes(notes, null);
        expect(sources.length, 1);
        expect(sources[0].id, 1);
        expect(sources[0].title, 'Valid');
      });

      test('deduplicates sources by id', () {
        final notes = [
          Note(id: 1, title: 'First', contentJson: ''),
          Note(id: 1, title: 'Duplicate', contentJson: ''),
        ];
        final sources = service.buildSourceNotes(notes, null);
        expect(sources.length, 1);
        expect(sources[0].title, 'First');
      });

      test('excludes the specified excludeNoteId', () {
        final notes = [
          Note(id: 1, title: 'Include', contentJson: ''),
          Note(id: 2, title: 'Exclude', contentJson: ''),
        ];
        final sources = service.buildSourceNotes(notes, 2);
        expect(sources.length, 1);
        expect(sources[0].id, 1);
      });

      test('filters out notes with id=0', () {
        final notes = [
          Note(id: 0, title: 'Invalid', contentJson: ''),
          Note(id: 1, title: 'Valid', contentJson: ''),
        ];
        final sources = service.buildSourceNotes(notes, null);
        expect(sources.length, 1);
        expect(sources[0].id, 1);
      });
    });

    group('resolveNoteByTitle', () {
      test('returns null for empty title', () {
        expect(service.resolveNoteByTitle(''), isNull);
        expect(service.resolveNoteByTitle('   '), isNull);
      });

      test('returns null when no matches found', () {
        mockNoteService.searchResults = [];
        expect(service.resolveNoteByTitle('NonexistentNote'), isNull);
      });

      test('returns null if matched note is deleted', () {
        final deletedNote = Note(id: 1, title: 'Deleted', contentJson: '', isDeleted: true);
        mockNoteService.searchResults = [deletedNote];
        expect(service.resolveNoteByTitle('Deleted'), isNull);
      });

      test('returns null if matched note is archived', () {
        final archivedNote = Note(id: 2, title: 'Archived', contentJson: '', isArchived: true);
        mockNoteService.searchResults = [archivedNote];
        expect(service.resolveNoteByTitle('Archived'), isNull);
      });

      test('is case-insensitive and whitespace-trimmed', () {
        final note = Note(id: 3, title: 'My Note', contentJson: '');
        mockNoteService.searchResults = [note];
        expect(service.resolveNoteByTitle(' MY NOTE '), equals(note));
        expect(service.resolveNoteByTitle('my note'), equals(note));
      });
    });

    group('resolveSourceNotes', () {
      test('returns empty list when entity has no sources', () {
        final entity = _MockChatMessageEntity();
        expect(service.resolveSourceNotes(entity, null), isEmpty);
      });

      test('resolves by sourceNoteIds if available', () {
        final note1 = Note(id: 1, title: 'First', contentJson: '');
        final note2 = Note(id: 2, title: 'Second', contentJson: '');
        mockNoteService.notesById = {1: note1, 2: note2};

        final entity = _MockChatMessageEntity(
          sourceNoteIds: [1, 2],
          sourceNoteTitles: ['', ''],
          sourceNoteLabels: ['tag1', 'tag2'],
        );

        final sources = service.resolveSourceNotes(entity, null);
        expect(sources.length, 2);
        expect(sources[0].id, 1);
        expect(sources[0].title, 'First');
        expect(sources[0].label, 'tag1');
        expect(sources[1].id, 2);
        expect(sources[1].title, 'Second');
        expect(sources[1].label, 'tag2');
      });

      test('falls back to sourceNoteTitles if sourceNoteIds empty', () {
        final note = Note(id: 5, title: 'Found Note', contentJson: '');
        mockNoteService.searchResults = [note];

        final entity = _MockChatMessageEntity(
          sourceNoteIds: [],
          sourceNoteTitles: ['Found Note'],
          sourceNoteLabels: [],
        );

        final sources = service.resolveSourceNotes(entity, null);
        expect(sources.length, 1);
        expect(sources[0].id, 5);
      });

      test('skips deleted or archived notes during resolution', () {
        final validNote = Note(id: 1, title: 'Valid', contentJson: '');
        final deletedNote = Note(id: 2, title: 'Deleted', contentJson: '', isDeleted: true);
        mockNoteService.notesById = {1: validNote, 2: deletedNote};

        final entity = _MockChatMessageEntity(
          sourceNoteIds: [1, 2],
          sourceNoteTitles: ['', ''],
        );

        final sources = service.resolveSourceNotes(entity, null);
        expect(sources.length, 1);
        expect(sources[0].id, 1);
      });

      test('prefers stored title over current note title', () {
        final note = Note(id: 3, title: 'Original Title', contentJson: '');
        mockNoteService.notesById = {3: note};

        final entity = _MockChatMessageEntity(
          sourceNoteIds: [3],
          sourceNoteTitles: ['Stored Title'],
        );

        final sources = service.resolveSourceNotes(entity, null);
        expect(sources.length, 1);
        expect(sources[0].title, 'Stored Title');
      });

      test('excludes the specified excludeNoteId', () {
        final note1 = Note(id: 1, title: 'First', contentJson: '');
        final note2 = Note(id: 2, title: 'Second', contentJson: '');
        mockNoteService.notesById = {1: note1, 2: note2};

        final entity = _MockChatMessageEntity(
          sourceNoteIds: [1, 2],
          sourceNoteTitles: ['', ''],
        );

        final sources = service.resolveSourceNotes(entity, 2);
        expect(sources.length, 1);
        expect(sources[0].id, 1);
      });
    });
  });
}

/// Mock for NoteService - supports searchNotes and getNote for testing ChatSourceService.
class _MockNoteService implements NoteService {
  List<Note> searchResults = [];
  Map<int, Note> notesById = {};

  @override
  List<Note> searchNotes(String query) => searchResults;

  Note? getNote(int id) => notesById[id];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock ChatMessageEntity for testing resolveSourceNotes.
class _MockChatMessageEntity extends ChatMessageEntity {
  _MockChatMessageEntity({
    List<int> sourceNoteIds = const [],
    List<String> sourceNoteTitles = const [],
    List<String> sourceNoteLabels = const [],
  }) : super(
    threadId: 1,
    role: 'assistant',
    content: 'test',
    sourceNoteIds: sourceNoteIds,
    sourceNoteTitles: sourceNoteTitles,
    sourceNoteLabels: sourceNoteLabels,
  );
}
