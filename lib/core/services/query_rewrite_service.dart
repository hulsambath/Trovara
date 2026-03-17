import 'package:logger/logger.dart';
import 'package:trovara/core/services/llm_client.dart';
import 'dart:collection';

/// Rewrites a user query into a clear, retrieval-optimized standalone question.
///
/// This is intentionally single-turn: it does not use chat history.
class QueryRewriteService {
  final LlmClient _llm;
  final Logger _logger = Logger();
  // Bounded LRU cache to avoid unbounded growth and long-lived retention of user text.
  static const int _maxCacheEntries = 64;
  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  QueryRewriteService({required LlmClient llmClient}) : _llm = llmClient;

  bool get isAvailable => _llm.isAvailable;

  static const String _system = '''You are an assistant that rewrites user questions for semantic document retrieval.

Rewrite the user's question as a precise, self-contained search query.
- Remove filler words.
- Resolve pronouns and vague references when possible (e.g. “that”, “it”, “this week”) by making the query self-contained.
- Expand common abbreviations when it improves clarity.
- Keep it short and specific (ideally one sentence).
- Preserve intent; do NOT add facts or assumptions.
- Output ONLY the rewritten query text (no quotes, no bullets, no explanations).''';

  Future<String> rewrite(String userQuery) async {
    final q = userQuery.trim();
    if (q.isEmpty) return q;
    if (!isAvailable) return q;

    final cacheKey = q.toLowerCase();
    final cached = _cache.remove(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      // Touch entry to keep it most-recently-used.
      _cache[cacheKey] = cached;
      return cached;
    }

    final prompt = '$_system\n\nUser question:\n$q';

    try {
      final rewritten = (await _llm.generate(prompt)).trim();
      if (rewritten.isEmpty) return q;
      _cache[cacheKey] = rewritten;
      // Evict least-recently-used if needed.
      while (_cache.length > _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      return rewritten;
    } catch (e) {
      _logger.w('Query rewrite failed: $e');
      return q;
    }
  }
}
