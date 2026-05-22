import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/graph/citation_extractor_service.dart';

void main() {
  group('CitationExtractorService', () {
    late CitationExtractorService service;

    setUp(() {
      service = CitationExtractorService();
    });

    test('extracts external URLs from text', () {
      const text = 'According to research [citation: https://example.com/paper.pdf] we know...';
      final citations = service.extractCitations(text);

      expect(citations, hasLength(1));
      expect(citations.first.source, 'https://example.com/paper.pdf');
    });

    test('extracts multiple citations', () {
      const text = '''
        First source [citation: https://example.com] says something.
        Second source [citation: Note on Artificial Intelligence] says another.
      ''';
      final citations = service.extractCitations(text);

      expect(citations, hasLength(2));
      expect(citations[0].source, 'https://example.com');
      expect(citations[1].source, 'Note on Artificial Intelligence');
    });

    test('extracts internal note references', () {
      const text = 'See also [citation: Note on Machine Learning] for details.';
      final citations = service.extractCitations(text);

      expect(citations.first.isInternal, true);
      expect(citations.first.source, 'Note on Machine Learning');
    });

    test('ignores malformed citation syntax', () {
      const text = 'This [citation: no closing bracket is ignored.';
      final citations = service.extractCitations(text);

      expect(citations, isEmpty);
    });

    test('deduplicates citations', () {
      const text = '''
        Source [citation: https://example.com] first mention.
        Source [citation: https://example.com] second mention.
      ''';
      final citations = service.extractCitations(text);

      expect(citations, hasLength(1));
    });

    test('handles URLs with special characters', () {
      const text = 'Research [citation: https://example.com/paper?id=123&lang=en] discusses...';
      final citations = service.extractCitations(text);

      expect(citations, hasLength(1));
      expect(citations.first.source, 'https://example.com/paper?id=123&lang=en');
    });
  });
}
