import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/text_parser_service.dart';

void main() {
  group('TextParserService.parseQuillContent', () {
    test('parses standard Quill map structure and collapses whitespace', () {
      const input =
          '{"ops":[{"insert":"Hello"},{"insert":"\\n"},{"insert":"   world   "},{"insert":"\\n"}]}';

      final result = TextParserService.parseQuillContent(input);

      expect(result, equals('Hello world'));
    });

    test('parses direct ops list format', () {
      const input = '[{"insert":"Line one "},{"insert":"Line two"}]';

      final result = TextParserService.parseQuillContent(input);

      expect(result, equals('Line one Line two'));
    });

    test('ignores non-string inserts', () {
      const input =
          '{"ops":[{"insert":"Visible"},{"insert":{"image":"https://example.com"}},{"insert":" text"}]}';

      final result = TextParserService.parseQuillContent(input);

      expect(result, equals('Visible text'));
    });

    test('falls back to stripping HTML when JSON parsing fails', () {
      const input = '<p>Hello <b>world</b></p>';

      final result = TextParserService.parseQuillContent(input);

      expect(result, equals('Hello world'));
    });
  });

  group('TextParserService preview and counters', () {
    test('getPreviewText truncates and appends ellipsis', () {
      const input = '{"ops":[{"insert":"abcdefghijklmnopqrstuvwxyz"}]}';

      final preview = TextParserService.getPreviewText(input, maxLength: 10);

      expect(preview, equals('abcdefghij...'));
    });

    test('calculateWordCount counts words from parsed content', () {
      const input = '{"ops":[{"insert":"one two   three\\n"}]}';

      final count = TextParserService.calculateWordCount(input);

      expect(count, equals(3));
    });

    test('calculateCharacterCount uses parsed plain text length', () {
      const input = '{"ops":[{"insert":"abc"},{"insert":"\\n"},{"insert":"de"}]}';

      final count = TextParserService.calculateCharacterCount(input);

      expect(count, equals(5));
    });
  });
}
