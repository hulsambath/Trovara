import 'package:flutter_test/flutter_test.dart';
import '../../test_support.dart';

void main() {
  group('QuillToMarkdownConverter', () {
    patrolTest('exports link attribute as markdown link', ($) async {
      final md = markdownFromQuillOps([
        {
          'insert': 'Google',
          'attributes': {'link': 'https://google.com'},
        },
        {'insert': '\n'},
      ]);
      expect(md, '[Google](https://google.com)');
    });

    patrolTest('exports header attribute as heading prefix', ($) async {
      final md = markdownFromQuillOps([
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
      ]);
      expect(md, '## Title');
    });

    patrolTest('exports bullet list attribute', ($) async {
      final md = markdownFromQuillOps([
        {'insert': 'Item'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]);
      expect(md, '- Item');
    });

    patrolTest('exports divider embed as --- line', ($) async {
      final md = markdownFromQuillOps([
        {
          'insert': {'divider': true},
        },
        {'insert': '\n'},
      ]);
      expect(md, '---');
    });

    patrolTest('exports bold attribute as markdown bold', ($) async {
      final md = markdownFromQuillOps([
        {
          'insert': 'bold text',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
      expect(md, '**bold text**');
    });

    patrolTest('exports italic attribute as markdown italic', ($) async {
      final md = markdownFromQuillOps([
        {
          'insert': 'italic text',
          'attributes': {'italic': true},
        },
        {'insert': '\n'},
      ]);
      expect(md, '*italic text*');
    });

    patrolTest('exports blockquote attribute as markdown quote', ($) async {
      final md = markdownFromQuillOps([
        {'insert': 'quote line'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ]);
      expect(md, '> quote line');
    });
  });
}
