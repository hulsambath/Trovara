import 'package:trovara/core/import/converters/quill_to_markdown.dart';
import 'package:trovara/models/note.dart';

/// Exports a single [Note] to a Markdown string with YAML frontmatter.
///
/// The output is fully compatible with Obsidian vaults:
/// - YAML frontmatter block (id, title, dates, tags, source, links)
/// - Body rendered from Quill Delta via [QuillToMarkdownConverter]
///
/// Example output:
/// ```markdown
/// ---
/// id: 550e8400-e29b-41d4-a716-446655440000
/// title: My Note
/// created_at: 2026-03-19T17:37:38.000Z
/// updated_at: 2026-03-20T01:02:04.000Z
/// tags: [productivity, ai]
/// source: trovara
/// links: []
/// ---
///
/// # My Note
///
/// This is the content...
/// ```
class MarkdownExporter {
  /// Convert a single [note] to a Markdown string with YAML frontmatter.
  static String exportNote(Note note) {
    final tags = note.allTags;
    final tagYaml = tags.isEmpty ? '[]' : '[${tags.map(_yamlStr).join(', ')}]';
    final links = note.internalLinks;
    final linksYaml = links.isEmpty ? '[]' : '[${links.map(_yamlStr).join(', ')}]';

    final frontmatter = StringBuffer()
      ..writeln('---')
      ..writeln('id: ${note.syncId}')
      ..writeln('title: ${_yamlStr(note.title)}')
      ..writeln('created_at: ${note.createdAt.toUtc().toIso8601String()}')
      ..writeln('updated_at: ${note.updatedAt.toUtc().toIso8601String()}')
      ..writeln('tags: $tagYaml')
      ..writeln('source: ${note.source}')
      ..writeln('links: $linksYaml')
      ..write('---');

    final body = QuillToMarkdownConverter.convert(note.contentJson);

    return '${frontmatter.toString()}\n\n${body.trim()}\n';
  }

  /// Export a list of notes, each separated by a markdown divider.
  ///
  /// Suitable for a single-file export bundle.
  static String exportNotes(List<Note> notes) => notes.map(exportNote).join('\n\n---\n\n');

  /// Produce a safe YAML scalar string.
  ///
  /// Wraps in double-quotes when the value contains `:`, `#`, `[`, `]`, or `'`.
  static String _yamlStr(String value) {
    const needsQuoting = [':', '#', '[', ']', "'", '"', '{', '}'];
    final needsQuote = needsQuoting.any(value.contains) || value.isEmpty;
    if (needsQuote) {
      final escaped = value.replaceAll('"', '\\"');
      return '"$escaped"';
    }
    return value;
  }
}
