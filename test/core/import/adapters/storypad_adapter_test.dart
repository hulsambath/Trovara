import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/adapters/storypad_adapter.dart';

void main() {
  late StorypadAdapter adapter;

  setUp(() {
    adapter = StorypadAdapter();
  });

  test('sourceName is storypad', () {
    expect(adapter.sourceName, equals('storypad'));
  });

  group('canHandle', () {
    test('accepts Storypad shape with tables and meta_data', () {
      final input = {
        'meta_data': {'app': 'storypad'},
        'tables': {
          'notes': [
            {'id': 1, 'title': 'A', 'content': 'hello'},
          ],
        },
      };

      expect(adapter.canHandle(input), isTrue);
    });

    test('rejects Trovara backup shape even if tables exists', () {
      final input = {
        'notes': [],
        'tables': {},
        'meta_data': {'app': 'storypad'},
      };

      expect(adapter.canHandle(input), isFalse);
    });

    test('rejects payload without tables', () {
      expect(adapter.canHandle({'meta_data': {}}), isFalse);
    });
  });

  group('parse', () {
    test('parses notes and resolves folder by folder_id', () async {
      final input = {
        'meta_data': {'app': 'storypad'},
        'tables': {
          'folders': [
            {'id': 'f1', 'name': 'Work'},
          ],
          'notes': [
            {
              'id': 'n1',
              'title': 'Plan',
              'content': '{"ops":[{"insert":"Hello world\\n"}]}',
              'folder_id': 'f1',
              'created_at': '2026-03-20T08:00:00Z',
              'updated_at': '2026-03-21T08:00:00Z',
            },
          ],
        },
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(1));
      expect(notes.first.title, equals('Plan'));
      expect(notes.first.markdownContent, equals('Hello world'));
      expect(notes.first.folderId, equals('storypad_folder_f1'));
      expect(notes.first.createdAt, isNotNull);
      expect(notes.first.updatedAt, isNotNull);
    });

    test('uses fallback title and default folder when data missing', () async {
      final input = {
        'version': 1,
        'tables': {
          'notes': [
            {'content': 'raw text body'},
          ],
        },
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(1));
      expect(notes.first.title, equals('Imported note 1'));
      expect(notes.first.markdownContent, equals('raw text body'));
      expect(notes.first.folderId, isNull);
    });

    test('resolves folder by folder_name and slugifies unknown names', () async {
      final input = {
        'metaData': {'app': 'storypad'},
        'tables': {
          'collections': [
            {'id': 'abc', 'name': 'My Collection'},
          ],
          'notes': [
            {'title': 'Known folder', 'body': 'A', 'folder_name': 'My Collection'},
            {'title': 'Unknown folder', 'body': 'B', 'folder_name': 'Travel Notes'},
          ],
        },
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(2));
      expect(notes[0].folderId, equals('storypad_folder_abc'));
      expect(notes[1].folderId, equals('storypad_travel_notes'));
    });

    test('supports list-based tables shape', () async {
      final input = {
        'meta_data': {'app': 'storypad'},
        'tables': [
          {
            'name': 'folders',
            'rows': [
              {'id': '7', 'name': 'Ideas'},
            ],
          },
          {
            'name': 'notes',
            'rows': [
              {'title': 'Idea', 'text': 'Ship it', 'folder_id': '7'},
            ],
          },
        ],
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(1));
      expect(notes.first.title, equals('Idea'));
      expect(notes.first.folderId, equals('storypad_folder_7'));
    });

    test('selects best notes-like table when multiple tables exist', () async {
      final input = {
        'meta_data': {'app': 'storypad'},
        'tables': {
          'users': [
            {'name': 'alice', 'password': 'secret'},
          ],
          'documents': [
            {'subject': 'Doc title', 'body': 'Doc body'},
          ],
        },
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(1));
      expect(notes.first.title, equals('Doc title'));
      expect(notes.first.markdownContent, equals('Doc body'));
    });

    test('handles epoch timestamps in milliseconds', () async {
      final input = {
        'version': 1,
        'tables': {
          'notes': [
            {'title': 'Time note', 'content': 'Body', 'created_at': 1710960000000, 'updated_at': 1711046400000},
          ],
        },
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(1));
      expect(notes.first.createdAt, isNotNull);
      expect(notes.first.updatedAt, isNotNull);
      expect(notes.first.updatedAt!.isAfter(notes.first.createdAt!), isTrue);
    });

    test('skips malformed note rows instead of throwing', () async {
      final input = {
        'version': 3,
        'tables': {
          'notes': [
            {'title': 'Good', 'content': 'ok'},
            123,
          ],
        },
      };

      final notes = await adapter.parse(input);

      expect(notes, hasLength(1));
      expect(notes.first.title, equals('Good'));
    });
  });
}
