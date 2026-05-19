import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';

/// Embedding provider backed by the Gemini Developer API (google_generative_ai).
///
/// Requires a `GEMINI_API_KEY` injected at build time via `--dart-define`.
/// Kept on the API-key path because `firebase_ai` 3.8.0 does not yet expose
/// an embedding endpoint — only `GenerativeModel` (text/chat), `ImagenModel`,
/// and live variants. Migrate to Firebase AI when upstream ships embeddings.
class GeminiEmbeddingProvider {
  static const String defaultModel = 'text-embedding-004';

  final String apiKey;
  final String modelName;
  final Logger _logger = Logger();
  GenerativeModel? _model;

  GeminiEmbeddingProvider({required this.apiKey, this.modelName = defaultModel});

  /// Generate an embedding vector for [text].
  ///
  /// Returns `null` on any API error so [EmbeddingService] can queue the
  /// note for retry without crashing.
  Future<List<double>?> embed(String text) async {
    try {
      _model ??= GenerativeModel(model: modelName, apiKey: apiKey);
      final result = await _model!.embedContent(Content.text(text));
      return result.embedding.values.toList(growable: false);
    } catch (e) {
      _logger.e('Gemini embedding error: $e');
      return null;
    }
  }
}
