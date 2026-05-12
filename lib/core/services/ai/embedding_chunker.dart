import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Static helpers for chunking note text and computing content signatures.
///
/// Extracted from [EmbeddingService] to keep that class under 300 LOC.
/// All methods are pure (no side effects) — safe to call from tests without
/// any service setup.
class EmbeddingChunker {
  static const int maxChunkChars = 2000;
  static const int overlapChars = 200;

  EmbeddingChunker._();

  /// Build the embedding-input string sent to the API for one chunk.
  ///
  /// When [title] is non-empty, prepends `Title: <title>\n\n` so the model
  /// knows which note the chunk belongs to.
  static String buildEmbeddingInput({required String title, required String chunkText}) {
    if (title.isEmpty) return chunkText;
    return 'Title: $title\n\n$chunkText';
  }

  /// Split [text] into overlapping chunks of at most [maxChunkChars] characters.
  ///
  /// Prefers breaking at sentence boundaries (`. `) or newlines to avoid
  /// splitting mid-sentence. Returns an empty list for empty input.
  static List<String> chunkText(String text) {
    if (text.isEmpty) return const [];
    if (text.length <= maxChunkChars) return [text];

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + maxChunkChars;
      if (end >= text.length) {
        final chunk = text.substring(start).trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
        break;
      }

      final segment = text.substring(start, end);
      final lastPeriod = segment.lastIndexOf('. ');
      final lastNewline = segment.lastIndexOf('\n');
      final halfChunk = maxChunkChars ~/ 2;

      int breakPoint = -1;
      if (lastPeriod > halfChunk) breakPoint = lastPeriod + 1;
      if (lastNewline > halfChunk && lastNewline > breakPoint) breakPoint = lastNewline;

      if (breakPoint > 0) end = start + breakPoint + 1;

      final chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      start = end - overlapChars;
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  /// Compute a deterministic SHA-256 signature over [embeddingInputs].
  ///
  /// Includes [modelName] so that upgrading the model automatically
  /// invalidates old signatures. Used by [EmbeddingService.isNoteStale].
  static String computeContentSignature(
    List<String> embeddingInputs, {
    required String modelName,
    int maxChunk = maxChunkChars,
    int overlap = overlapChars,
  }) {
    final buffer = StringBuffer()
      ..writeln('model=$modelName')
      ..writeln('maxChunk=$maxChunk')
      ..writeln('overlap=$overlap');
    for (final input in embeddingInputs) {
      buffer
        ..writeln('---')
        ..writeln(input.replaceAll('\r\n', '\n').trim());
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }
}
