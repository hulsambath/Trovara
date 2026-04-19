import 'dart:convert';

/// Converts a Quill Delta JSON string to a Markdown string.
///
/// Supported Delta attributes → Markdown:
/// - `{'header': 1}`    → `# `
/// - `{'header': 2}`    → `## `
/// - `{'header': 3}`    → `### `
/// - `{'bold': true}`   → `**text**`
/// - `{'italic': true}` → `*text*`
/// - `{'strike': true}` → `~~text~~`
/// - `{'code': true}`   → `` `text` ``
/// - `{'blockquote': true}` → `> `
/// - `{'list': 'bullet'}`   → `- `
/// - `{'list': 'ordered'}`  → `1. ` (sequential numbering)
/// - `{'link': '...'}`      → `[text](url)` (or `[[text]]` for wikilinks)
/// - Embed `{'divider': true}` → `---`
///
/// Quill Deltas that contain embedded objects other than `divider` are
/// rendered as `[embed]` to avoid silent data loss.
class QuillToMarkdownConverter {
  /// Convert a Quill Delta JSON string (or a plain Quill ops list JSON)
  /// to Markdown.  Returns an empty string on parse failure.
  static String convert(String quillDeltaJson) {
    if (quillDeltaJson.trim().isEmpty) return '';

    try {
      final decoded = jsonDecode(quillDeltaJson);
      List<dynamic> ops = [];

      if (decoded is Map<String, dynamic>) {
        ops = decoded['ops'] as List<dynamic>? ?? [];
      } else if (decoded is List) {
        ops = decoded;
      }

      return _buildMarkdown(ops);
    } catch (_) {
      // Fallback: treat as plain text
      return quillDeltaJson;
    }
  }

  static String _buildMarkdown(List<dynamic> ops) {
    final buffer = StringBuffer();

    // We accumulate inline spans per "line" (segments separated by `\n` inserts)
    // because line-level attributes (header, list, blockquote) live on the `\n`
    // insert, not on the preceding text inserts.
    final lineBuffer = StringBuffer();
    int orderedCounter = 0;

    void flushLine(Map<String, dynamic>? lineAttrs) {
      final lineContent = lineBuffer.toString();
      lineBuffer.clear();

      if (lineAttrs == null) {
        buffer.writeln(lineContent);
        orderedCounter = 0;
        return;
      }

      final header = lineAttrs['header'];
      final list = lineAttrs['list'];
      final blockquote = lineAttrs['blockquote'];

      if (header is int && header >= 1 && header <= 6) {
        buffer.writeln('${'#' * header} $lineContent');
        orderedCounter = 0;
      } else if (list == 'bullet') {
        buffer.writeln('- $lineContent');
        orderedCounter = 0;
      } else if (list == 'ordered') {
        orderedCounter++;
        buffer.writeln('$orderedCounter. $lineContent');
      } else if (blockquote == true) {
        buffer.writeln('> $lineContent');
        orderedCounter = 0;
      } else {
        buffer.writeln(lineContent);
        orderedCounter = 0;
      }
    }

    for (final op in ops) {
      if (op is! Map<String, dynamic>) continue;
      final insert = op['insert'];
      final attrs = op['attributes'] as Map<String, dynamic>?;

      // ── Embed objects ────────────────────────────────────────────────────
      if (insert is Map) {
        if (insert['divider'] == true) {
          // Flush any pending line content first
          if (lineBuffer.isNotEmpty) flushLine(null);
          buffer.writeln('---');
        } else {
          lineBuffer.write('[embed]');
        }
        continue;
      }

      if (insert is! String) continue;

      // ── Split on newlines — each `\n` ends a logical line ────────────────
      final parts = insert.split('\n');
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];

        if (i < parts.length - 1) {
          // This `\n` ends a line.  Inline-format the preceding segment.
          if (part.isNotEmpty) {
            lineBuffer.write(_inlineFormat(part, attrs));
          }
          // The lineAttrs for this `\n` only apply when the `\n` itself
          // carries attributes.  For mid-string `\n` splits the attrs live
          // on the LAST segment's `\n` op — so only use attrs on last split.
          flushLine(i == parts.length - 2 ? attrs : null);
        } else {
          // Last segment (no `\n` follows within this op)
          if (part.isNotEmpty) {
            lineBuffer.write(_inlineFormat(part, attrs));
          }
        }
      }
    }

    // Flush any remaining content
    if (lineBuffer.isNotEmpty) {
      flushLine(null);
    }

    return buffer.toString().trimRight();
  }

  static String _inlineFormat(String text, Map<String, dynamic>? attrs) {
    if (attrs == null || attrs.isEmpty) return text;

    // Code attribute takes precedence — don't nest bold inside code
    if (attrs['code'] == true) return '`$text`';
    if (attrs['strike'] == true) text = '~~$text~~';
    if (attrs['bold'] == true) text = '**$text**';
    if (attrs['italic'] == true) text = '*$text*';

    final link = attrs['link'] as String?;
    if (link != null) {
      // Trovara wikilinks are stored as trovara://note/<target>
      if (link.startsWith('trovara://note/')) {
        final target = link.substring('trovara://note/'.length);
        return '[[$target]]';
      }
      return '[$text]($link)';
    }

    return text;
  }
}
