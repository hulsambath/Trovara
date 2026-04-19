import 'dart:convert';

/// Converts a Markdown string into a Quill Delta JSON string.
///
/// Supported constructs (input → output):
/// - `# Heading 1`       → `{'insert': 'Heading 1', 'attributes': {'bold': true}}` + `{'insert': '\n', 'attributes': {'header': 1}}`
/// - `## Heading 2`      → header level 2
/// - `### Heading 3`     → header level 3
/// - `**bold**` / `__bold__`   → bold attribute
/// - `*italic*` / `_italic_`   → italic attribute
/// - `~~strikethrough~~`       → strike attribute
/// - `- item` / `* item`       → bullet list
/// - `1. item`           → ordered list
/// - `` `inline code` `` → code attribute
/// - `> blockquote`      → blockquote attribute
/// - `---` horizontal rule → divider embed
/// - Plain paragraph     → plain insert + `\n`
///
/// Unsupported Markdown (images, tables, fenced code blocks) is left as
/// plain text so no content is silently dropped.
class MarkdownToQuillConverter {
  /// Convert [markdown] to a Quill Delta JSON string.
  static String convert(String markdown) {
    if (markdown.trim().isEmpty) {
      return jsonEncode({
        'ops': [
          {'insert': '\n'},
        ],
      });
    }

    final ops = <Map<String, dynamic>>[];
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // ── Fenced code block ──────────────────────────────────────────────────
      if (line.startsWith('```')) {
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        // Each code line as inline-code insert
        for (final codeLine in codeLines) {
          if (codeLine.isNotEmpty) {
            ops.add({
              'insert': codeLine,
              'attributes': {'code': true},
            });
          }
          ops.add({'insert': '\n'});
        }
        i++; // skip closing ```
        continue;
      }

      // ── Horizontal rule ────────────────────────────────────────────────────
      if (line == '---' || line == '***' || line == '___') {
        ops.add({
          'insert': {'divider': true},
        });
        ops.add({'insert': '\n'});
        i++;
        continue;
      }

      // ── ATX Headings ───────────────────────────────────────────────────────
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!;
        _appendInline(ops, text);
        ops.add({
          'insert': '\n',
          'attributes': {'header': level},
        });
        i++;
        continue;
      }

      // ── Blockquote ─────────────────────────────────────────────────────────
      if (line.startsWith('> ')) {
        final text = line.substring(2);
        _appendInline(ops, text);
        ops.add({
          'insert': '\n',
          'attributes': {'blockquote': true},
        });
        i++;
        continue;
      }

      // ── Bullet list ────────────────────────────────────────────────────────
      final bulletMatch = RegExp(r'^[-*+]\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        _appendInline(ops, bulletMatch.group(1)!);
        ops.add({
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        });
        i++;
        continue;
      }

      // ── Ordered list ───────────────────────────────────────────────────────
      final orderedMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(line);
      if (orderedMatch != null) {
        _appendInline(ops, orderedMatch.group(1)!);
        ops.add({
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        });
        i++;
        continue;
      }

      // ── Blank line ─────────────────────────────────────────────────────────
      if (line.trim().isEmpty) {
        ops.add({'insert': '\n'});
        i++;
        continue;
      }

      // ── Plain paragraph / inline formatting ────────────────────────────────
      _appendInline(ops, line);
      ops.add({'insert': '\n'});
      i++;
    }

    // Ensure the Delta always ends with a bare newline
    if (ops.isEmpty || ops.last['insert'] != '\n') {
      ops.add({'insert': '\n'});
    }

    return jsonEncode({'ops': ops});
  }

  // ── Inline formatting parser ───────────────────────────────────────────────

  /// Parse inline Markdown spans within [text] and append Quill ops.
  ///
  /// Handles (in priority order): bold, italic, strikethrough, inline-code,
  /// [[wikilinks]], plain text.
  static void _appendInline(List<Map<String, dynamic>> ops, String text) {
    if (text.isEmpty) return;

    // Inline token pattern — order matters (longest match first)
    final pattern = RegExp(
      r'(\*\*|__)(.+?)\1' // bold
      r'|(\*|_)(.+?)\3' // italic
      r'|~~(.+?)~~' // strikethrough
      r'|`(.+?)`' // inline code
      r'|\[\[([^\]]+?)\]\]' // [[wikilink]]
      r'|\[[^\]]+\]\([^\)]+\)', // [text](url)  (parsed in handler to keep URL)
      dotAll: true,
    );

    int cursor = 0;
    for (final match in pattern.allMatches(text)) {
      // Plain text before this match
      if (match.start > cursor) {
        ops.add({'insert': text.substring(cursor, match.start)});
      }

      final full = match.group(0)!;
      if (full.startsWith('**') || full.startsWith('__')) {
        // Bold
        ops.add({
          'insert': match.group(2),
          'attributes': {'bold': true},
        });
      } else if (full.startsWith('~~')) {
        // Strikethrough
        ops.add({
          'insert': match.group(5),
          'attributes': {'strike': true},
        });
      } else if (full.startsWith('`')) {
        // Inline code
        ops.add({
          'insert': match.group(6),
          'attributes': {'code': true},
        });
      } else if (full.startsWith('[[')) {
        // Wikilink — rendered as plain text with a link attribute
        final target = match.group(7)!;
        ops.add({
          'insert': target,
          'attributes': {'link': 'trovara://note/$target'},
        });
      } else if (full.startsWith('[')) {
        // Markdown link [label](url) — preserve URL via Quill link attribute
        //
        // Supports optional titles: [label](url "title") or [label](url 'title')
        // We ignore the title, but keep the URL.
        final linkMatch = RegExp(
          '^\\[([^\\]]+)\\]\\((\\S+?)(?:\\s+(?:"[^"]*"|\'[^\']*\'))?\\)\$',
          dotAll: true,
        ).firstMatch(full);

        if (linkMatch != null) {
          final label = linkMatch.group(1) ?? '';
          final url = linkMatch.group(2) ?? '';
          if (label.isNotEmpty) {
            ops.add({
              'insert': label,
              'attributes': {'link': url},
            });
          }
        } else {
          // If parsing fails, fall back to plain text (avoid silent drops).
          ops.add({'insert': full});
        }
      } else if (full.startsWith('*') || full.startsWith('_')) {
        // Italic
        ops.add({
          'insert': match.group(4),
          'attributes': {'italic': true},
        });
      } else {
        ops.add({'insert': full});
      }

      cursor = match.end;
    }

    // Remaining plain text
    if (cursor < text.length) {
      ops.add({'insert': text.substring(cursor)});
    }
  }
}
