import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/chat/chat_source_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/note.dart';

void main() {
  group('ChatSourceService', () {
    late ChatSourceService service;
    late _StubNoteService stubNoteService;

    setUp(() {
      stubNoteService = _StubNoteService();
      service = ChatSourceService(noteService: stubNoteService);
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
  });
}

/// Stub for NoteService - minimal implementation for testing ChatSourceService.
class _StubNoteService implements NoteService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
