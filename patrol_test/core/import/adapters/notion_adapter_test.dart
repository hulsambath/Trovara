import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/adapters/notion_adapter.dart';
import '../../test_support.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────
//
// Notion embeds a 32-character lowercase hex UUID in filenames and folder names.
// Example real filename:
//   "Meeting Notes abc123def456abc123def456abc12345.md"
//
// We use this constant throughout the tests so it's easy to update if the
// regex in the adapter ever changes.
const kNotionUuid = 'abc123def456abc123def456abc12345'; // exactly 32 hex chars

void main() {
  late NotionAdapter adapter;

  setUp(() {
    adapter = NotionAdapter();
  });

  // ── sourceName ─────────────────────────────────────────────────────────────

  patrolTest('sourceName is notion', ($) async {
    expect(adapter.sourceName, 'notion');
  });

  // ── canHandle ──────────────────────────────────────────────────────────────

  group('canHandle', () {
    patrolTest('accepts a List<Map> with non-empty content', ($) async {
      expect(adapter.canHandle([fileInput(path: 'Page $kNotionUuid.md', content: '# Page')]), isTrue);
    });

    patrolTest('accepts a List<Map> with UUID in path even with empty content', ($) async {
      // _hasNotionUuidPath returns true when the 32-char hex UUID is present
      expect(adapter.canHandle([fileInput(path: 'Notes $kNotionUuid.md', content: '')]), isTrue);
    });

    patrolTest('rejects a String (not a Notion export format)', ($) async {
      expect(adapter.canHandle('# Hello'), isFalse);
    });

    patrolTest('rejects an empty List', ($) async {
      expect(adapter.canHandle([]), isFalse);
    });

    patrolTest('rejects a Map (not wrapped in List)', ($) async {
      expect(adapter.canHandle({'path': 'x.md', 'content': '# X'}), isFalse);
    });
  });

  // ── UUID stripping from filenames ──────────────────────────────────────────

  group('title from Notion filename', () {
    patrolTest('strips 32-char hex UUID suffix', ($) async {
      final input = [fileInput(path: 'Meeting Notes $kNotionUuid.md', content: 'Some meeting content.')];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'Meeting Notes');
    });

    patrolTest('preserves title when file has no UUID suffix', ($) async {
      final input = [fileInput(path: 'Clean Title.md', content: 'Content.')];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'Clean Title');
    });

    patrolTest('uses h1 heading as title (h1 always wins over filename)', ($) async {
      final input = [fileInput(path: 'Unknown $kNotionUuid.md', content: '# Real Title\nContent here.')];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'Real Title');
    });

    patrolTest('falls back to UUID-stripped filename when no h1', ($) async {
      final input = [fileInput(path: 'My Page $kNotionUuid.md', content: 'Just body text without a heading.')];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'My Page');
    });
  });

  // ── Notion property block ──────────────────────────────────────────────────

  group('Notion property block', () {
    patrolTest('extracts tags from **Tags:** property line', ($) async {
      final input = [
        fileInput(path: 'note.md', content: '# Note\n**Tags:** productivity, ai, flutter\n\nBody content.'),
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.tags, containsAll(['productivity', 'ai', 'flutter']));
    });

    patrolTest('extracts tags from lowercase **tags:** line', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**tags:** design\n\nBody.')];
      final notes = await adapter.parse(input);
      expect(notes.first.tags, contains('design'));
    });

    patrolTest('created date from **Created:** property (ISO format)', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**Created:** 2024-03-19\n\nBody.')];
      final notes = await adapter.parse(input);
      expect(notes.first.createdAt, isNotNull);
    });

    patrolTest('created date from **Created:** property (human-readable Notion format)', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**Created:** March 19, 2026 3:02 PM\n\nBody.')];
      final notes = await adapter.parse(input);
      expect(notes.first.createdAt, isNotNull);
      expect(notes.first.createdAt!.year, 2026);
      expect(notes.first.createdAt!.month, 3);
      expect(notes.first.createdAt!.day, 19);
    });

    patrolTest('body excludes property lines', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**Tags:** test\n\nActual body here.')];
      final notes = await adapter.parse(input);
      expect(notes.first.markdownContent, contains('Actual body here.'));
      expect(notes.first.markdownContent, isNot(contains('**Tags:**')));
    });

    patrolTest('stores properties in rawMetadata (lowercased key)', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**Status:** Done\n\nBody.')];
      final notes = await adapter.parse(input);
      expect(notes.first.rawMetadata['status'], 'Done');
    });

    patrolTest('multiple properties are all stored in rawMetadata', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**Tags:** a, b\n**Created:** 2024-01-01\n\nBody.')];
      final notes = await adapter.parse(input);
      expect(notes.first.rawMetadata.containsKey('tags'), isTrue);
      expect(notes.first.rawMetadata.containsKey('created'), isTrue);
    });

    patrolTest('does not treat bold intro line **Introduction:** as a property', ($) async {
      final input = [
        fileInput(
          path: 'note.md',
          content: '# My Page\n**Introduction:** This is not metadata, it is prose.\n\nMore body.',
        ),
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.rawMetadata, isEmpty);
      expect(notes.first.markdownContent, contains('**Introduction:** This is not metadata'));
      expect(notes.first.markdownContent, contains('More body.'));
    });

    patrolTest('accepts **Key**: value with colon after closing bold (any key)', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n**Department**: Engineering\n\nBody text.')];
      final notes = await adapter.parse(input);
      expect(notes.first.rawMetadata['department'], 'Engineering');
      expect(notes.first.markdownContent, 'Body text.');
    });
  });

  // ── CSV files skipped ──────────────────────────────────────────────────────

  group('CSV handling', () {
    patrolTest('skips .csv files in the input', ($) async {
      final input = [
        fileInput(path: 'database.csv', content: 'id,name\n1,Alice'),
        fileInput(path: 'note.md', content: '# Note\nBody.'),
      ];
      final notes = await adapter.parse(input);
      expect(notes, hasLength(1));
      // Title from h1 (always wins over filename)
      expect(notes.first.title, 'Note');
    });
  });

  // ── Internal links ─────────────────────────────────────────────────────────

  group('internal links', () {
    patrolTest('extracts [[wikilinks]]', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\nSee [[Related Page]] for details.')];
      final notes = await adapter.parse(input);
      expect(notes.first.internalLinks, contains('Related Page'));
    });

    patrolTest('extracts @[mention] style links', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\nMention @[Alice] here.')];
      final notes = await adapter.parse(input);
      expect(notes.first.internalLinks, contains('Alice'));
    });

    patrolTest('deduplicates links', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n[[Page A]] and [[Page A]] again.')];
      final notes = await adapter.parse(input);
      expect(notes.first.internalLinks.where((l) => l == 'Page A'), hasLength(1));
    });

    patrolTest('returns empty internalLinks when none present', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\nPlain body.')];
      final notes = await adapter.parse(input);
      expect(notes.first.internalLinks, isEmpty);
    });
  });

  // ── HTML cleanup ───────────────────────────────────────────────────────────

  group('HTML cleanup', () {
    patrolTest('strips HTML tags from body', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\n<aside>Callout</aside>Body text.')];
      final notes = await adapter.parse(input);
      expect(notes.first.markdownContent, isNot(contains('<aside>')));
      expect(notes.first.markdownContent, contains('Body text.'));
    });

    patrolTest('collapses excessive blank lines', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note\nLine 1.\n\n\n\n\nLine 2.')];
      final notes = await adapter.parse(input);
      // 4+ blank lines should be reduced to 3 (i.e. no 4 consecutive \n)
      expect(notes.first.markdownContent, isNot(matches(RegExp(r'\n{4,}'))));
    });
  });

  // ── Folder mapping ─────────────────────────────────────────────────────────

  group('folder mapping', () {
    patrolTest('root-level note has null folderId', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Note')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, isNull);
    });

    patrolTest('nested note maps to notion_ prefixed folder slug', ($) async {
      final input = [fileInput(path: 'Work/Projects/task.md', content: '# Task')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'notion_work_projects');
    });

    patrolTest('UUID in folder names is stripped', ($) async {
      final input = [fileInput(path: 'Projects $kNotionUuid/note.md', content: '# Note')];
      final notes = await adapter.parse(input);
      // UUID stripped → "Projects" → "projects"
      expect(notes.first.folderId, 'notion_projects');
    });

    patrolTest('spaces in folder names become underscores', ($) async {
      final input = [fileInput(path: 'My Workspace/Daily Notes/entry.md', content: '# Entry')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'notion_my_workspace_daily_notes');
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('edge cases', () {
    patrolTest('skips files with empty content', ($) async {
      final input = [fileInput(path: 'empty.md', content: '   '), fileInput(path: 'real.md', content: '# Real\nBody.')];
      final notes = await adapter.parse(input);
      expect(notes, hasLength(1));
    });

    patrolTest('returns empty for non-List input', ($) async {
      final notes = await adapter.parse('# Not a list');
      expect(notes, isEmpty);
    });

    patrolTest('title is never empty — falls back to "Imported note"', ($) async {
      final input = [
        // Path with no meaningful name and no heading
        fileInput(path: '$kNotionUuid.md', content: 'No heading.'),
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.title, isNotEmpty);
    });

    patrolTest('CRLF line endings are normalised before h1 detection', ($) async {
      final input = [
        // rawText has CRLF; after normalisation the h1 should be "CRLF Title"
        fileInput(path: 'note.md', content: '# CRLF Title\r\nBody text.'),
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'CRLF Title');
    });

    patrolTest('parse returns empty list for empty list input', ($) async {
      final notes = await adapter.parse([]);
      expect(notes, isEmpty);
    });
  });
}
