import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:trovara/core/services/llm_client.dart';

/// Generates multiple semantic variants of a rewritten query to improve recall.
///
/// This is intentionally single-turn: it does not use chat history.
class MultiQueryExpansionService {
  final LlmClient _llm;
  final Logger _logger = Logger();

  MultiQueryExpansionService({required LlmClient llmClient}) : _llm = llmClient;

  bool get isAvailable => _llm.isAvailable;

  static const String _system = '''You generate search query variations for semantic retrieval.

Given ONE rewritten user question, output a JSON array of query strings.
- Output ONLY valid JSON (no markdown).
- Provide diverse paraphrases with different wording.
- Keep each query short and specific.
- Do not add facts.
''';

  Future<List<String>> expand(String rewrittenQuery, {int count = 3}) async {
    final q = rewrittenQuery.trim();
    if (q.isEmpty) return const [];
    if (!isAvailable) return [q];

    // `count` means: number of *variants* to generate (not including `rewrittenQuery`).
    // The return value always includes `rewrittenQuery` first.
    final variantsCount = count.clamp(1, 8);
    final prompt = '$_system\nReturn exactly $variantsCount queries.\n\nRewritten question:\n$q';

    try {
      final raw = (await _llm.generate(prompt)).trim();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [q];

      final out = <String>[];
      for (final item in decoded) {
        final s = item?.toString().trim() ?? '';
        if (s.isEmpty) continue;
        out.add(s);
      }

      // Always include the rewritten query and dedupe (exact match, case-insensitive) while preserving order.
      final normalizedSeen = <String>{};
      final result = <String>[];

      void add(String s) {
        final key = s.toLowerCase();
        if (normalizedSeen.contains(key)) return;
        normalizedSeen.add(key);
        result.add(s);
      }

      add(q);
      for (final s in out) {
        add(s);
        if (result.length >= (variantsCount + 1)) break;
      }

      return result;
    } catch (e) {
      _logger.w('Multi-query expansion failed: $e');
      return [q];
    }
  }
}
