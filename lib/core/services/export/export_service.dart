import 'package:logger/logger.dart';

enum ExportFormat { markdown, pdf, html, docx }

class ExportService {
  static final _logger = Logger();

  /// Export to Markdown format
  String toMarkdown({
    required String title,
    required String content,
    required List<String> citations,
    bool includeToc = true,
  }) {
    final buffer = StringBuffer();

    // Title
    buffer.writeln('# $title\n');

    // Table of contents (if requested and content has headings)
    if (includeToc && content.contains('##')) {
      buffer.writeln('## Table of Contents\n');
      // Simple TOC: extract h2/h3 headings
      final lines = content.split('\n');
      for (final line in lines) {
        if (line.startsWith('## ')) {
          final heading = line.replaceFirst('## ', '').trim();
          buffer.writeln('- [$heading](#${heading.toLowerCase().replaceAll(' ', '-')})');
        }
      }
      buffer.writeln();
    }

    // Content (with link conversion)
    final processedContent = _convertInternalLinks(content);
    buffer.write(processedContent);

    // Bibliography
    if (citations.isNotEmpty) {
      buffer.writeln('\n\n## References\n');
      for (final citation in citations) {
        buffer.writeln('- $citation');
      }
    }

    _logger.i('Exported to Markdown: $title');
    return buffer.toString();
  }

  /// Export to HTML format
  String toHtml({
    required String title,
    required String content,
    required List<String> citations,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>$title</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto; max-width: 800px; margin: 0 auto; padding: 20px; }');
    buffer.writeln('h1 { border-bottom: 2px solid #ddd; padding-bottom: 10px; }');
    buffer.writeln('code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }');
    buffer.writeln('a { color: #0066cc; }');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Title
    buffer.writeln('<h1>$title</h1>');

    // Content (markdown to HTML conversion - simplified)
    buffer.write(_markdownToHtml(content));

    // Bibliography
    if (citations.isNotEmpty) {
      buffer.writeln('<h2>References</h2>');
      buffer.writeln('<ul>');
      for (final citation in citations) {
        buffer.writeln('<li><a href="$citation">$citation</a></li>');
      }
      buffer.writeln('</ul>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    _logger.i('Exported to HTML: $title');
    return buffer.toString();
  }

  /// Convert internal note links to markdown links
  String _convertInternalLinks(String content) {
    // [link: Note Title] -> [Note Title](#note-title)
    final regex = RegExp(r'\[link:\s*([^\]]+)\]');
    return content.replaceAllMapped(regex, (match) {
      final noteTitle = match.group(1)?.trim() ?? '';
      return '[$noteTitle](#${noteTitle.toLowerCase().replaceAll(' ', '-')})';
    });
  }

  /// Very simple markdown to HTML conversion
  String _markdownToHtml(String markdown) {
    var html = markdown;

    // Headings
    html = html.replaceAllMapped(RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true), (m) {
      final level = m.group(1)!.length;
      final text = m.group(2)!;
      return '<h$level>$text</h$level>';
    });

    // Bold
    html = html.replaceAll(RegExp(r'\*\*(.+?)\*\*'), '<strong>\$1</strong>');

    // Italic
    html = html.replaceAll(RegExp(r'\*(.+?)\*'), '<em>\$1</em>');

    // Links
    html = html.replaceAllMapped(RegExp(r'\[(.+?)\]\((.+?)\)'), (m) {
      final text = m.group(1)!;
      final url = m.group(2)!;
      return '<a href="$url">$text</a>';
    });

    // Code blocks
    html = html.replaceAll(RegExp(r'```(.+?)```', dotAll: true), '<pre><code>\$1</code></pre>');

    // Inline code
    html = html.replaceAll(RegExp(r'`(.+?)`'), '<code>\$1</code>');

    // Paragraphs
    html = html.replaceAll(RegExp(r'\n\n+'), '</p><p>');
    html = '<p>$html</p>';

    return html;
  }

  /// Get file extension for format
  String getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.markdown:
        return '.md';
      case ExportFormat.pdf:
        return '.pdf';
      case ExportFormat.html:
        return '.html';
      case ExportFormat.docx:
        return '.docx';
    }
  }
}
