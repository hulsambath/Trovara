import 'package:flutter_test/flutter_test.dart';
import '../../test_support.dart';

void main() {
  group('MarkdownToQuillConverter', () {
    patrolTest('preserves markdown links as Quill link attributes', ($) async {
      final delta = deltaFromMarkdown('See [Google](https://google.com) now.');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(
        ops.any((op) => op['insert'] == 'Google' && (op['attributes'] as Map?)?['link'] == 'https://google.com'),
        isTrue,
      );
    });

    patrolTest('converts heading to newline op with header attribute', ($) async {
      final delta = deltaFromMarkdown('# Title');
      final ops = (delta['ops'] as List).cast<Map>();

      // Expect a terminating newline with header: 1
      expect(ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['header'] == 1), isTrue);
    });

    patrolTest('converts bullet list line to newline op with list=bullet', ($) async {
      final delta = deltaFromMarkdown('- item');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'bullet'), isTrue);
    });

    patrolTest('converts ordered list line to newline op with list=ordered', ($) async {
      final delta = deltaFromMarkdown('1. first');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['list'] == 'ordered'), isTrue);
    });

    patrolTest('converts horizontal rule to divider embed', ($) async {
      final delta = deltaFromMarkdown('---');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(ops.any((op) => op['insert'] is Map && (op['insert'] as Map)['divider'] == true), isTrue);
    });

    patrolTest('converts bold text to bold attribute', ($) async {
      final delta = deltaFromMarkdown('**bold text**');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(ops.any((op) => op['insert'] == 'bold text' && (op['attributes'] as Map?)?['bold'] == true), isTrue);
    });

    patrolTest('converts italic text to italic attribute', ($) async {
      final delta = deltaFromMarkdown('*italic text*');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(ops.any((op) => op['insert'] == 'italic text' && (op['attributes'] as Map?)?['italic'] == true), isTrue);
    });

    patrolTest('converts blockquote to blockquote attribute', ($) async {
      final delta = deltaFromMarkdown('> quote line');
      final ops = (delta['ops'] as List).cast<Map>();

      expect(ops.any((op) => op['insert'] == '\n' && (op['attributes'] as Map?)?['blockquote'] == true), isTrue);
    });
  });
}
