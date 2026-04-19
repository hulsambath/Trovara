import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/adapters/obsidian_adapter.dart';
import 'package:trovara/core/import/import_adapter.dart';

void main() {
  late ObsidianAdapter adapter;

  setUp(() {
    adapter = ObsidianAdapter();
  });

  // ── canHandle ──────────────────────────────────────────────────────────────

  group('canHandle', () {
    test('accepts a raw String', () {
      expect(adapter.canHandle('# Hello\nworld'), isTrue);
    });

    test('accepts a non-empty List<Map> with content key', () {
      expect(
        adapter.canHandle([
          {'path': 'note.md', 'content': '# Hello'},
        ]),
        isTrue,
      );
    });

    test('accepts a List<Map> with only a path key', () {
      expect(
        adapter.canHandle([
          {'path': 'note.md'},
        ]),
        isTrue,
      );
    });

    test('rejects an empty List', () {
      expect(adapter.canHandle([]), isFalse);
    });

    test('rejects an integer', () {
      expect(adapter.canHandle(42), isFalse);
    });

    test('rejects null', () {
      expect(adapter.canHandle(null), isFalse);
    });
  });

  // ── sourceName ─────────────────────────────────────────────────────────────

  test('sourceName is obsidian', () {
    expect(adapter.sourceName, 'obsidian');
  });

  // ── parse — single String input ────────────────────────────────────────────

  group('parse — String input', () {
    test('simple note with h1 title', () async {
      const md = '# My Note\nHello world.';
      final notes = await adapter.parse(md);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'My Note');
      expect(notes.first.markdownContent, 'Hello world.');
    });

    test('empty string is skipped', () async {
      final notes = await adapter.parse('   ');
      expect(notes, isEmpty);
    });
  });

  // ── parse — List<Map> input ────────────────────────────────────────────────

  group('parse — List<Map> input', () {
    test('parses multiple files', () async {
      final input = [
        {'path': 'a.md', 'content': '# Alpha\nContent A.'},
        {'path': 'b.md', 'content': '# Beta\nContent B.'},
      ];
      final notes = await adapter.parse(input);
      expect(notes, hasLength(2));
      expect(notes[0].title, 'Alpha');
      expect(notes[1].title, 'Beta');
    });

    test('skips files with empty content', () async {
      final input = [
        {'path': 'empty.md', 'content': '   '},
        {'path': 'good.md', 'content': '# Real\nbody'},
      ];
      final notes = await adapter.parse(input);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'Real');
    });

    test('returns empty list for non-List input', () async {
      final notes = await adapter.parse({'path': 'note.md', 'content': '# X'});
      // _normalise returns [] for non-String, non-List → no notes
      expect(notes, isEmpty);
    });
  });

  // ── YAML frontmatter ───────────────────────────────────────────────────────

  group('YAML frontmatter', () {
    test('extracts title from frontmatter', () async {
      const md = '---\ntitle: My Front Title\n---\nBody text.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'My Front Title');
      // Body should NOT contain frontmatter
      expect(notes.first.markdownContent, 'Body text.');
    });

    test('frontmatter title takes priority over h1', () async {
      const md = '---\ntitle: FM Title\n---\n# H1 Title\nContent.';
      final notes = await adapter.parse(md);
      // H1 is NOT promoted to title when frontmatter title exists
      expect(notes.first.title, 'FM Title');
    });

    test('parses inline list tags', () async {
      const md = '---\ntags: [productivity, ai, flutter]\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['productivity', 'ai', 'flutter']));
    });

    test('parses multi-line list tags', () async {
      const md = '---\ntags:\n  - dart\n  - flutter\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['dart', 'flutter']));
    });

    test('parses created_at date', () async {
      const md = '---\ncreated: 2024-01-15\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.createdAt, DateTime(2024, 1, 15));
    });

    test('parses updated_at (modified key)', () async {
      const md = '---\nmodified: 2024-06-01\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.updatedAt, DateTime(2024, 6, 1));
    });

    test('gracefully handles missing dates', () async {
      const md = '---\ntitle: No Dates\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.createdAt, isNull);
      expect(notes.first.updatedAt, isNull);
    });

    test('closing --- at EOF preserves frontmatter and title', () async {
      const md = '---\ntitle: End Of File Fence\n---';
      final notes = await adapter.parse(md);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'End Of File Fence');
      expect(notes.first.markdownContent, isEmpty);
      expect(notes.first.rawMetadata['title'], 'End Of File Fence');
    });

    test('stores raw frontmatter in rawMetadata', () async {
      const md = '---\ntitle: Meta Test\nauthor: Sambath\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.rawMetadata['title'], 'Meta Test');
      expect(notes.first.rawMetadata['author'], 'Sambath');
    });

    test('note without frontmatter parses correctly', () async {
      const md = '# Plain Note\nJust text.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'Plain Note');
      expect(notes.first.rawMetadata, isEmpty);
    });
  });

  // ── Title resolution fallback ──────────────────────────────────────────────

  group('title resolution', () {
    test('falls back to filename when no frontmatter or h1', () async {
      final input = [
        {'path': 'my-awesome-note.md', 'content': 'Just body text.'},
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'my-awesome-note');
    });

    test('strips extension from filename title', () async {
      final input = [
        {'path': 'folder/Meeting Notes.md', 'content': 'Agenda here.'},
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'Meeting Notes');
    });

    test('h1 heading is promoted to title and removed from body', () async {
      const md = '# Great Title\nBody content here.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'Great Title');
      expect(notes.first.markdownContent, 'Body content here.');
      expect(notes.first.markdownContent, isNot(contains('# Great Title')));
    });
  });

  // ── [[wikilinks]] extraction ───────────────────────────────────────────────

  group('wikilinks', () {
    test('extracts simple [[wikilink]]', () async {
      const md = '# Note\nSee [[Related Note]] for more.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks, contains('Related Note'));
    });

    test('extracts [[link|alias]] and stores target, not alias', () async {
      const md = '# Note\nCheck [[Target Page|nice alias]] here.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks, contains('Target Page'));
      expect(notes.first.internalLinks, isNot(contains('nice alias')));
    });

    test('deduplicates repeated wikilinks', () async {
      const md = '# Note\n[[Page A]] and [[Page A]] again.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks.where((l) => l == 'Page A'), hasLength(1));
    });

    test('returns empty internalLinks when no wikilinks', () async {
      const md = '# Plain\nNo links here.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks, isEmpty);
    });
  });

  // ── Inline #tags ───────────────────────────────────────────────────────────

  group('inline tags', () {
    test('extracts inline #tags from body', () async {
      const md = '# Note\nThis is about #flutter and #dart development.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['flutter', 'dart']));
    });

    test('merges inline tags with frontmatter tags', () async {
      const md = '---\ntags: [productivity]\n---\nWorking on #flutter today.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['productivity', 'flutter']));
    });

    test('strips # prefix from inline tags', () async {
      const md = '# Note\nLearn #machine-learning today.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, contains('machine-learning'));
    });

    test('does not extract # from markdown headings', () async {
      const md = '# My Note\n## Section\nBody.';
      final notes = await adapter.parse(md);
      // "My" and "Section" should NOT appear as tags
      expect(notes.first.tags, isNot(contains('My')));
      expect(notes.first.tags, isNot(contains('Section')));
    });
  });

  // ── Folder mapping ─────────────────────────────────────────────────────────

  group('folder mapping', () {
    test('root-level file has null folderId', () async {
      final input = [
        {'path': 'note.md', 'content': '# Root note'},
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, isNull);
    });

    test('nested file maps to obsidian_ prefixed folder slug', () async {
      final input = [
        {'path': 'Work/Projects/meeting.md', 'content': '# Meeting'},
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'obsidian_work_projects');
    });

    test('single-level sub-folder', () async {
      final input = [
        {'path': 'Journal/today.md', 'content': '# Today'},
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'obsidian_journal');
    });

    test('spaces in folder names become underscores', () async {
      final input = [
        {'path': 'My Vault/Daily Notes/2024-01-01.md', 'content': '# Day'},
      ];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'obsidian_my_vault_daily_notes');
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('edge cases', () {
    test('CRLF line endings are normalised', () async {
      const md = '---\r\ntitle: CRLF Test\r\n---\r\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'CRLF Test');
    });

    test('malformed frontmatter does not throw', () async {
      // Missing closing ---
      const md = '---\ntitle: Broken\nBody without closing fence.';
      final notes = await adapter.parse(md);
      // Either skips or parses the whole thing as body
      expect(notes, hasLength(1));
    });

    test('ImportedNote implements toString', () {
      const note = ImportedNote(
        title: 'Test',
        markdownContent: 'Body',
        tags: ['a', 'b'],
        internalLinks: ['C'],
      );
      expect(note.toString(), contains('Test'));
    });
  });
}
