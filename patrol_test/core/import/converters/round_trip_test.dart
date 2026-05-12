import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/converters/markdown_to_quill.dart';
import 'package:trovara/core/import/converters/quill_to_markdown.dart';
import '../../test_support.dart';

void main() {
  group('Markdown ↔ Quill round-trip', () {
    patrolTest('preserves links, headings, and lists in a basic round-trip', ($) async {
      const md = '''
# Title

See [Google](https://google.com).

- one
- two

---''';

      final delta = MarkdownToQuillConverter.convert(md);
      final out = QuillToMarkdownConverter.convert(delta);

      expect(
        out,
        allOf([
          contains('# Title'),
          contains('[Google](https://google.com)'),
          contains('- one'),
          contains('- two'),
          contains('---'),
        ]),
      );
    });

    patrolTest('keeps the markdown shape stable through a second pass', ($) async {
      const md = '## Section\n\n1. first\n2. second';

      final roundTripped = markdownFromQuillOps(quillOpsFromMarkdown(md));

      expect(roundTripped, contains('## Section'));
      expect(roundTripped, contains('1. first'));
      expect(roundTripped, contains('2. second'));
    });
  });
}
