import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Converts a note's stored `contentJson` into a Quill [Document].
///
/// Accepts both the bare delta-ops array (`[{"insert":"\n"}]`) and the wrapped
/// `{"ops": [...]}` form. Falls back to an empty document on any parse failure
/// so the editor always opens. Extracted from `NoteViewModel` (Recipe R3).
class NoteDocumentCodec {
  NoteDocumentCodec._();

  /// Parse [contentJson] into a [Document]; returns a fresh empty document on error.
  static Document parse(String contentJson) {
    try {
      final jsonData = jsonDecode(contentJson);
      final List<dynamic> ops;
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('ops')) {
        ops = jsonData['ops'] as List<dynamic>;
      } else if (jsonData is List<dynamic>) {
        ops = jsonData;
      } else {
        throw const FormatException('Invalid document format');
      }
      return Document.fromJson(ops);
    } catch (_) {
      return empty();
    }
  }

  /// A fresh empty single-newline document.
  static Document empty() => Document.fromJson(jsonDecode('[{"insert":"\\n"}]') as List<dynamic>);
}
