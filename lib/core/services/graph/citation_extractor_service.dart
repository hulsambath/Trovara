import 'package:logger/logger.dart';

class ExtractedCitation {
  final String source; // URL or internal note title
  final bool isInternal; // true if internal note, false if external URL
  final String? title;

  ExtractedCitation({
    required this.source,
    required this.isInternal,
    this.title,
  });
}

class CitationExtractorService {
  static final _logger = Logger();

  /// Extract citations from note text
  /// Format: [citation: https://example.com] or [citation: Note Title]
  List<ExtractedCitation> extractCitations(String text) {
    final regex = RegExp(r'\[citation:\s*([^\]]+)\]');
    final matches = regex.allMatches(text);

    final citations = <ExtractedCitation>[];
    final seen = <String>{};

    for (final match in matches) {
      final source = match.group(1)?.trim();
      if (source == null || source.isEmpty) continue;

      // Avoid duplicates
      if (seen.contains(source)) continue;
      seen.add(source);

      final isInternal = !source.startsWith('http');

      citations.add(ExtractedCitation(
        source: source,
        isInternal: isInternal,
        title: isInternal ? source : _extractTitleFromUrl(source),
      ));
    }

    _logger.i('Extracted ${citations.length} citations from note');
    return citations;
  }

  /// Best-effort extraction of title from URL
  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.last.split('.').first.replaceAll('-', ' ');
      }
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  /// Validate URL format
  bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http');
    } catch (_) {
      return false;
    }
  }
}
