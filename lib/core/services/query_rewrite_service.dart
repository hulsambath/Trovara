import 'package:logger/logger.dart';
import 'package:trovara/core/services/llm_client.dart';
import 'dart:collection';

/// Rewrites a user query into a clear, retrieval-optimized standalone question.
///
/// Without [conversationContext], behavior matches a single-turn rewrite. With
/// a non-empty [conversationContext], pronouns and follow-ups can be resolved
/// using recent dialogue (still no new facts in the output query).
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

  static const String _contextualHint = '''

When a "Recent conversation" section appears below, use it ONLY to resolve references
in the current question (pronouns, "that topic", etc.). Do not add facts from the
conversation that are not implied by the current question.''';

  Future<String> rewrite(String userQuery, {String? conversationContext}) async {
    final q = userQuery.trim();
    if (q.isEmpty) return q;
    if (!isAvailable) return q;

    final ctx = conversationContext?.trim();
    final hasContext = ctx != null && ctx.isNotEmpty;

    if (!hasContext) {
      final cacheKey = q.toLowerCase();
      final cached = _cache.remove(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _cache[cacheKey] = cached;
        return cached;
      }
    }

    final prompt = hasContext
        ? '$_system$_contextualHint\n\nRecent conversation:\n$ctx\n\nCurrent user question:\n$q'
        : '$_system\n\nUser question:\n$q';

    try {
      final rewritten = (await _llm.generate(prompt)).trim();
      if (rewritten.isEmpty) return q;
      if (!hasContext) {
        final cacheKey = q.toLowerCase();
        _cache[cacheKey] = rewritten;
        while (_cache.length > _maxCacheEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      return rewritten;
    } catch (e) {
      _logger.w('Query rewrite failed: $e');
      return q;
    }
  }
}
