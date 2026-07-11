import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/adapters/storypad_adapter.dart';
import '../../test_support.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────────

Map<String, dynamic> storypadBackup({
  dynamic tables,
  bool withVersion = true,
  bool withMetaData = false,
}) => {
  if (withVersion) 'version': 1,
  if (withMetaData) 'meta_data': {'app': 'storypad'},
  if (tables != null) 'tables': tables,
};

Map<String, dynamic> noteRow({
  String? title,
  dynamic content,
  dynamic createdAt,
  dynamic updatedAt,
  Map<String, dynamic> extra = const {},
}) => {
  if (title != null) 'title': title,
  if (content != null) 'content': content,
  if (createdAt != null) 'created_at': createdAt,
  if (updatedAt != null) 'updated_at': updatedAt,
  ...extra,
};

void main() {
  late StorypadAdapter adapter;

  setUp(() {
    adapter = StorypadAdapter();
  });

  patrolTest('sourceName is storypad', ($) async {
    expect(adapter.sourceName, 'storypad');
  });

  // ── canHandle ──────────────────────────────────────────────────────────────

  group('canHandle', () {
    patrolTest('accepts tables + version', ($) async {
      expect(adapter.canHandle(storypadBackup(tables: {})), isTrue);
    });

    patrolTest('accepts tables + meta_data without version', ($) async {
      expect(adapter.canHandle(storypadBackup(tables: {}, withVersion: false, withMetaData: true)), isTrue);
    });

    patrolTest('accepts camelCase metaData', ($) async {
      expect(
        adapter.canHandle({
          'tables': {},
          'metaData': {'app': 'storypad'},
        }),
        isTrue,
      );
    });

    patrolTest('rejects a Trovara backup (notes key present)', ($) async {
      expect(adapter.canHandle({'tables': {}, 'version': 1, 'notes': []}), isFalse);
    });

    patrolTest('rejects a Trovara backup (folders key present)', ($) async {
      expect(adapter.canHandle({'tables': {}, 'version': 1, 'folders': []}), isFalse);
    });

    patrolTest('rejects a map without tables', ($) async {
      expect(adapter.canHandle({'version': 1}), isFalse);
    });

    patrolTest('rejects tables without version or meta_data', ($) async {
      expect(adapter.canHandle({'tables': {}}), isFalse);
    });

    patrolTest('rejects non-map input', ($) async {
      expect(adapter.canHandle('not a map'), isFalse);
      expect(adapter.canHandle([1, 2, 3]), isFalse);
      expect(adapter.canHandle(null), isFalse);
    });
  });

  // ── parse: notes table detection ───────────────────────────────────────────

  group('parse', () {
    patrolTest('parses a simple notes table', ($) async {
      final input = storypadBackup(
        tables: {
          'notes': [
            noteRow(title: 'First', content: 'Hello world'),
            noteRow(title: 'Second', content: 'More text'),
          ],
        },
      );

      final notes = await adapter.parse(input);
      expect(notes, hasLength(2));
      expect(notes[0].title, 'First');
      expect(notes[0].markdownContent, 'Hello world');
      expect(notes[1].title, 'Second');
    });

    patrolTest('supports list-form tables with name/rows entries', ($) async {
      final input = storypadBackup(
        tables: [
          {
            'name': 'notes',
            'rows': [noteRow(title: 'From list form', content: 'body')],
          },
        ],
      );

      final notes = await adapter.parse(input);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'From list form');
    });

    patrolTest('returns empty for empty tables', ($) async {
      expect(await adapter.parse(storypadBackup(tables: {})), isEmpty);
      expect(await adapter.parse(storypadBackup(tables: [])), isEmpty);
    });

    patrolTest('returns empty for non-map input', ($) async {
      expect(await adapter.parse('nope'), isEmpty);
    });

    patrolTest('ignores tables that do not look like notes (score below threshold)', ($) async {
      final input = storypadBackup(
        tables: {
          'settings': [
            {'key': 'theme', 'value': 'dark'},
          ],
        },
      );
      expect(await adapter.parse(input), isEmpty);
    });

    patrolTest('skips malformed rows without dropping the rest', ($) async {
      final input = storypadBackup(
        tables: {
          'notes': [
            noteRow(title: 'Good', content: 'fine'),
            noteRow(title: 'Bad date', content: 'x', createdAt: 'not-a-date'),
          ],
        },
      );
      final notes = await adapter.parse(input);
      // Unparseable date resolves to null rather than throwing — both survive.
      expect(notes, hasLength(2));
    });
  });

  // ── content conversion ─────────────────────────────────────────────────────

  group('content conversion', () {
    patrolTest('plain text content is kept as-is', ($) async {
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: 'Just plain text')],
          },
        ),
      );
      expect(notes.first.markdownContent, 'Just plain text');
    });

    patrolTest('Quill Delta JSON content is converted to Markdown', ($) async {
      const delta = '[{"insert":"Hello bold","attributes":{"bold":true}},{"insert":"\\n"}]';
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: delta)],
          },
        ),
      );
      expect(notes.first.markdownContent, contains('**'));
    });

    patrolTest('invalid JSON-looking content is treated as plain text', ($) async {
      const notJson = '{this is not json';
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: notJson)],
          },
        ),
      );
      expect(notes.first.markdownContent, notJson);
    });

    patrolTest('null/empty content yields empty markdown', ($) async {
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: '')],
          },
        ),
      );
      expect(notes.first.markdownContent, isEmpty);
    });
  });

  // ── titles & dates ─────────────────────────────────────────────────────────

  group('titles and dates', () {
    patrolTest('untitled rows get a positional fallback title', ($) async {
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(content: 'no title here'), noteRow(content: 'me neither')],
          },
        ),
      );
      expect(notes[0].title, 'Imported note 1');
      expect(notes[1].title, 'Imported note 2');
    });

    patrolTest('parses ISO-8601 date strings', ($) async {
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: 'x', createdAt: '2024-03-01T10:00:00Z')],
          },
        ),
      );
      expect(notes.first.createdAt, DateTime.parse('2024-03-01T10:00:00Z'));
    });

    patrolTest('parses epoch milliseconds', ($) async {
      final ms = DateTime.utc(2024, 3, 1).millisecondsSinceEpoch;
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: 'x', createdAt: ms)],
          },
        ),
      );
      expect(notes.first.createdAt, DateTime.fromMillisecondsSinceEpoch(ms));
    });

    patrolTest('parses epoch seconds', ($) async {
      final secs = DateTime.utc(2024, 3, 1).millisecondsSinceEpoch ~/ 1000;
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: 'x', createdAt: secs)],
          },
        ),
      );
      expect(notes.first.createdAt, DateTime.fromMillisecondsSinceEpoch(secs * 1000));
    });

    patrolTest('updatedAt falls back to createdAt when absent', ($) async {
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: 'x', createdAt: '2024-03-01T10:00:00Z')],
          },
        ),
      );
      expect(notes.first.updatedAt, notes.first.createdAt);
    });
  });

  // ── folders ────────────────────────────────────────────────────────────────

  group('folder resolution', () {
    patrolTest('maps folder_id to storypad_folder_<id> when the folder table has it', ($) async {
      final input = storypadBackup(
        tables: {
          'folders': [
            {'id': 7, 'name': 'Journal'},
          ],
          'notes': [
            noteRow(title: 'T', content: 'x', extra: {'folder_id': 7}),
          ],
        },
      );
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'storypad_folder_7');
    });

    patrolTest('resolves folder by name when id is missing', ($) async {
      final input = storypadBackup(
        tables: {
          'folders': [
            {'id': 7, 'name': 'Journal'},
          ],
          'notes': [
            noteRow(title: 'T', content: 'x', extra: {'folder_name': 'journal'}),
          ],
        },
      );
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'storypad_folder_7');
    });

    patrolTest('slugifies unknown folder names', ($) async {
      final input = storypadBackup(
        tables: {
          'notes': [
            noteRow(title: 'T', content: 'x', extra: {'folder_name': 'My Trips 2024!'}),
          ],
        },
      );
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'storypad_my_trips_2024');
    });

    patrolTest('notes without folder info get null folderId', ($) async {
      final notes = await adapter.parse(
        storypadBackup(
          tables: {
            'notes': [noteRow(title: 'T', content: 'x')],
          },
        ),
      );
      expect(notes.first.folderId, isNull);
    });
  });

  // ── metadata preservation (data-loss guard) ────────────────────────────────

  patrolTest('raw row is preserved in rawMetadata', ($) async {
    final row = noteRow(title: 'T', content: 'x', extra: {'mood': 'happy', 'weather': 'sunny'});
    final notes = await adapter.parse(
      storypadBackup(
        tables: {
          'notes': [row],
        },
      ),
    );
    expect(notes.first.rawMetadata['mood'], 'happy');
    expect(notes.first.rawMetadata['weather'], 'sunny');
  });
}
