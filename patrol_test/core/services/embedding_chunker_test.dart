import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/embedding_chunker.dart';
import '../test_support.dart';

void main() {
  // ── chunkText ──────────────────────────────────────────────────────────────

  group('EmbeddingChunker.chunkText', () {
    patrolTest('short text returns single chunk', ($) async {
      final chunks = EmbeddingChunker.chunkText('Hello world');
      expect(chunks, hasLength(1));
      expect(chunks.first, 'Hello world');
    });

    patrolTest('empty text returns empty list', ($) async {
      expect(EmbeddingChunker.chunkText(''), isEmpty);
    });

    patrolTest('long text produces multiple chunks with overlap', ($) async {
      final text = 'A' * 2500;
      final chunks = EmbeddingChunker.chunkText(text);
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c, isNotEmpty);
      }
    });

    patrolTest('is deterministic', ($) async {
      const text = 'Same input text for determinism test.';
      expect(EmbeddingChunker.chunkText(text), equals(EmbeddingChunker.chunkText(text)));
    });
  });

  // ── buildEmbeddingInput ───────────────────────────────────────────────────

  group('EmbeddingChunker.buildEmbeddingInput', () {
    patrolTest('empty title returns chunk only', ($) async {
      expect(EmbeddingChunker.buildEmbeddingInput(title: '', chunkText: 'body'), 'body');
    });

    patrolTest('non-empty title prepends Title: header', ($) async {
      final result = EmbeddingChunker.buildEmbeddingInput(title: 'My Note', chunkText: 'body text');
      expect(result, startsWith('Title: My Note\n\n'));
      expect(result, contains('body text'));
    });
  });

  // ── computeContentSignature ───────────────────────────────────────────────

  group('EmbeddingChunker.computeContentSignature', () {
    patrolTest('same inputs produce same signature', ($) async {
      final inputs = ['chunk one', 'chunk two'];
      final a = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v1');
      final b = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v1');
      expect(a, equals(b));
    });

    patrolTest('different model name produces different signature', ($) async {
      final inputs = ['chunk one'];
      final a = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v1');
      final b = EmbeddingChunker.computeContentSignature(inputs, modelName: 'model-v2');
      expect(a, isNot(equals(b)));
    });

    patrolTest('different inputs produce different signature', ($) async {
      final a = EmbeddingChunker.computeContentSignature(['aaa'], modelName: 'm');
      final b = EmbeddingChunker.computeContentSignature(['bbb'], modelName: 'm');
      expect(a, isNot(equals(b)));
    });
  });
}
