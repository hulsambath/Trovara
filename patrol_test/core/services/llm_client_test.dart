import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/llm_client.dart';

/// Coverage for [LlmClient] backend selection.
///
/// Locks in the Gemini API scenario behind the default chat backend:
///   - [LlmProvider.gemini] → Gemini Developer API, requires a `GEMINI_API_KEY`
void main() {
  group('LlmClient', () {
    test('defaultGeminiModel is a valid Gemini model id', () {
      // Regression lock: the API rejects human-readable names.
      expect(LlmClient.defaultGeminiModel, 'gemini-1.5-flash');
    });

    group('LlmProvider.gemini', () {
      test('is unavailable when no API key is configured', () async {
        final client = LlmClient(
          provider: LlmProvider.gemini,
          apiKey: '',
          modelName: LlmClient.defaultGeminiModel,
        );
        await client.initialize();

        expect(client.isAvailable, isFalse);
      });

      test('is available after initialize when an API key is configured', () async {
        final client = LlmClient(
          provider: LlmProvider.gemini,
          apiKey: 'test-key',
          modelName: LlmClient.defaultGeminiModel,
        );
        await client.initialize();

        expect(client.isAvailable, isTrue);
        expect(client.provider, LlmProvider.gemini);
        expect(client.modelName, LlmClient.defaultGeminiModel);
      });
    });
  });
}
