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
  });
}

/// Stub for NoteService - minimal implementation for testing ChatSourceService.
class _StubNoteService implements NoteService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
