import 'package:trovara/core/services/ai/chat_tier.dart';

/// Retrieval-depth preset for a chat tier. Higher = better recall, more cost.
class RetrievalDepth {
  const RetrievalDepth({
    required this.fusionPoolSizePerQuery,
    required this.topKChunks,
    required this.expansionCount,
  });

  /// Candidates each (expanded) query contributes before RRF fusion.
  final int fusionPoolSizePerQuery;

  /// Final chunks used as prompt context.
  final int topKChunks;

  /// Number of query variations for multi-query expansion (1 = no expansion).
  final int expansionCount;

  static const RetrievalDepth free = RetrievalDepth(fusionPoolSizePerQuery: 5, topKChunks: 3, expansionCount: 1);
  static const RetrievalDepth pro = RetrievalDepth(fusionPoolSizePerQuery: 8, topKChunks: 5, expansionCount: 3);

  static RetrievalDepth forTier(ChatTier tier) => tier == ChatTier.pro ? pro : free;
}
