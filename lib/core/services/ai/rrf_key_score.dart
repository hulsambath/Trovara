/// A fused key with its Reciprocal Rank Fusion (RRF) score.
class RrfKeyScore {
  final String key;
  final double rrfScore;
  final double bestSimilarity;

  const RrfKeyScore({required this.key, required this.rrfScore, required this.bestSimilarity});
}
