import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/converters/markdown_to_quill.dart';
import 'package:trovara/core/import/converters/quill_to_markdown.dart';

void main() {
  group('Markdown ↔ Quill round-trip', () {
    test('preserves links, headings, and lists in a basic round-trip', () {
      const md = '''
# Title

See [Google](https://google.com).

- one
- two

---''';

      final delta = MarkdownToQuillConverter.convert(md);
      final out = QuillToMarkdownConverter.convert(delta);

      // Exact whitespace may vary; assert key constructs survive.
      expect(out, contains('# Title'));
      expect(out, contains('[Google](https://google.com)'));
      expect(out, contains('- one'));
      expect(out, contains('- two'));
      expect(out, contains('---'));
    });
  });
}

