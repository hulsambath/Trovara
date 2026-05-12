import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/adapters/obsidian_adapter.dart';
import 'package:trovara/core/import/import_adapter.dart';
import '../../test_support.dart';

void main() {
  late ObsidianAdapter adapter;

  setUp(() {
    adapter = ObsidianAdapter();
  });

  // ── canHandle ──────────────────────────────────────────────────────────────

  group('canHandle', () {
    patrolTest('accepts a raw String', ($) async {
      expect(adapter.canHandle('# Hello\nworld'), isTrue);
    });

    patrolTest('accepts a non-empty List<Map> with content key', ($) async {
      expect(adapter.canHandle([fileInput(path: 'note.md', content: '# Hello')]), isTrue);
    });

    patrolTest('accepts a List<Map> with only a path key', ($) async {
      expect(
        adapter.canHandle([
          {'path': 'note.md'},
        ]),
        isTrue,
      );
    });

    patrolTest('rejects an empty List', ($) async {
      expect(adapter.canHandle([]), isFalse);
    });

    patrolTest('rejects an integer', ($) async {
      expect(adapter.canHandle(42), isFalse);
    });

    patrolTest('rejects null', ($) async {
      expect(adapter.canHandle(null), isFalse);
    });
  });

  // ── sourceName ─────────────────────────────────────────────────────────────

  patrolTest('sourceName is obsidian', ($) async {
    expect(adapter.sourceName, 'obsidian');
  });

  // ── parse — single String input ────────────────────────────────────────────

  group('parse — String input', () {
    patrolTest('simple note with h1 title', ($) async {
      const md = '# My Note\nHello world.';
      final notes = await adapter.parse(md);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'My Note');
      expect(notes.first.markdownContent, 'Hello world.');
    });

    patrolTest('empty string is skipped', ($) async {
      final notes = await adapter.parse('   ');
      expect(notes, isEmpty);
    });
  });

  // ── parse — List<Map> input ────────────────────────────────────────────────

  group('parse — List<Map> input', () {
    patrolTest('parses multiple files', ($) async {
      final input = [
        fileInput(path: 'a.md', content: '# Alpha\nContent A.'),
        fileInput(path: 'b.md', content: '# Beta\nContent B.'),
      ];
      final notes = await adapter.parse(input);
      expect(notes, hasLength(2));
      expect(notes[0].title, 'Alpha');
      expect(notes[1].title, 'Beta');
    });

    patrolTest('skips files with empty content', ($) async {
      final input = [fileInput(path: 'empty.md', content: '   '), fileInput(path: 'good.md', content: '# Real\nbody')];
      final notes = await adapter.parse(input);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'Real');
    });

    patrolTest('returns empty list for non-List input', ($) async {
      final notes = await adapter.parse(fileInput(path: 'note.md', content: '# X'));
      // _normalise returns [] for non-String, non-List → no notes
      expect(notes, isEmpty);
    });
  });

  // ── YAML frontmatter ───────────────────────────────────────────────────────

  group('YAML frontmatter', () {
    patrolTest('extracts title from frontmatter', ($) async {
      const md = '---\ntitle: My Front Title\n---\nBody text.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'My Front Title');
      // Body should NOT contain frontmatter
      expect(notes.first.markdownContent, 'Body text.');
    });

    patrolTest('frontmatter title takes priority over h1', ($) async {
      const md = '---\ntitle: FM Title\n---\n# H1 Title\nContent.';
      final notes = await adapter.parse(md);
      // H1 is NOT promoted to title when frontmatter title exists
      expect(notes.first.title, 'FM Title');
    });

    patrolTest('parses inline list tags', ($) async {
      const md = '---\ntags: [productivity, ai, flutter]\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['productivity', 'ai', 'flutter']));
    });

    patrolTest('parses multi-line list tags', ($) async {
      const md = '---\ntags:\n  - dart\n  - flutter\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['dart', 'flutter']));
    });

    patrolTest('parses created_at date', ($) async {
      const md = '---\ncreated: 2024-01-15\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.createdAt, DateTime(2024, 1, 15));
    });

    patrolTest('parses updated_at (modified key)', ($) async {
      const md = '---\nmodified: 2024-06-01\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.updatedAt, DateTime(2024, 6, 1));
    });

    patrolTest('gracefully handles missing dates', ($) async {
      const md = '---\ntitle: No Dates\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.createdAt, isNull);
      expect(notes.first.updatedAt, isNull);
    });

    patrolTest('closing --- at EOF preserves frontmatter and title', ($) async {
      const md = '---\ntitle: End Of File Fence\n---';
      final notes = await adapter.parse(md);
      expect(notes, hasLength(1));
      expect(notes.first.title, 'End Of File Fence');
      expect(notes.first.markdownContent, isEmpty);
      expect(notes.first.rawMetadata['title'], 'End Of File Fence');
    });

    patrolTest('stores raw frontmatter in rawMetadata', ($) async {
      const md = '---\ntitle: Meta Test\nauthor: Sambath\n---\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.rawMetadata['title'], 'Meta Test');
      expect(notes.first.rawMetadata['author'], 'Sambath');
    });

    patrolTest('note without frontmatter parses correctly', ($) async {
      const md = '# Plain Note\nJust text.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'Plain Note');
      expect(notes.first.rawMetadata, isEmpty);
    });
  });

  // ── Title resolution fallback ──────────────────────────────────────────────

  group('title resolution', () {
    patrolTest('falls back to filename when no frontmatter or h1', ($) async {
      final input = [fileInput(path: 'my-awesome-note.md', content: 'Just body text.')];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'my-awesome-note');
    });

    patrolTest('strips extension from filename title', ($) async {
      final input = [fileInput(path: 'folder/Meeting Notes.md', content: 'Agenda here.')];
      final notes = await adapter.parse(input);
      expect(notes.first.title, 'Meeting Notes');
    });

    patrolTest('h1 heading is promoted to title and removed from body', ($) async {
      const md = '# Great Title\nBody content here.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'Great Title');
      expect(notes.first.markdownContent, 'Body content here.');
      expect(notes.first.markdownContent, isNot(contains('# Great Title')));
    });
  });

  // ── [[wikilinks]] extraction ───────────────────────────────────────────────

  group('wikilinks', () {
    patrolTest('extracts simple [[wikilink]]', ($) async {
      const md = '# Note\nSee [[Related Note]] for more.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks, contains('Related Note'));
    });

    patrolTest('extracts [[link|alias]] and stores target, not alias', ($) async {
      const md = '# Note\nCheck [[Target Page|nice alias]] here.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks, contains('Target Page'));
      expect(notes.first.internalLinks, isNot(contains('nice alias')));
    });

    patrolTest('deduplicates repeated wikilinks', ($) async {
      const md = '# Note\n[[Page A]] and [[Page A]] again.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks.where((l) => l == 'Page A'), hasLength(1));
    });

    patrolTest('returns empty internalLinks when no wikilinks', ($) async {
      const md = '# Plain\nNo links here.';
      final notes = await adapter.parse(md);
      expect(notes.first.internalLinks, isEmpty);
    });
  });

  // ── Inline #tags ───────────────────────────────────────────────────────────

  group('inline tags', () {
    patrolTest('extracts inline #tags from body', ($) async {
      const md = '# Note\nThis is about #flutter and #dart development.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['flutter', 'dart']));
    });

    patrolTest('merges inline tags with frontmatter tags', ($) async {
      const md = '---\ntags: [productivity]\n---\nWorking on #flutter today.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, containsAll(['productivity', 'flutter']));
    });

    patrolTest('strips # prefix from inline tags', ($) async {
      const md = '# Note\nLearn #machine-learning today.';
      final notes = await adapter.parse(md);
      expect(notes.first.tags, contains('machine-learning'));
    });

    patrolTest('does not extract # from markdown headings', ($) async {
      const md = '# My Note\n## Section\nBody.';
      final notes = await adapter.parse(md);
      // "My" and "Section" should NOT appear as tags
      expect(notes.first.tags, isNot(contains('My')));
      expect(notes.first.tags, isNot(contains('Section')));
    });
  });

  // ── Folder mapping ─────────────────────────────────────────────────────────

  group('folder mapping', () {
    patrolTest('root-level file has null folderId', ($) async {
      final input = [fileInput(path: 'note.md', content: '# Root note')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, isNull);
    });

    patrolTest('nested file maps to obsidian_ prefixed folder slug', ($) async {
      final input = [fileInput(path: 'Work/Projects/meeting.md', content: '# Meeting')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'obsidian_work_projects');
    });

    patrolTest('single-level sub-folder', ($) async {
      final input = [fileInput(path: 'Journal/today.md', content: '# Today')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'obsidian_journal');
    });

    patrolTest('spaces in folder names become underscores', ($) async {
      final input = [fileInput(path: 'My Vault/Daily Notes/2024-01-01.md', content: '# Day')];
      final notes = await adapter.parse(input);
      expect(notes.first.folderId, 'obsidian_my_vault_daily_notes');
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('edge cases', () {
    patrolTest('CRLF line endings are normalised', ($) async {
      const md = '---\r\ntitle: CRLF Test\r\n---\r\nBody.';
      final notes = await adapter.parse(md);
      expect(notes.first.title, 'CRLF Test');
    });

    patrolTest('malformed frontmatter does not throw', ($) async {
      // Missing closing ---
      const md = '---\ntitle: Broken\nBody without closing fence.';
      final notes = await adapter.parse(md);
      // Either skips or parses the whole thing as body
      expect(notes, hasLength(1));
    });

    patrolTest('ImportedNote implements toString', ($) async {
      const note = ImportedNote(title: 'Test', markdownContent: 'Body', tags: ['a', 'b'], internalLinks: ['C']);
      expect(note.toString(), contains('Test'));
    });
  });
}
