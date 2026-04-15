import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/import/converters/markdown_to_quill.dart';

void main() {
  Map<String, dynamic> _delta(String markdown) => jsonDecode(MarkdownToQuillConverter.convert(markdown)) as Map<String, dynamic>;

  group('MarkdownToQuillConverter', () {
    test('preserves markdown links as Quill link attributes', () {
      final delta = _delta('See [Google](https://google.com) now.');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(
        ops.any(
          (op) => op['insert'] == 'Google' && (op['attributes'] as Map?)?['link'] == 'https://google.com',
        ),
        isTrue,
      );
    });

    test('converts heading to newline op with header attribute', () {
      final delta = _delta('# Title');
      final ops = (delta['ops'] as List).cast<Map>();

      // Expect a terminating newline with header: 1
      expect(
        ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['header'] == 1),
        isTrue,
      );
    });

    test('converts bullet list line to newline op with list=bullet', () {
      final delta = _delta('- item');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(
        ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'bullet'),
        isTrue,
      );
    });

    test('converts ordered list line to newline op with list=ordered', () {
      final delta = _delta('1. first');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(
        ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'ordered'),
        isTrue,
      );
    });

    test('converts horizontal rule to divider embed', () {
      final delta = _delta('---');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(
        ops.any((op) => op['insert'] is Map && (op['insert'] as Map)['divider'] == true),
        isTrue,
      );
    });
  });
}

