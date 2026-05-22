import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/export/export_service.dart';

void main() {
  group('ExportService', () {
    late ExportService service;

    setUp(() {
      service = ExportService();
    });

    test('exports to markdown', () {
      const title = 'My Note';
      const content = '# Heading\n\nSome text.';
      const citations = ['https://example.com'];

      final markdown = service.toMarkdown(
        title: title,
        content: content,
        citations: citations,
      );

      expect(markdown, contains('# My Note'));
      expect(markdown, contains('Some text.'));
      expect(markdown, contains('https://example.com'));
    });

    test('converts note links to markdown links', () {
      const content = 'See [link: Other Note] for details.';

      final markdown = service.toMarkdown(
        title: 'Note',
        content: content,
        citations: [],
      );

      expect(markdown, contains('[Other Note]'));
    });

    test('generates markdown with bibliography', () {
      const citations = [
        'https://example.com/paper1.pdf',
        'https://example.com/paper2.pdf',
      ];

      final markdown = service.toMarkdown(
        title: 'Research Note',
        content: 'Content',
        citations: citations,
      );

      expect(markdown, contains('## References'));
      expect(markdown, contains('example.com/paper1.pdf'));
      expect(markdown, contains('example.com/paper2.pdf'));
    });

    test('handles empty citations gracefully', () {
      final markdown = service.toMarkdown(
        title: 'Note',
        content: 'Content',
        citations: [],
      );

      expect(markdown, isNotEmpty);
      expect(markdown, contains('# Note'));
    });
  });
}
