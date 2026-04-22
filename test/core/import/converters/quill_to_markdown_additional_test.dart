import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/converters/quill_to_markdown.dart';

void main() {
  String mdFromOps(List<Map<String, dynamic>> ops) => QuillToMarkdownConverter.convert(jsonEncode({'ops': ops}));

  group('QuillToMarkdownConverter additional scenarios', () {
    test('ordered list increments numbering and resets after plain line', () {
      final md = mdFromOps([
        {'insert': 'First'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Second'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Paragraph'},
        {'insert': '\n'},
        {'insert': 'Third'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
      ]);

      expect(md, equals('1. First\n2. Second\nParagraph\n1. Third'));
    });

    test('converts trovara wikilink protocol to double-bracket link', () {
      final md = mdFromOps([
        {
          'insert': 'Related Note',
          'attributes': {'link': 'trovara://note/Related Note'},
        },
        {'insert': '\n'},
      ]);

      expect(md, equals('[[Related Note]]'));
    });

    test('renders unknown embed as placeholder', () {
      final md = mdFromOps([
        {
          'insert': {'image': 'x.png'},
        },
        {'insert': '\n'},
      ]);

      expect(md, equals('[embed]'));
    });
  });
}
