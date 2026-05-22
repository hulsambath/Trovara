import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/graph/similarity_matcher_service.dart';

void main() {
  group('SimilarityMatcherService', () {
    late SimilarityMatcherService service;

    setUp(() {
      service = SimilarityMatcherService();
    });

    test('computes cosine similarity correctly', () {
      const embedding1 = [1.0, 0.0, 1.0];
      const embedding2 = [1.0, 0.0, 1.0];

      final similarity = service.cosineSimilarity(embedding1, embedding2);

      expect(similarity, closeTo(1.0, 0.001)); // identical = 1.0
    });

    test('returns 0 for orthogonal vectors', () {
      const embedding1 = [1.0, 0.0, 0.0];
      const embedding2 = [0.0, 1.0, 0.0];

      final similarity = service.cosineSimilarity(embedding1, embedding2);

      expect(similarity, closeTo(0.0, 0.001));
    });

    test('handles empty embeddings gracefully', () {
      const embedding1 = <double>[];
      const embedding2 = <double>[];

      final similarity = service.cosineSimilarity(embedding1, embedding2);

      expect(similarity, 0.0);
    });

    test('normalizes embeddings before comparison', () {
      const embedding1 = [2.0, 0.0, 2.0];
      const embedding2 = [1.0, 0.0, 1.0];

      final similarity = service.cosineSimilarity(embedding1, embedding2);

      expect(similarity, closeTo(1.0, 0.001)); // scaled versions are identical
    });
  });
}
