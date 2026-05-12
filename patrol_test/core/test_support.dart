import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
export 'package:patrol_finders/patrol_finders.dart';
import 'package:trovara/core/import/converters/markdown_to_quill.dart';
import 'package:trovara/core/import/converters/quill_to_markdown.dart';

Map<String, dynamic> fileInput({required String path, required String content}) => {'path': path, 'content': content};

Map<String, dynamic> deltaFromMarkdown(String markdown) =>
    jsonDecode(MarkdownToQuillConverter.convert(markdown)) as Map<String, dynamic>;

List<Map<String, dynamic>> quillOpsFromMarkdown(String markdown) =>
    (deltaFromMarkdown(markdown)['ops'] as List).cast<Map<String, dynamic>>();

String markdownFromQuillOps(List<Map<String, dynamic>> ops) =>
    QuillToMarkdownConverter.convert(jsonEncode({'ops': ops}));

void patrolTest(
  String description,
  Future<void> Function(PatrolTester $) callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
}) {
  patrolWidgetTest(
    description,
    callback,
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
  );
}

