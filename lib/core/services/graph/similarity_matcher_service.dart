import 'dart:math' as math;
import 'package:logger/logger.dart';

class SimilarityMatcherService {
  static final _logger = Logger();

  /// Compute cosine similarity between two embedding vectors
  /// Returns value between 0.0 (orthogonal) and 1.0 (identical)
  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.isEmpty || embedding2.isEmpty) {
      return 0.0;
    }

    if (embedding1.length != embedding2.length) {
      _logger.w('Embedding length mismatch: ${embedding1.length} vs ${embedding2.length}');
      return 0.0;
    }

    // Compute dot product
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // Compute magnitudes
    final magnitude1 = math.sqrt(embedding1.fold(0.0, (sum, val) => sum + val * val));
    final magnitude2 = math.sqrt(embedding2.fold(0.0, (sum, val) => sum + val * val));

    if (magnitude1 == 0.0 || magnitude2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (magnitude1 * magnitude2);
  }

  /// Find the most similar embedding from a list
  /// Returns index and similarity score
  (int index, double similarity)? findMostSimilar(
    List<double> query,
    List<List<double>> candidates,
  ) {
    if (candidates.isEmpty) return null;

    double maxSimilarity = -1.0;
    int maxIndex = 0;

    for (int i = 0; i < candidates.length; i++) {
      final similarity = cosineSimilarity(query, candidates[i]);
      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        maxIndex = i;
      }
    }

    return (maxIndex, maxSimilarity);
  }

  /// Filter embeddings above similarity threshold
  List<(int index, double similarity)> filterByThreshold(
    List<double> query,
    List<List<double>> candidates, {
    double threshold = 0.7,
  }) {
    final results = <(int, double)>[];

    for (int i = 0; i < candidates.length; i++) {
      final similarity = cosineSimilarity(query, candidates[i]);
      if (similarity >= threshold) {
        results.add((i, similarity));
      }
    }

    // Sort by similarity descending
    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results;
  }
}
