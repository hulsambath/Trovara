import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/text_parser_service.dart';

void main() {
  group('TextParserService.parseQuillContent', () {
    test('parses standard Quill map format', () {
      const content = '{"ops":[{"insert":"Hello "},{"insert":"world"},{"insert":"\\n"}]}';
      expect(TextParserService.parseQuillContent(content), 'Hello world');
    });

    test('parses direct list format', () {
      const content = '[{"insert":"alpha"},{"insert":" beta"},{"insert":"\\n"}]';
      expect(TextParserService.parseQuillContent(content), 'alpha beta');
    });

    test('preserves spacing across line breaks', () {
      const content = '{"ops":[{"insert":"hello"},{"insert":"\\n"},{"insert":"world"},{"insert":"\\n"}]}';
      expect(TextParserService.parseQuillContent(content), 'hello world');
    });

    test('ignores non-string inserts such as embeds', () {
      const content = '{"ops":[{"insert":"Text"},{"insert":{"image":"x.png"}},{"insert":"\\n"}]}';
      expect(TextParserService.parseQuillContent(content), 'Text');
    });

    test('falls back to HTML stripping when JSON is invalid', () {
      const content = '<p>Hello <b>world</b></p>';
      expect(TextParserService.parseQuillContent(content), 'Hello world');
    });
  });

  group('TextParserService helpers', () {
    test('getPreviewText truncates and appends ellipsis', () {
      const content = '{"ops":[{"insert":"abcdefghijklmnopqrstuvwxyz\\n"}]}';
      expect(TextParserService.getPreviewText(content, maxLength: 10), 'abcdefghij...');
    });

    test('calculateWordCount and characterCount use parsed text', () {
      const content = '{"ops":[{"insert":"one"},{"insert":"\\n"},{"insert":"two three"},{"insert":"\\n"}]}';
      expect(TextParserService.calculateWordCount(content), 3);
      expect(TextParserService.calculateCharacterCount(content), 'one two three'.length);
    });
  });
}
