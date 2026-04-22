import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/converters/quill_to_markdown.dart';

void main() {
  String mdFromOps(List<Map<String, dynamic>> ops) => QuillToMarkdownConverter.convert(jsonEncode({'ops': ops}));

  group('QuillToMarkdownConverter', () {
    test('exports link attribute as markdown link', () {
      final md = mdFromOps([
        {
          'insert': 'Google',
          'attributes': {'link': 'https://google.com'},
        },
        {'insert': '\n'},
      ]);
      expect(md, '[Google](https://google.com)');
    });

    test('exports header attribute as heading prefix', () {
      final md = mdFromOps([
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
      ]);
      expect(md, '## Title');
    });

    test('exports bullet list attribute', () {
      final md = mdFromOps([
        {'insert': 'Item'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ]);
      expect(md, '- Item');
    });

    test('exports divider embed as --- line', () {
      final md = mdFromOps([
        {
          'insert': {'divider': true},
        },
        {'insert': '\n'},
      ]);
      expect(md, '---');
    });
  });
}
