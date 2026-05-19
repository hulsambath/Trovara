import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/_providers/onnx_embedding_provider.dart';

import '../test_support.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Tests for the pure helpers (mean-pool + L2 norm).
//
//  The end-to-end ONNX session forward pass is exercised by
//  integration_test/on_device_embedding_test.dart on a real emulator.
//  Here we lock the deterministic post-processing math.
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  group('meanPool', () {
    patrolTest('averages valid tokens, ignores masked-out positions', ($) async {
      // 3 tokens × dim 2; mask=[1,1,0] → average of first two rows only.
      final pooled = OnnxEmbeddingProvider.meanPool(
        tokenOutputs: [
          [2.0, 4.0],
          [4.0, 6.0],
          [99.0, 99.0], // masked
        ],
        attentionMask: [1, 1, 0],
        dim: 2,
      );
      expect(pooled, equals([3.0, 5.0]));
    });

    patrolTest('returns zero vector when all tokens masked', ($) async {
      final pooled = OnnxEmbeddingProvider.meanPool(
        tokenOutputs: [
          [1.0, 2.0],
          [3.0, 4.0],
        ],
        attentionMask: [0, 0],
        dim: 2,
      );
      expect(pooled, equals([0.0, 0.0]));
    });

    patrolTest('matches simple arithmetic mean when all tokens valid', ($) async {
      final pooled = OnnxEmbeddingProvider.meanPool(
        tokenOutputs: [
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0],
        ],
        attentionMask: [1, 1],
        dim: 3,
      );
      expect(pooled, equals([2.5, 3.5, 4.5]));
    });
  });

  group('l2Normalize', () {
    patrolTest('produces a unit vector', ($) async {
      final v = OnnxEmbeddingProvider.l2Normalize([3.0, 4.0]);
      final norm = math.sqrt(v.fold<double>(0.0, (a, x) => a + x * x));
      expect(norm, closeTo(1.0, 1e-9));
      expect(v[0], closeTo(0.6, 1e-9));
      expect(v[1], closeTo(0.8, 1e-9));
    });

    patrolTest('returns input unchanged when norm is zero', ($) async {
      final v = OnnxEmbeddingProvider.l2Normalize([0.0, 0.0, 0.0]);
      expect(v, equals([0.0, 0.0, 0.0]));
    });

    patrolTest('keeps already-unit vectors approximately unit', ($) async {
      final v = OnnxEmbeddingProvider.l2Normalize([1.0, 0.0, 0.0]);
      expect(v, equals([1.0, 0.0, 0.0]));
    });
  });

  group('prefix constants', () {
    patrolTest('query/passage prefixes match E5 convention', ($) async {
      expect(OnnxEmbeddingProvider.queryPrefix, equals('query: '));
      expect(OnnxEmbeddingProvider.passagePrefix, equals('passage: '));
    });
  });
}
